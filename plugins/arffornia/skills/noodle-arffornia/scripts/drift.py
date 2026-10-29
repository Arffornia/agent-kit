#!/usr/bin/env python3
"""Drift report between the curated Noodle model and the discovered fragments (ADR-0015).

Usage (from the docs repo root):
  drift.py [architecture/arffornia] [--json]

Reports:
  GONE       a `matches` id in model.yaml that no discovered fragment contains any more
             (the infra object was renamed or deleted: fix the model)
  UNMATCHED  a discovered element that neither it nor any ancestor (`parent` chain) is matched
             by a curated element (new infra object: model it, or decide it is out of scope)
  CONN       a discovered connection between two matched elements that the model does not
             have between the same curated ids (a connection found but not modelled)
Drift is a report, not a failure (ADR-0015): exit 0 unless the files cannot be read (2).
`noodle render` still enforces the hard rules (`matches` well-formed and unique).
"""
from __future__ import annotations

import glob
import json
import os
import sys

try:
    import yaml  # type: ignore
except ImportError:
    print("ERROR PyYAML is required (pip install pyyaml)", file=sys.stderr)
    sys.exit(2)


def load(path: str) -> dict:
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def main(argv: list[str]) -> int:
    as_json = "--json" in argv
    args = [a for a in argv if not a.startswith("--")]
    system = args[0] if args else "architecture/arffornia"
    model_path = os.path.join(system, "model.yaml")
    if not os.path.isfile(model_path):
        print(f"ERROR {model_path} not found: run from the docs repo root or pass the system dir", file=sys.stderr)
        return 2
    model = load(model_path)
    frags = {p: load(p) for p in sorted(glob.glob(os.path.join(system, "discovered", "*.yaml")))}
    if not frags:
        print(f"no fragments in {system}/discovered: run `make discover INFRA=../infra` first", file=sys.stderr)
        return 2
    disc: dict[str, dict] = {}
    for p, f in frags.items():
        for e in f.get("elements", []) or []:
            disc[e["id"]] = {**e, "_file": os.path.basename(p)}
    owner: dict[str, str] = {}
    for e in model.get("elements", []) or []:
        for m in e.get("matches", []) or []:
            owner[m] = e["id"]
    report: dict[str, list] = {"gone": [], "unmatched": [], "connections": []}
    for m, cur in sorted(owner.items()):
        if m not in disc:
            report["gone"].append({"curated": cur, "matches": m})

    def covered(eid: str) -> str | None:
        seen = set()
        while eid and eid not in seen:
            seen.add(eid)
            if eid in owner:
                return owner[eid]
            eid = (disc.get(eid) or {}).get("parent")
        return None

    for eid, e in sorted(disc.items()):
        if covered(eid) is None:
            src = e.get("src") or {}
            report["unmatched"].append({"id": eid, "kind": e.get("kind"), "tech": e.get("tech"),
                                        "src": f"{e['_file']}:{src.get('line', '?')}" if isinstance(src, dict) else str(src)})
    modelled = {(c.get("from"), c.get("to")) for c in model.get("connections", []) or []}
    for p, f in frags.items():
        for c in f.get("connections", []) or []:
            a, b = covered(c.get("from", "")), covered(c.get("to", ""))
            if a and b and a != b and (a, b) not in modelled:
                report["connections"].append({"from": a, "to": b, "discovered": f"{c.get('from')} -> {c.get('to')}",
                                              "src": os.path.basename(p)})
    if as_json:
        print(json.dumps(report, indent=2))
        return 0
    for g in report["gone"]:
        print(f"GONE       {g['curated']} matches {g['matches']}")
    for u in report["unmatched"]:
        print(f"UNMATCHED  {u['id']}  ({u['kind']}{', ' + u['tech'] if u['tech'] else ''})  {u['src']}")
    for c in report["connections"]:
        print(f"CONN       {c['from']} -> {c['to']}  (discovered {c['discovered']}, {c['src']})")
    print(f"{len(disc)} discovered elements in {len(frags)} fragment(s), {len(owner)} matched ids: "
          f"{len(report['gone'])} gone, {len(report['unmatched'])} unmatched, {len(report['connections'])} unmodelled connection(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
