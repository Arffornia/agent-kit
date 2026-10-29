#!/usr/bin/env python3
"""Lint a harness: skills, subagents and agent docs. Read-only.

Usage:
  skill_lint.py [DIR ...] [--transcripts ~/.claude/projects] [--days 30] [--json]

DIR defaults to every place skills and agents live under the current directory:
  plugins/*/skills, plugins/*/agents, .claude/skills, .claude/agents, .agents/skills.
AGENTS.md / CLAUDE.md files found under the current directory are measured too.

Checks (ERROR fails, WARN is advice):
  ERROR  front matter missing or not on line 1; no description; unknown front-matter key
  ERROR  an unquoted description containing " #" (YAML truncates it as a comment)
  ERROR  a relative link or `${CLAUDE_SKILL_DIR}/...` path that does not exist
  ERROR  side effects (git push, gh pr create, gh api -X POST/PATCH/DELETE, gh release,
         kubectl apply, rm -rf) without `disable-model-invocation: true` (skills only)
  WARN   description over 600 chars (listing cut is 1,536 for description+when_to_use)
         or without a "when"/"use" trigger phrase
  WARN   SKILL.md body over 200 lines (the doc's hard ceiling is 500); AGENTS.md over 100 lines
  WARN   a references/ or scripts/ file that SKILL.md never mentions (dead weight)
  WARN   two skills whose descriptions overlap strongly (Jaccard >= 0.45 on content words)
  WARN   a skill that loads another skill by name ("use the X skill", "/plugin:x") - skills
         should not depend on each other; agents preloading skills is fine
  WARN   contradictions: "always X" in one file and "never X" in another for the same phrase
  INFO   with --transcripts: how many times each skill was invoked in the last N days
         (Skill tool calls and /name commands in session JSONL); 0 = candidate for pruning
Exit code: 1 when any ERROR, else 0.
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys
import time

SKILL_KEYS = {"name", "description", "when_to_use", "argument-hint", "arguments", "disable-model-invocation",
              "user-invocable", "allowed-tools", "disallowed-tools", "model", "effort", "context", "agent",
              "background", "hooks", "paths", "shell", "metadata", "license", "compatibility"}
AGENT_KEYS = {"name", "description", "tools", "disallowedTools", "model", "permissionMode", "skills", "mcpServers",
              "hooks", "memory", "maxTurns", "background", "isolation", "color", "effort", "initialPrompt",
              "autoCompactWindow", "omitClaudeMd", "experimental"}
SIDE_EFFECT = re.compile(r"git push(?! --dry-run)|gh pr (?:create|merge|comment|review)|gh api [^\n`]*-X ?(?:POST|PATCH|PUT|DELETE)"
                         r"|gh api repos/[^\s`]+/(?:pulls|issues)(?:/\d+/(?:labels|comments))? +-f|gh release|kubectl (?:apply|delete)|rm -rf /")
STOP = set("a an the and or of to in on for with by from is are be it this that as at use when your you any its into "
           "not do does than then them they their what which who how only also can will after before over under".split())


def front_matter(path: str) -> tuple[dict | None, list[str], str]:
    text = open(path, encoding="utf-8").read()
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None, lines, text
    try:
        end = lines[1:].index("---") + 1
    except ValueError:
        return None, lines, text
    fm_text = "\n".join(lines[1:end])
    try:
        import yaml  # type: ignore
        fm = yaml.safe_load(fm_text) or {}
    except ImportError:
        fm = {}
        for l in lines[1:end]:
            m = re.match(r"^([A-Za-z_-]+):\s*(.*)$", l)
            if m:
                fm[m.group(1)] = m.group(2).strip().strip("'\"")
    except Exception as e:  # yaml error
        fm = {"__error__": str(e)}
    return fm, lines[end + 1:], text


def words(s: str) -> set[str]:
    return {w for w in re.findall(r"[a-z][a-z0-9-]{2,}", s.lower()) if w not in STOP}


def find_targets(dirs: list[str]) -> tuple[list[str], list[str]]:
    if not dirs:
        dirs = glob.glob("plugins/*/skills") + glob.glob("plugins/*/agents") + \
            [d for d in (".claude/skills", ".claude/agents", ".agents/skills") if os.path.isdir(d)]
    skills, agents = [], []
    for d in dirs:
        skills += glob.glob(os.path.join(d, "**", "SKILL.md"), recursive=True)
        if d.rstrip("/").endswith("agents"):
            agents += [p for p in glob.glob(os.path.join(d, "**", "*.md"), recursive=True)]
    return sorted(set(skills)), sorted(set(agents))


def usage_counts(root: str, days: int) -> dict[str, int]:
    counts: dict[str, int] = {}
    since = time.time() - days * 86400
    for p in glob.glob(os.path.join(os.path.expanduser(root), "**", "*.jsonl"), recursive=True):
        if os.path.getmtime(p) < since:
            continue
        try:
            for line in open(p, encoding="utf-8", errors="ignore"):
                for m in re.finditer(r'"name":\s*"Skill",\s*"input":\s*\{[^}]*"skill":\s*"([^"]+)"', line):
                    counts[m.group(1).split(":")[-1]] = counts.get(m.group(1).split(":")[-1], 0) + 1
                for m in re.finditer(r"<command-name>/?([\w:-]+)</command-name>", line):
                    counts[m.group(1).split(":")[-1]] = counts.get(m.group(1).split(":")[-1], 0) + 1
        except OSError:
            pass
    return counts


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dirs", nargs="*")
    ap.add_argument("--transcripts")
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    skills, agents = find_targets(a.dirs)
    out: list[dict] = []

    def add(level: str, path: str, msg: str) -> None:
        out.append({"level": level, "path": path, "msg": msg})

    descs: dict[str, set[str]] = {}
    statements: list[tuple[str, str, str]] = []
    names = {os.path.basename(os.path.dirname(p)) for p in skills}
    for path in skills + agents:
        is_skill = path.endswith("SKILL.md")
        fm, body, text = front_matter(path)
        name = os.path.basename(os.path.dirname(path)) if is_skill else os.path.splitext(os.path.basename(path))[0]
        if fm is None:
            add("ERROR", path, "no front matter starting on line 1")
            continue
        if "__error__" in fm:
            add("ERROR", path, f"front matter is not valid YAML: {fm['__error__']}")
            continue
        for raw in text.splitlines()[1:]:
            if raw.strip() == "---":
                break
            m = re.match(r"^(description|when_to_use):\s*([^'\"|>].*)$", raw)
            if m and re.search(r"\s#", m.group(2)):
                add("ERROR", path, f"unquoted '{m.group(1)}' contains ' #': YAML drops the rest as a comment; quote it")
        allowed = SKILL_KEYS if is_skill else AGENT_KEYS
        for k in fm:
            if k not in allowed:
                add("ERROR", path, f"unknown front-matter key '{k}' (silently ignored by Claude Code)")
        desc = str(fm.get("description", "") or "")
        if not desc:
            add("ERROR", path, "no description")
        total = len(desc) + len(str(fm.get("when_to_use", "") or ""))
        if total > 600:
            add("WARN", path, f"description is {total} chars; keep the trigger in the first sentence (cut at 1,536)")
        if desc and not re.search(r"\b(use|when|after|before|whenever)\b", desc, re.I):
            add("WARN", path, "description does not say when to use it")
        if is_skill:
            descs[name] = words(desc)
            if len(body) > 200:
                add("WARN", path, f"body is {len(body)} lines; move detail to references/")
            sd = os.path.dirname(path)
            for sub in ("references", "scripts", "assets"):
                for f in glob.glob(os.path.join(sd, sub, "**", "*"), recursive=True):
                    if os.path.isfile(f) and "__pycache__" not in f and os.path.relpath(f, sd) not in text and os.path.basename(f) not in text:
                        add("WARN", path, f"{os.path.relpath(f, sd)} is never mentioned in SKILL.md")
            if SIDE_EFFECT.search(text) and str(fm.get("disable-model-invocation", "")).lower() not in ("true", "yes", "on", "1"):
                m = SIDE_EFFECT.search(text)
                add("ERROR", path, f"side effect '{m.group(0)}' without disable-model-invocation: true "
                                   "(or move the command to a manual skill / say 'propose only')")
            for m in re.finditer(r"(?:the|use|run|invoke)\s+`?/?(?:arffornia:)?([a-z][a-z0-9-]+)`?\s+skill", text, re.I):
                if m.group(1) in names and m.group(1) != name:
                    add("WARN", path, f"depends on the '{m.group(1)}' skill; inline what is needed or point to a shared reference")
        base = os.path.dirname(path)
        for m in re.finditer(r"\]\(([^)#\s]+)(?:#[^)]*)?\)", text):
            t = m.group(1)
            if re.match(r"^[a-z]+:", t) or t.startswith("/"):
                continue
            if not os.path.exists(os.path.normpath(os.path.join(base, t))):
                add("ERROR", path, f"broken link {t}")
        for m in re.finditer(r"\$\{CLAUDE_SKILL_DIR\}/([\w./-]+)", text):
            if not os.path.exists(os.path.join(base, m.group(1))):
                add("ERROR", path, f"missing bundled file {m.group(1)}")
        for m in re.finditer(r"\b(always|never)\s+([a-z][a-z ]{6,40}?)[.,;:\n]", text, re.I):
            statements.append((m.group(1).lower(), m.group(2).lower().strip(), path))
    ks = sorted(descs)
    for i, x in enumerate(ks):
        for y in ks[i + 1:]:
            A, B = descs[x], descs[y]
            if A and B and len(A & B) / len(A | B) >= 0.45:
                add("WARN", f"{x} / {y}", f"descriptions overlap ({len(A & B)} shared words): Claude may pick the wrong one")
    pos = {(s, p) for k, s, p in statements if k == "always"}
    for k, s, p in statements:
        if k == "never":
            for s2, p2 in pos:
                if s2 == s and p2 != p:
                    add("WARN", f"{p} / {p2}", f"'never {s}' vs 'always {s}'")
    for doc in glob.glob("**/AGENTS.md", recursive=True) + glob.glob("**/CLAUDE.md", recursive=True):
        if "node_modules" in doc or doc.startswith("templates/"):
            continue
        n = sum(1 for _ in open(doc, encoding="utf-8"))
        if n > 100:
            add("WARN", doc, f"{n} lines; a map should stay under 100 lines")
    if a.transcripts:
        counts = usage_counts(a.transcripts, a.days)
        for n in ks:
            add("INFO", n, f"invoked {counts.get(n, 0)} time(s) in the last {a.days} days")
    if a.json:
        print(json.dumps(out, indent=2))
    else:
        for o in sorted(out, key=lambda o: ({"ERROR": 0, "WARN": 1, "INFO": 2}[o["level"]], o["path"])):
            print(f"{o['level']:5} {o['path']}: {o['msg']}")
        e = sum(o["level"] == "ERROR" for o in out)
        w = sum(o["level"] == "WARN" for o in out)
        print(f"{len(skills)} skill(s), {len(agents)} agent(s): {e} error(s), {w} warning(s)")
    return 1 if any(o["level"] == "ERROR" for o in out) else 0


if __name__ == "__main__":
    sys.exit(main())
