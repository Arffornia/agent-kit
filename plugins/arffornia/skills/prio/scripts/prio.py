#!/usr/bin/env python3
"""Rank open issues by (impact x urgency / effort) + unblock bonus. Read-only.

Usage:
  prio.py Arffornia/Arffornia_Mods [Arffornia/Arffornia_Website ...] [--top 15] [--json]
  prio.py --from-json issues.json [--top 15]      # offline: a saved `gh api .../issues` array

Scores come from labels (the Arffornia taxonomy) and issue text:
  impact   type: security 5, bug 4, test/ci 3, feature 3, refactor/deps 2, docs 1 (default 2)
  urgency  priority: P0 4, P1 3, P2 2, P3 1 (default 1.5: unlabelled issues sink, not vanish)
  effort   effort: S 1, M 2, L 4 (default 2)
  unblock  +1.5 per open issue that says "blocked by #N" / "depends on #N" / "after #N" about it
  in progress  an open PR says Closes #N: x0.2
  readiness  needs-decision x0.5 (a human must decide first: listed, not dropped), proposal x0.3
score = impact * urgency / effort + unblock.  Open PRs are read only to spot work in progress.
The script never edits issues, labels or project boards: it prints a proposal.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys

IMPACT = {"security": 5, "bug": 4, "test": 3, "ci": 3, "feature": 3, "refactor": 2, "deps": 2, "docs": 1}
URGENCY = {"P0": 4, "P1": 3, "P2": 2, "P3": 1}
EFFORT = {"S": 1, "M": 2, "L": 4}
DEP_RE = re.compile(r"(?:blocked by|depends on|after|requires|needs)\s+((?:[\w.-]+/[\w.-]+)?#\d+)", re.I)


def label(issue: dict, axis: str) -> str | None:
    for l in issue.get("labels", []):
        n = l["name"] if isinstance(l, dict) else str(l)
        if n.lower().startswith(axis + ":"):
            return n.split(":", 1)[1].strip()
    return None


def has(issue: dict, name: str) -> bool:
    return any((l["name"] if isinstance(l, dict) else str(l)) == name for l in issue.get("labels", []))


def fetch(repo: str) -> list[dict]:
    r = subprocess.run(["gh", "api", "--paginate", "-X", "GET", f"repos/{repo}/issues", "-f", "state=open", "-f", "per_page=100"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(f"ERROR cannot read {repo}: {r.stderr.strip()}", file=sys.stderr)
        sys.exit(2)
    out = []
    for chunk in re.split(r"(?<=\])\s*(?=\[)", r.stdout.strip()):
        out += json.loads(chunk)
    for i in out:
        i["_repo"] = repo
    return out


CLOSES_RE = re.compile(r"(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+((?:[\w.-]+/[\w.-]+)?#\d+)", re.I)


def score(issues: list[dict]) -> list[dict]:
    in_progress: dict[str, str] = {}
    for pr in (i for i in issues if "pull_request" in i):
        for ref in CLOSES_RE.findall(pr.get("body") or ""):
            key = ref if "/" in ref else f"{pr['_repo']}{ref}"
            in_progress[key] = pr.get("html_url", f"#{pr['number']}")
    issues = [i for i in issues if "pull_request" not in i]
    unblocks: dict[str, list[str]] = {}
    for i in issues:
        for ref in DEP_RE.findall(i.get("body") or ""):
            key = ref if "/" in ref else f"{i['_repo']}{ref}"
            unblocks.setdefault(key, []).append(f"{i['_repo']}#{i['number']}")
    rows = []
    for i in issues:
        t, p, e = label(i, "type"), label(i, "priority"), label(i, "effort")
        imp, urg, eff = IMPACT.get(t or "", 2), URGENCY.get(p or "", 1.5), EFFORT.get(e or "", 2)
        ub = unblocks.get(f"{i['_repo']}#{i['number']}", [])
        s = imp * urg / eff + 1.5 * len(ub)
        notes = []
        if has(i, "needs-decision"):
            s *= 0.5
            notes.append("needs-decision")
        if has(i, "proposal"):
            s *= 0.3
            notes.append("proposal")
        pr = in_progress.get(f"{i['_repo']}#{i['number']}")
        if pr:
            s *= 0.2
            notes.append(f"in progress: {pr}")
        if has(i, "agent-ready"):
            notes.append("agent-ready")
        missing = [a for a, v in (("type", t), ("priority", p), ("effort", e)) if not v]
        if missing:
            notes.append("unlabelled " + "/".join(missing))
        if ub:
            notes.append("unblocks " + ", ".join(ub))
        rows.append({"score": round(s, 2), "repo": i["_repo"], "number": i["number"], "title": i["title"],
                     "url": i.get("html_url", f"https://github.com/{i['_repo']}/issues/{i['number']}"),
                     "impact": imp, "urgency": urg, "effort": eff, "unblock": len(ub), "notes": notes,
                     "milestone": (i.get("milestone") or {}).get("title")})
    return sorted(rows, key=lambda r: (-r["score"], r["effort"], r["number"]))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("repos", nargs="*")
    ap.add_argument("--from-json")
    ap.add_argument("--top", type=int, default=15)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    issues: list[dict] = []
    if a.from_json:
        data = json.load(open(a.from_json, encoding="utf-8"))
        for i in data:
            i.setdefault("_repo", (i.get("repository_url") or "x/unknown").split("repos/")[-1])
        issues = data
    for repo in a.repos:
        issues += fetch(repo)
    if not issues:
        print(__doc__, file=sys.stderr)
        return 2
    rows = score(issues)[: a.top]
    if a.json:
        print(json.dumps(rows, indent=2))
        return 0
    print("score  I x U / E + ub   issue")
    for r in rows:
        print(f"{r['score']:5.1f}  {r['impact']} x {r['urgency']:g} / {r['effort']} + {r['unblock']}   "
              f"{r['url']}  {r['title']}" + (f"  [{'; '.join(r['notes'])}]" if r["notes"] else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
