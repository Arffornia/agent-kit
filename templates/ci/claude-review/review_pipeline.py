#!/usr/bin/env python3
"""Deterministic glue for the AI review pipeline (.github/workflows/claude-review.yml).

The LLM jobs only produce JSON. Everything that decides what gets posted lives here, so it can
be unit-tested and never depends on model output being well-behaved.

Subcommands
  triage   risk level + finder lenses + verifier count from risk.yml and the changed files
  merge    merge and de-duplicate the findings of every finder lens into candidates.json
  tally    count independent verifier votes, keep confirmed findings, rank by severity
  payload  build the single GitHub review (body + inline comments) from confirmed findings

Only the Python standard library is used, plus PyYAML when it is installed (falls back to a
small parser that understands the risk.yml shape documented in templates/ci/README.md).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

MARKER = "arffornia-ai-review"
SEVERITIES = ["blocking", "major", "minor"]
SEV_RANK = {s: i for i, s in enumerate(SEVERITIES)}
LEVELS = ["light", "standard", "deep"]
LEVEL_ALIASES = {"low": "light", "medium": "standard", "high": "deep", "critical": "deep"}

# Finder lenses per level. Each lens is an independent agent with its own prompt.
LENSES = {
    "light": ["quick"],
    "standard": ["bugs", "security", "conventions"],
    "deep": ["bugs", "bugs-crosscut", "security", "conventions", "tests"],
}
# Independent verifiers per level, and how many must confirm a finding.
VERIFIERS = {"light": 0, "standard": 2, "deep": 3}
QUORUM = {"light": 0, "standard": 2, "deep": 2}
LABELS = ["fixed", "wrong", "intended", "noise"]


# ---------------------------------------------------------------- risk.yml

def glob_to_regex(pattern: str) -> re.Pattern:
    """gitignore-like globs: `**` spans directories, `*` and `?` stay inside one segment."""
    p = pattern.strip()
    anchored = p.startswith("/")
    p = p.lstrip("/")
    if p.endswith("/"):
        p += "**"
    out, i = [], 0
    while i < len(p):
        c = p[i]
        if p.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
        elif p.startswith("**", i):
            out.append(".*")
            i += 2
        elif c == "*":
            out.append("[^/]*")
            i += 1
        elif c == "?":
            out.append("[^/]")
            i += 1
        elif c == "{":
            j = p.find("}", i)
            if j == -1:
                out.append(re.escape(c))
                i += 1
            else:
                alts = p[i + 1 : j].split(",")
                out.append("(?:" + "|".join(re.escape(a) for a in alts) + ")")
                i = j + 1
        else:
            out.append(re.escape(c))
            i += 1
    body = "".join(out)
    # A pattern without a slash matches at any depth, like .gitignore.
    if not anchored and "/" not in pattern.strip().rstrip("/"):
        body = "(?:.*/)?" + body
    return re.compile("^" + body + "$")


def _mini_yaml(text: str) -> dict:
    """Tiny parser for the risk.yml shape (maps of lists of strings, scalars). No PyYAML needed."""
    root: dict = {}
    stack = [(-1, root)]
    last_key_at: dict[int, tuple[dict, str]] = {}
    for raw in text.splitlines():
        line = raw.split(" #", 1)[0].rstrip() if not raw.lstrip().startswith("#") else ""
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())
        s = line.strip()
        while stack and stack[-1][0] >= indent:
            stack.pop()
        parent = stack[-1][1] if stack else root
        if s.startswith("- "):
            val = s[2:].strip().strip("'\"")
            owner = last_key_at.get(max(k for k in last_key_at if k < indent)) if last_key_at else None
            if owner:
                d, k = owner
                if not isinstance(d.get(k), list):
                    d[k] = []
                d[k].append(val)
            continue
        if ":" in s:
            k, v = s.split(":", 1)
            k, v = k.strip().strip("'\""), v.strip()
            if not isinstance(parent, dict):
                continue
            if v == "":
                parent[k] = {}
                stack.append((indent, parent[k]))
                last_key_at = {kk: vv for kk, vv in last_key_at.items() if kk < indent}
                last_key_at[indent] = (parent, k)
            elif v.startswith("["):
                parent[k] = [x.strip().strip("'\"") for x in v.strip("[]").split(",") if x.strip()]
            else:
                parent[k] = v.strip("'\"")
    return root


def load_risk(path: str) -> dict:
    p = Path(path)
    if not p.is_file():
        return {}
    text = p.read_text(encoding="utf-8")
    try:
        import yaml  # type: ignore

        data = yaml.safe_load(text) or {}
    except ImportError:
        data = _mini_yaml(text)
    return data if isinstance(data, dict) else {}


def _norm_level(name) -> str | None:
    n = str(name).strip().lower()
    n = LEVEL_ALIASES.get(n, n)
    return n if n in LEVELS else None


def risk_rules(cfg: dict) -> dict[str, list[str]]:
    """Accepts `levels: {deep: [...]}` or top-level `deep: [...]`; entries may be `{paths: [...]}`."""
    src = cfg.get("levels") if isinstance(cfg.get("levels"), dict) else cfg
    rules: dict[str, list[str]] = {}
    for key, val in (src or {}).items():
        lvl = _norm_level(key)
        if not lvl:
            continue
        if isinstance(val, dict):
            val = val.get("paths") or val.get("globs") or []
        if isinstance(val, str):
            val = [val]
        rules.setdefault(lvl, []).extend(str(v) for v in val or [])
    return rules


def level_for_file(path: str, rules: dict[str, list[str]]) -> str | None:
    # deep always wins (safety); light paths are carve-outs from standard; then standard.
    for lvl in ("deep", "light", "standard"):
        for g in rules.get(lvl, []):
            if glob_to_regex(g).match(path):
                return lvl
    return None


def triage(files: list[str], cfg: dict, lines_changed: int, labels: list[str]) -> dict:
    rules = risk_rules(cfg)
    default = _norm_level(cfg.get("default", "standard")) or "standard"
    reasons: list[str] = []
    per_file = {}
    for f in files:
        per_file[f] = level_for_file(f, rules) or default
    level = "light"
    for f, lvl in per_file.items():
        if LEVELS.index(lvl) > LEVELS.index(level):
            level = lvl
    if not files:
        level = default
    top = [f for f, l in per_file.items() if l == level][:5]
    reasons.append(f"paths: {level} ({', '.join(top) or 'no files'})")
    esc = cfg.get("escalate") if isinstance(cfg.get("escalate"), dict) else {}
    threshold = int(esc.get("lines_changed", 400) or 400)
    if lines_changed > threshold and level != "deep":
        level = LEVELS[LEVELS.index(level) + 1]
        reasons.append(f"size: {lines_changed} changed lines > {threshold}, escalated to {level}")
    # Depth comes from the change, not the author: labels can only raise it.
    if "ai-review:deep" in labels and level != "deep":
        level = "deep"
        reasons.append("label ai-review:deep")
    return {
        "level": level,
        "lenses": LENSES[level],
        "verifiers": list(range(1, VERIFIERS[level] + 1)),
        "quorum": QUORUM[level],
        "reasons": reasons,
        "risk_file_found": bool(cfg),
    }


# ---------------------------------------------------------------- findings

def _load_json(path: Path):
    try:
        text = path.read_text(encoding="utf-8").strip()
        return json.loads(text) if text else None
    except (OSError, json.JSONDecodeError):
        return None


def _clean_finding(f: dict, lens: str) -> dict | None:
    if not isinstance(f, dict):
        return None
    path = str(f.get("path") or f.get("file") or "").strip().lstrip("./")
    try:
        line = int(f.get("line") or 0)
    except (TypeError, ValueError):
        line = 0
    sev = str(f.get("severity", "minor")).lower()
    sev = sev if sev in SEV_RANK else "minor"
    title = str(f.get("title") or "").strip()
    evidence = str(f.get("evidence") or "").strip()
    if not path or not title:
        return None
    return {
        "path": path,
        "line": max(line, 0),
        "severity": sev,
        "category": str(f.get("category") or lens),
        "title": title[:200],
        "description": str(f.get("description") or "").strip()[:2000],
        "evidence": evidence[:2000],
        "fix": str(f.get("fix") or f.get("suggested_fix") or "").strip()[:1500],
        "found_by": [lens],
    }


def merge(findings_dir: str, lenses: list[str]) -> dict:
    """Merge lens outputs. A lens with no readable output is reported, never treated as 'nothing found'."""
    merged: list[dict] = []
    missing: list[str] = []
    for lens in lenses:
        data = None
        for cand in Path(findings_dir).rglob(f"{lens}.json"):
            data = _load_json(cand)
            if data is not None:
                break
        if data is None:
            missing.append(lens)
            continue
        items = data.get("findings", []) if isinstance(data, dict) else data
        for raw in items or []:
            f = _clean_finding(raw, lens)
            if not f:
                continue
            dup = next(
                (
                    m
                    for m in merged
                    if m["path"] == f["path"]
                    and abs(m["line"] - f["line"]) <= 3
                    and (m["category"] == f["category"] or _similar(m["title"], f["title"]))
                ),
                None,
            )
            if dup:
                if SEV_RANK[f["severity"]] < SEV_RANK[dup["severity"]]:
                    dup["severity"] = f["severity"]
                if lens not in dup["found_by"]:
                    dup["found_by"].append(lens)
                if len(f["evidence"]) > len(dup["evidence"]):
                    dup["evidence"] = f["evidence"]
            else:
                merged.append(f)
    for i, f in enumerate(merged, 1):
        f["id"] = f"F{i}"
    return {"candidates": merged, "missing_lenses": missing}


def _similar(a: str, b: str) -> bool:
    wa = {w for w in re.findall(r"[a-z0-9]{4,}", a.lower())}
    wb = {w for w in re.findall(r"[a-z0-9]{4,}", b.lower())}
    return bool(wa and wb) and len(wa & wb) / max(1, min(len(wa), len(wb))) >= 0.6


def tally(candidates: dict, votes_dir: str, n_verifiers: int, quorum: int, level: str) -> dict:
    cands = candidates.get("candidates", [])
    missing = list(candidates.get("missing_lenses", []))
    if level == "light":
        # One quick pass, no verifiers: only post findings that carry evidence and matter.
        kept = [dict(f, votes="light pass, unverified") for f in cands if f["evidence"] and f["severity"] != "minor"]
        return _rank({"confirmed": kept[:5], "rejected": len(cands) - len(kept[:5]), "missing": missing})
    ballots: list[dict] = []
    for i in range(1, n_verifiers + 1):
        data = None
        for cand in Path(votes_dir).rglob(f"verifier-{i}.json"):
            data = _load_json(cand)
            if data is not None:
                break
        if data is None:
            missing.append(f"verifier-{i}")
            continue
        votes = data.get("votes", []) if isinstance(data, dict) else data
        ballots.append({str(v.get("id")): v for v in votes or [] if isinstance(v, dict)})
    confirmed, rejected = [], 0
    # With fewer ballots than planned, the quorum stays the same: missing votes count as "not confirmed".
    for f in cands:
        yes = [b[f["id"]] for b in ballots if b.get(f["id"], {}).get("verdict") == "confirmed"]
        if len(yes) >= max(1, quorum):
            sevs = sorted(SEV_RANK.get(str(v.get("severity", f["severity"])).lower(), SEV_RANK[f["severity"]]) for v in yes)
            # Median of the confirmers' severities, rounding towards the less severe one.
            sev = SEVERITIES[sevs[len(sevs) // 2]]
            ev = max((str(v.get("evidence") or "") for v in yes), key=len)
            confirmed.append(
                dict(
                    f,
                    severity=sev,
                    verifier_evidence=ev[:1500],
                    votes=f"{len(yes)}/{n_verifiers} verifiers confirmed",
                )
            )
        else:
            rejected += 1
    return _rank({"confirmed": confirmed, "rejected": rejected, "missing": missing})


def _rank(result: dict) -> dict:
    result["confirmed"].sort(key=lambda f: (SEV_RANK[f["severity"]], -len(f.get("found_by", [])), f["path"], f["line"]))
    return result


# ---------------------------------------------------------------- review payload

def diff_lines(files_json: list[dict]) -> dict[str, set[int]]:
    """Right-side line numbers present in each file's patch (where GitHub accepts inline comments)."""
    out: dict[str, set[int]] = {}
    for f in files_json:
        lines: set[int] = set()
        n = 0
        for row in (f.get("patch") or "").splitlines():
            m = re.match(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", row)
            if m:
                n = int(m.group(1))
                continue
            if row.startswith("-"):
                continue
            if row.startswith("+") or row.startswith(" "):
                lines.add(n)
                n += 1
        out[f.get("filename", "")] = lines
    return out


def _finding_md(f: dict, sha: str) -> str:
    parts = [f"**[{f['severity']}] {f['title']}** ({f['category']}, found by {', '.join(f.get('found_by', []))})", ""]
    if f.get("description"):
        parts += [f["description"], ""]
    if f.get("evidence"):
        parts += ["Evidence:", "", _quote(f["evidence"]), ""]
    if f.get("verifier_evidence") and f["verifier_evidence"] != f.get("evidence"):
        parts += ["Verifier check:", "", _quote(f["verifier_evidence"]), ""]
    if f.get("fix"):
        parts += [f"Fix: {f['fix']}", ""]
    parts.append(
        f"<sub>{f.get('votes', '')} · reply with one word: `fixed`, `wrong`, `intended` or `noise` "
        f"(feeds the reviewer evals)</sub>"
    )
    parts.append(f"<!-- {MARKER}-finding id={f['id']} sha={sha} sev={f['severity']} cat={f['category']} -->")
    return "\n".join(parts)


def _quote(text: str) -> str:
    return "\n".join("> " + l for l in text.splitlines()) or "> (empty)"


def payload(result: dict, files_json: list[dict], level: str, round_no: int, max_rounds: int, sha: str, reasons: list[str]) -> dict:
    conf = result.get("confirmed", [])
    counts = {s: sum(1 for f in conf if f["severity"] == s) for s in SEVERITIES}
    in_diff = diff_lines(files_json)
    comments, outside = [], []
    for f in conf:
        if f["line"] and f["line"] in in_diff.get(f["path"], set()):
            comments.append({"path": f["path"], "line": f["line"], "side": "RIGHT", "body": _finding_md(f, sha)})
        else:
            outside.append(f)
    head = (
        f"Findings: {len(conf)} (blocking {counts['blocking']}, major {counts['major']}, minor {counts['minor']})"
        f" · risk: {level} · round {round_no}/{max_rounds}"
    )
    body = [head, ""]
    if conf:
        body.append("| # | Severity | Where | Finding |")
        body.append("|---|---|---|---|")
        for i, f in enumerate(conf, 1):
            body.append(f"| {i} | {f['severity']} | `{f['path']}:{f['line']}` | {f['title'].replace('|', '/')} |")
        body.append("")
    if outside:
        body.append("### Outside the diff")
        for f in outside:
            body += ["", f"`{f['path']}:{f['line']}`", "", _finding_md(f, sha)]
        body.append("")
    body.append(
        f"<details><summary>How this review was made</summary>\n\n"
        f"- Depth: {'; '.join(reasons) or level}.\n"
        f"- {result.get('rejected', 0)} candidate finding(s) were dropped by the verifiers (no confirmed evidence).\n"
        + (f"- **Did not complete: {', '.join(result['missing'])}.** Coverage is partial; do not read silence as approval.\n" if result.get("missing") else "")
        + "- This review never approves or requests changes; a human decides. Reply to an inline comment with "
        "`fixed`, `wrong`, `intended` or `noise` so the reviewer can be measured.\n</details>"
    )
    body.append(f"<!-- {MARKER} sha={sha} round={round_no} level={level} -->")
    return {"commit_id": sha, "event": "COMMENT", "body": "\n".join(body), "comments": comments}


def count_rounds(reviews: list[dict], sha: str) -> tuple[int, bool]:
    """Number of previous AI review rounds, and whether this exact head sha was already reviewed."""
    rounds, seen = 0, False
    for r in reviews:
        b = r.get("body") or ""
        if f"<!-- {MARKER} " in b:
            rounds += 1
            if f"sha={sha}" in b:
                seen = True
    return rounds, seen


# ---------------------------------------------------------------- CLI

def _gh_output(**kv):
    out = os.environ.get("GITHUB_OUTPUT")
    lines = [f"{k}={v if isinstance(v, str) else json.dumps(v)}" for k, v in kv.items()]
    if out:
        with open(out, "a", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")
    print("\n".join(lines))


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    t = sub.add_parser("triage")
    t.add_argument("--risk", default="risk.yml")
    t.add_argument("--files-json", required=True, help="output of GET /pulls/{n}/files (paginated, slurped)")
    t.add_argument("--reviews-json", required=True, help="output of GET /pulls/{n}/reviews")
    t.add_argument("--labels", default="")
    t.add_argument("--sha", required=True)
    t.add_argument("--max-rounds", type=int, default=3)
    m = sub.add_parser("merge")
    m.add_argument("--dir", required=True)
    m.add_argument("--lenses", required=True)
    m.add_argument("--out", required=True)
    y = sub.add_parser("tally")
    y.add_argument("--candidates", required=True)
    y.add_argument("--dir", required=True)
    y.add_argument("--verifiers", type=int, required=True)
    y.add_argument("--quorum", type=int, required=True)
    y.add_argument("--level", required=True)
    y.add_argument("--out", required=True)
    p = sub.add_parser("payload")
    p.add_argument("--result", required=True)
    p.add_argument("--files-json", required=True)
    p.add_argument("--level", required=True)
    p.add_argument("--round", type=int, required=True)
    p.add_argument("--max-rounds", type=int, default=3)
    p.add_argument("--sha", required=True)
    p.add_argument("--reasons", default="[]")
    p.add_argument("--out", required=True)
    a = ap.parse_args(argv)

    if a.cmd == "triage":
        files_json = _flatten(json.loads(Path(a.files_json).read_text()))
        reviews = _flatten(json.loads(Path(a.reviews_json).read_text()))
        files = [f["filename"] for f in files_json]
        changed = sum(int(f.get("additions", 0)) + int(f.get("deletions", 0)) for f in files_json)
        labels = [l.strip() for l in a.labels.split(",") if l.strip()]
        res = triage(files, load_risk(a.risk), changed, labels)
        rounds, seen = count_rounds(reviews, a.sha)
        run = "true"
        why = ""
        if "ai-review:skip" in labels:
            run, why = "false", "label ai-review:skip"
        elif seen:
            run, why = "false", f"head {a.sha[:7]} already reviewed"
        elif rounds >= a.max_rounds:
            run, why = "exhausted", f"{rounds} AI review rounds reached (max {a.max_rounds})"
        _gh_output(
            run=run,
            skip_reason=why,
            level=res["level"],
            lenses=res["lenses"],
            verifiers=res["verifiers"] or [0],
            n_verifiers=str(len(res["verifiers"])),
            quorum=str(res["quorum"]),
            round=str(rounds + 1),
            reasons=res["reasons"],
            changed_lines=str(changed),
        )
        return 0
    if a.cmd == "merge":
        res = merge(a.dir, json.loads(a.lenses))
        Path(a.out).write_text(json.dumps(res, indent=2))
        print(f"{len(res['candidates'])} candidate(s); missing lenses: {res['missing_lenses'] or 'none'}")
        return 0
    if a.cmd == "tally":
        res = tally(json.loads(Path(a.candidates).read_text()), a.dir, a.verifiers, a.quorum, a.level)
        Path(a.out).write_text(json.dumps(res, indent=2))
        print(f"{len(res['confirmed'])} confirmed, {res['rejected']} dropped; missing: {res['missing'] or 'none'}")
        return 0
    if a.cmd == "payload":
        res = json.loads(Path(a.result).read_text())
        files_json = _flatten(json.loads(Path(a.files_json).read_text()))
        out = payload(res, files_json, a.level, a.round, a.max_rounds, a.sha, json.loads(a.reasons))
        Path(a.out).write_text(json.dumps(out, indent=2))
        print(f"{len(out['comments'])} inline comment(s)")
        return 0
    return 2


def _flatten(data):
    """`gh api --paginate --slurp` returns a list of pages; plain calls return a list."""
    if data and isinstance(data, list) and all(isinstance(x, list) for x in data):
        return [i for page in data for i in page]
    return data or []


if __name__ == "__main__":
    sys.exit(main())
