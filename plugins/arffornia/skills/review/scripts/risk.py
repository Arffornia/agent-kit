#!/usr/bin/env python3
"""Route a change to a review depth from the repo's risk.yml.

Usage:
  risk.py [--risk-file risk.yml] [--base origin/main] [--json] [FILE ...]

Without FILE arguments, the changed files are `git diff --name-only <base>...HEAD`
plus uncommitted and untracked files. Prints one line per file with its level and the
rule that matched, then the overall level (the highest one) and the agent plan.

risk.yml (any of these shapes; first match wins inside a level, highest level wins):

  high:   ["**/network/**", "app/Http/Controllers/Auth/**"]
  medium: ["src/**"]
  low:    ["docs/**", "**/*.md"]

or
  levels:
    high:   {paths: [...], why: "network input"}
    medium: {paths: [...]}
  skip: ["**/*.lock", "public/build/**"]

Without a risk.yml, built-in Arffornia defaults are used (and the output says so).
Exit code: 0 always (it is a router, not a gate), 2 on bad usage.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import subprocess
import sys

ORDER = {"skip": -1, "low": 0, "medium": 1, "high": 2}

DEFAULTS = {
    "high": [
        "**/auth/**", "**/Auth/**", "**/*auth*", "**/*Auth*", "**/*token*", "**/*Token*",
        "**/network/**", "**/*Packet*.java", "**/*Payload*.java",
        "**/ipc/**", "**/*Handler.js", "src/preload/**", "src/main/**/index.js",
        "**/*download*", "**/*Download*", "**/*updater*",
        "routes/api.php", "app/Http/Middleware/**", "config/sanctum.php", "config/auth.php",
        "**/shop/**", "**/Shop*", "**/*Payment*",
        ".github/workflows/release*", ".github/workflows/publish*",
        "config/*/modList.json", "config/*/storage/**",
        "k8s/**/secret*", "**/*secret*", "**/Dockerfile", "**/*.Dockerfile",
        "k8s/config/**/config.yaml",
    ],
    "medium": [
        "app/**", "src/**", "lib/**", "database/migrations/**", "routes/**",
        "k8s/**", "charts/**", "terraform/**", "build.gradle", "**/*.gradle",
        "package.json", "composer.json",
    ],
    "low": [
        "docs/**", "**/*.md", "test/**", "tests/**", "**/test/**", "**/*.test.*",
        "**/*Test.java", "**/*Test.php", "**/lang/**", "**/locales/**", ".editorconfig",
    ],
    "skip": ["**/*.lock", "package-lock.json", "composer.lock", "public/build/**",
             "**/index.json", "**/*.min.js", "out/**", "build/**"],
}

PLAN = {
    "high": "high: every line, trace callers, 3 finders (correctness, security, rules) + "
            "1 verifier per candidate; run arffornia:security-reviewer too",
    "medium": "medium: every line, 2 finders (correctness, rules) + 1 verifier per candidate; "
              "check tests cover the change",
    "low": "low: one pass, verify anything you would report; no style beyond 3 remarks",
    "skip": "skip: generated or vendored only; say so and stop",
}


def glob_to_re(pat: str) -> re.Pattern:
    """`**` crosses directories, `*` does not, `?` is one char. Matches the whole path."""
    i, out = 0, ""
    while i < len(pat):
        c = pat[i]
        if pat.startswith("**/", i):
            out += "(?:.*/)?"
            i += 3
        elif pat.startswith("**", i):
            out += ".*"
            i += 2
        elif c == "*":
            out += "[^/]*"
            i += 1
        elif c == "?":
            out += "[^/]"
            i += 1
        else:
            out += re.escape(c)
            i += 1
    return re.compile("^" + out + "$")


def parse_simple_yaml(text: str) -> dict:
    """Tiny fallback for risk.yml when PyYAML is missing: top-level keys with
    inline lists or '- item' lists, and one nested level (levels: high: paths:)."""
    data: dict = {}
    stack: list[tuple[int, dict]] = [(-1, data)]
    last_key_at: dict[int, tuple[dict, str]] = {}
    for raw in text.splitlines():
        line = raw.split(" #", 1)[0].rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        ind = len(line) - len(line.lstrip())
        s = line.strip()
        while stack and stack[-1][0] >= ind:
            stack.pop()
        parent = stack[-1][1] if stack else data
        if s.startswith("- "):
            owner, key = last_key_at.get(max(k for k in last_key_at if k < ind), (None, None))
            if owner is not None:
                if not isinstance(owner.get(key), list):
                    owner[key] = []
                owner[key].append(s[2:].strip().strip("'\""))
            continue
        if ":" in s:
            key, _, val = s.partition(":")
            key, val = key.strip(), val.strip()
            if val.startswith("[") and val.endswith("]"):
                parent[key] = [v.strip().strip("'\"") for v in val[1:-1].split(",") if v.strip()]
            elif val.startswith("{") and val.endswith("}"):
                inner = {}
                for m in re.finditer(r"(\w+):\s*(\[[^\]]*\]|\"[^\"]*\"|'[^']*'|[^,}]+)", val[1:-1]):
                    k2, v2 = m.group(1), m.group(2).strip()
                    if v2.startswith("["):
                        inner[k2] = [v.strip().strip("'\"") for v in v2[1:-1].split(",") if v.strip()]
                    else:
                        inner[k2] = v2.strip("'\"")
                parent[key] = inner
            elif val:
                parent[key] = val.strip("'\"")
            else:
                parent[key] = {}
                stack.append((ind, parent[key]))
            last_key_at[ind] = (parent, key)
    return data


def load_rules(path: str | None) -> tuple[dict[str, list[str]], dict[str, str], str]:
    candidates = [path] if path else ["risk.yml", ".github/risk.yml", "docs/agents/risk.yml"]
    for p in candidates:
        if p and os.path.isfile(p):
            text = open(p, encoding="utf-8").read()
            try:
                import yaml  # type: ignore
                data = yaml.safe_load(text) or {}
            except ImportError:
                data = parse_simple_yaml(text)
            rules: dict[str, list[str]] = {}
            why: dict[str, str] = {}
            levels = data.get("levels", data)
            for lvl in ("high", "medium", "low", "skip"):
                v = levels.get(lvl, data.get(lvl))
                if isinstance(v, dict):
                    rules[lvl] = list(v.get("paths", []) or [])
                    if v.get("why"):
                        why[lvl] = str(v["why"])
                elif isinstance(v, list):
                    rules[lvl] = [str(x) for x in v]
            return rules, why, p
    return DEFAULTS, {}, "built-in defaults (no risk.yml found)"


def changed_files(base: str) -> list[str]:
    def run(*cmd: str) -> list[str]:
        r = subprocess.run(cmd, capture_output=True, text=True)
        return [l for l in r.stdout.splitlines() if l.strip()] if r.returncode == 0 else []
    files = run("git", "diff", "--name-only", f"{base}...HEAD")
    files += run("git", "diff", "--name-only", "HEAD")
    files += run("git", "ls-files", "--others", "--exclude-standard")
    return sorted(set(files))


def classify(f: str, rules: dict[str, list[str]]) -> tuple[str, str]:
    # skip first (generated wins), then highest level first
    for lvl in ("skip", "high", "medium", "low"):
        for pat in rules.get(lvl, []):
            if glob_to_re(pat).match(f) or fnmatch.fnmatch(os.path.basename(f), pat):
                return lvl, pat
    return "medium", "(unmatched: default medium)"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="*")
    ap.add_argument("--risk-file")
    ap.add_argument("--base", default="origin/main")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    rules, why, source = load_rules(a.risk_file)
    files = a.files or changed_files(a.base)
    rows = [(f, *classify(f, rules)) for f in files]
    reviewed = [r for r in rows if r[1] != "skip"]
    overall = max((r[1] for r in reviewed), key=lambda l: ORDER[l], default="skip")
    if a.json:
        print(json.dumps({"source": source, "overall": overall, "plan": PLAN[overall],
                          "files": [{"path": f, "level": l, "rule": p} for f, l, p in rows]}, indent=2))
        return 0
    print(f"risk rules: {source}")
    for f, l, p in sorted(rows, key=lambda r: (-ORDER[r[1]], r[0])):
        print(f"{l:6}  {f}  [{p}]")
    print(f"overall: {overall}" + (f" ({why[overall]})" if overall in why else ""))
    print(f"plan: {PLAN[overall]}")
    if not files:
        print("no changed files found: pass files or --base", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
