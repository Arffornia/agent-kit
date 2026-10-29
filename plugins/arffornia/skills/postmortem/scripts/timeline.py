#!/usr/bin/env python3
"""Build a raw incident timeline for one or more Arffornia repos from GitHub. Read-only.

Usage:
  timeline.py --from 2026-10-20T18:00 --to 2026-10-21T02:00 Arffornia/Arffornia_Provisioning [Arffornia/infra ...]
  timeline.py ... --json

Collects, in the window (UTC): commits on the default branch, PRs merged, workflow runs
(name, event, conclusion), releases and tags, and issues opened. Each line carries its URL.
It does not read cluster logs or Discord: add those by hand with their source.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys


def gh(path: str, **params: str) -> list | dict:
    args = ["gh", "api", "-X", "GET", path]
    for k, v in params.items():
        args += ["-f", f"{k}={v}"]
    r = subprocess.run(args, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"WARN cannot read {path}: {r.stderr.strip()[:200]} (reported, not skipped silently)", file=sys.stderr)
        return []
    return json.loads(r.stdout or "[]")


def iso(s: str) -> str:
    return s if len(s) > 16 else s + ":00Z" if len(s) == 16 else s + "T00:00:00Z"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("repos", nargs="+")
    ap.add_argument("--from", dest="start", required=True)
    ap.add_argument("--to", dest="end", required=True)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    start, end = iso(a.start), iso(a.end)
    ev: list[dict] = []
    for repo in a.repos:
        info = gh(f"repos/{repo}")
        branch = info.get("default_branch", "main") if isinstance(info, dict) else "main"
        for c in gh(f"repos/{repo}/commits", sha=branch, since=start, until=end, per_page="100"):
            ev.append({"t": c["commit"]["committer"]["date"], "repo": repo, "kind": "commit",
                       "what": c["commit"]["message"].splitlines()[0], "who": (c.get("author") or {}).get("login") or c["commit"]["author"]["name"],
                       "url": c["html_url"]})
        for p in gh(f"repos/{repo}/pulls", state="closed", sort="updated", direction="desc", per_page="100"):
            if p.get("merged_at") and start <= p["merged_at"] <= end:
                ev.append({"t": p["merged_at"], "repo": repo, "kind": "pr merged", "what": p["title"],
                           "who": p["user"]["login"], "url": p["html_url"]})
        runs = gh(f"repos/{repo}/actions/runs", created=f"{start[:19]}..{end[:19]}", per_page="100")
        for r in (runs.get("workflow_runs", []) if isinstance(runs, dict) else []):
            ev.append({"t": r["created_at"], "repo": repo, "kind": f"ci {r.get('conclusion') or r.get('status')}",
                       "what": f"{r['name']} ({r['event']}, {r['head_branch']}@{r['head_sha'][:7]})", "who": (r.get("actor") or {}).get("login"),
                       "url": r["html_url"]})
        for rel in gh(f"repos/{repo}/releases", per_page="30"):
            if start <= (rel.get("published_at") or "") <= end:
                ev.append({"t": rel["published_at"], "repo": repo, "kind": "release", "what": rel["tag_name"],
                           "who": rel["author"]["login"], "url": rel["html_url"]})
        for i in gh(f"repos/{repo}/issues", state="all", since=start, per_page="100"):
            if "pull_request" not in i and start <= i["created_at"] <= end:
                ev.append({"t": i["created_at"], "repo": repo, "kind": "issue opened", "what": i["title"],
                           "who": i["user"]["login"], "url": i["html_url"]})
    ev.sort(key=lambda e: e["t"])
    if a.json:
        print(json.dumps(ev, indent=2))
        return 0
    print(f"timeline {start} .. {end} (UTC), {len(ev)} event(s)")
    for e in ev:
        print(f"{e['t'][:16].replace('T', ' ')}  {e['repo'].split('/')[-1]:<24} {e['kind']:<16} {e['what']}  ({e['who']})  {e['url']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
