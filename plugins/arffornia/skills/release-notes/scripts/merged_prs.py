#!/usr/bin/env python3
"""List pull requests merged into an Arffornia repo since a tag or date, for release notes. Read-only.

Usage:
  merged_prs.py Arffornia/Arffornia_Mods [--since v1.4.0 | --since 2026-10-01] [--base main] [--json]

--since defaults to the latest GitHub release (or the latest tag). Output: one line per PR with
its URL, title, labels, author and the "player-facing" guess (labels area:/type: feature|bug,
or files under lang/, assets/, resources/views, src/renderer, config/*/modList.json). The
body's first paragraph is included in --json so the notes can be written from intent, not titles.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys

PLAYER_PATHS = re.compile(r"(^|/)(lang|locales|assets|resources/views|resources/js|src/renderer)/|modList\.json$|\.blade\.php$|\.vue$")


def gh(*args: str) -> object:
    r = subprocess.run(["gh", "api", *args], capture_output=True, text=True)
    if r.returncode != 0:
        print(f"ERROR gh api {' '.join(args)}: {r.stderr.strip()}", file=sys.stderr)
        sys.exit(2)
    out = r.stdout.strip()
    if out.startswith("[") and "][" in out.replace("]\n[", "]["):
        merged = []
        for chunk in re.split(r"(?<=\])\s*(?=\[)", out):
            merged += json.loads(chunk)
        return merged
    return json.loads(out) if out else None


def since_date(repo: str, since: str | None) -> tuple[str, str]:
    if since and re.match(r"^\d{4}-\d{2}-\d{2}", since):
        return since, since
    if not since:
        rel = subprocess.run(["gh", "api", f"repos/{repo}/releases/latest", "--jq", ".tag_name"], capture_output=True, text=True)
        since = rel.stdout.strip() if rel.returncode == 0 and rel.stdout.strip() else None
        if not since:
            tags = gh(f"repos/{repo}/tags", "-X", "GET", "-f", "per_page=1") or []
            if not tags:
                return "1970-01-01", "the first commit (no release or tag)"
            since = tags[0]["name"]
    c = gh(f"repos/{repo}/commits/{since}")
    return c["commit"]["committer"]["date"], since


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("repo")
    ap.add_argument("--since")
    ap.add_argument("--base", default=None)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    date, label = since_date(a.repo, a.since)
    base = a.base or gh(f"repos/{a.repo}")["default_branch"]
    # repo-scoped endpoint (the search API is not available in every session)
    closed = gh(f"repos/{a.repo}/pulls", "-X", "GET", "--paginate", "-f", "state=closed", "-f", f"base={base}",
                "-f", "sort=updated", "-f", "direction=desc", "-f", "per_page=100") or []
    rows = []
    for pr in sorted((p for p in closed if p.get("merged_at") and p["merged_at"] >= date), key=lambda p: p["merged_at"]):
        n = pr["number"]
        files = [f["filename"] for f in (gh(f"repos/{a.repo}/pulls/{n}/files", "-X", "GET", "-f", "per_page=100") or [])]
        labels = [l["name"] for l in pr.get("labels", [])]
        player = any(PLAYER_PATHS.search(f) for f in files) or any(l in ("type: feature", "type: bug") for l in labels)
        internal = all(re.match(r"^(\.github/|docs/|test|tests/|AGENTS|CLAUDE|README|CONTRIBUTING|Makefile|\.editorconfig)", f) for f in files) if files else False
        body = (pr.get("body") or "").strip()
        first = re.split(r"\n\s*\n", re.sub(r"^#+ .*\n", "", body), maxsplit=1)[0][:400]
        rows.append({"number": n, "url": pr["html_url"], "title": pr["title"], "merged_at": pr["merged_at"][:10],
                     "author": pr["user"]["login"], "labels": labels, "player_facing": player and not internal,
                     "files": len(files), "summary": first})
    if a.json:
        print(json.dumps({"repo": a.repo, "since": label, "since_date": date, "prs": rows}, indent=2))
        return 0
    print(f"{a.repo}: {len(rows)} PR(s) merged into {base} since {label} ({date[:10]})")
    for r in rows:
        tag = "PLAYER " if r["player_facing"] else "intern "
        print(f"  {tag} {r['url']}  {r['title']}  [{', '.join(r['labels'])}] {r['merged_at']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
