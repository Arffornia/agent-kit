#!/usr/bin/env python3
"""Lint Architecture Decision Records (ADRs).

Usage: python3 adr_lint.py [DIR ...]          (default: docs/decisions, docs/adr when present)

Each ADR is `NNNN-kebab-title.md` and declares its metadata either as YAML front-matter

    ---
    status: accepted            # proposed | accepted | rejected | deprecated | superseded
    date: 2026-10-29
    supersedes: [0003]          # optional, ADR numbers or file names
    amends: [0004]              # optional: changes part of an ADR that stays accepted
    superseded_by: 0012         # required when status is superseded
    ---

or as the bullet header used by existing repos (Noodle):

    - Status: Accepted
    - Date: 2026-09-26
    - Supersedes: ADR-0003
    - Superseded by: ADR-0012

Checks (every error message says how to fix it):
  name, required status/date, allowed status, date format, unique numbers,
  supersedes/superseded_by/amends point to existing ADRs, and both sides of a full supersession
  agree. A partial supersession ("Supersedes: one section of ADR-0007") is treated as `amends`.
Exit code 1 on any error. Standard library only.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

STATUSES = {"proposed", "accepted", "rejected", "deprecated", "superseded"}
NAME_RE = re.compile(r"^(\d{4})-[a-z0-9]+(?:-[a-z0-9]+)*\.md$")
# "Supersedes: one line of ADR-0007" replaces only part of it: the old ADR stays accepted.
PARTIAL_RE = re.compile(r"\b(part|partly|partially|line|section|clause|paragraph)\b", re.I)
SKIP = {"README.md", "index.md", "template.md", "0000-template.md", "TEMPLATE.md"}


def parse_meta(text: str) -> dict:
    meta: dict = {}
    lines = text.splitlines()
    if lines and lines[0].strip() == "---":
        for line in lines[1:]:
            if line.strip() == "---":
                break
            if ":" in line and not line.startswith(" "):
                k, v = line.split(":", 1)
                meta[_key(k)] = v.split(" #", 1)[0].strip()
        return meta
    for line in lines[:25]:
        m = re.match(r"^\s*[-*]\s*\**([A-Za-z ]+?)\**\s*:\s*(.+)$", line)
        if m:
            meta[_key(m.group(1))] = m.group(2).strip()
    return meta


def _key(k: str) -> str:
    return k.strip().lower().replace(" ", "_").replace("-", "_")


def refs(value: str | None) -> list[str]:
    if not value:
        return []
    v = value.strip().strip("[]")
    if v.lower() in {"", "none", "null", "-", "n/a"}:
        return []
    return [n.zfill(4) for n in re.findall(r"(\d{1,4})", v)]


def lint_dir(d: Path) -> list[str]:
    errors: list[str] = []
    adrs: dict[str, tuple[Path, dict]] = {}
    for p in sorted(d.glob("*.md")):
        if p.name in SKIP:
            continue
        m = NAME_RE.match(p.name)
        if not m:
            errors.append(f"{p}: name must be NNNN-kebab-title.md (e.g. 0007-use-datapacks.md). Rename the file.")
            continue
        num = m.group(1)
        if num in adrs:
            errors.append(f"{p}: number {num} is already used by {adrs[num][0].name}. Take the next free number.")
            continue
        adrs[num] = (p, parse_meta(p.read_text(encoding="utf-8")))

    for num, (p, meta) in adrs.items():
        status = meta.get("status", "").strip().lower().split()[0] if meta.get("status") else ""
        if not status:
            errors.append(f"{p}: missing status. Add front-matter `status: proposed` (or a `- Status: Proposed` line).")
        elif status not in STATUSES:
            errors.append(f"{p}: status '{meta['status']}' is not one of {sorted(STATUSES)}. Use one of them.")
        date = meta.get("date", "")
        if not re.match(r"^\d{4}-\d{2}-\d{2}$", date):
            errors.append(f"{p}: date '{date}' must be YYYY-MM-DD (the day the status last changed).")
        partial = bool(PARTIAL_RE.search(meta.get("supersedes", "")))
        for target in refs(meta.get("amends")) + (refs(meta.get("supersedes")) if partial else []):
            if target not in adrs:
                errors.append(f"{p}: amends {target}, which does not exist in {d}. Fix the number.")
        for target in [] if partial else refs(meta.get("supersedes")):
            if target not in adrs:
                errors.append(f"{p}: supersedes {target}, which does not exist in {d}. Fix the number.")
                continue
            tp, tmeta = adrs[target]
            if (tmeta.get("status", "").lower().split() or [""])[0] != "superseded" or num not in refs(tmeta.get("superseded_by")):
                errors.append(
                    f"{p}: supersedes {target}, but {tp.name} does not say so. In {tp.name} set "
                    f"`status: superseded` and `superseded_by: {num}`."
                )
        by = refs(meta.get("superseded_by"))
        if status == "superseded":
            if not by:
                errors.append(f"{p}: status superseded needs `superseded_by: NNNN` naming the ADR that replaces it.")
            for target in by:
                if target not in adrs:
                    errors.append(f"{p}: superseded_by {target}, which does not exist. Write that ADR or fix the number.")
                elif num not in refs(adrs[target][1].get("supersedes")):
                    errors.append(f"{p}: superseded_by {target}, but {adrs[target][0].name} lacks `supersedes: {num}`. Add it there.")
        elif by:
            errors.append(f"{p}: has superseded_by but status is '{status}'. Set `status: superseded` or drop superseded_by.")
    return errors


def main(argv: list[str]) -> int:
    dirs = [Path(a) for a in argv] or [p for p in (Path("docs/decisions"), Path("docs/adr")) if p.is_dir()]
    if not dirs:
        print("adr-lint: no docs/decisions or docs/adr directory, nothing to check.")
        return 0
    errors = []
    count = 0
    for d in dirs:
        if not d.is_dir():
            errors.append(f"{d}: not a directory.")
            continue
        count += len([p for p in d.glob("*.md") if p.name not in SKIP])
        errors += lint_dir(d)
    for e in errors:
        print(f"::error::{e}" if "GITHUB_ACTIONS" in __import__("os").environ else e)
    print(f"adr-lint: {count} ADR(s), {len(errors)} error(s).")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
