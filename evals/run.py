#!/usr/bin/env python3
"""Run agent-kit evals with `claude -p` against the local plugin.

Usage (from the agent-kit root):
  python3 evals/run.py list                          # show cases, no model calls
  python3 evals/run.py triggers [--only rev-1,gt-1] [--runs 1] [--model <id>]
  python3 evals/run.py reviewer [--only app-debug-true] [--model <id>]
  python3 evals/run.py all
  python3 evals/run.py check                         # offline: case files, shared refs, helper script tests

Triggers: each query runs in an empty temp git repo with only the plugin loaded
(`--plugin-dir plugins/arffornia`), tools limited to Skill/Read/Glob/Grep in `dontAsk` mode, so
nothing can change. Pass = the arffornia skill was (or, for should_trigger=false, was not)
invoked through the Skill tool as `arffornia:<skill>` (bundled\nskills such as /review and /verify share short names and do not count). With --runs N, the majority decides.

Reviewer: builds a temp git repo (base commit on main, head commit on a branch) from
evals/reviewer/<case>/{base,head} (and evals/reviewer-held/, git-ignored, when present), then has the main session delegate to the `arffornia:reviewer` subagent
on it as a subagent (as in real use) with read-only tools. Pass = the `Findings:` line parses and the counts and regexes in
case.json hold. Outputs go to evals/.results/<timestamp>/ (git-ignored).
Exit code: 0 all passed, 1 a case failed, 2 setup error (no claude CLI, bad case file).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLUGIN = os.path.join(ROOT, "plugins", "arffornia")
EVALS = os.path.join(ROOT, "evals")
FINDINGS = re.compile(r"Findings:\s*(\d+)\s*\(\s*blocking\s*(\d+)\s*,\s*major\s*(\d+)", re.I)


def claude_env() -> dict:
    env = dict(os.environ)
    env.pop("CLAUDECODE", None)  # allow nesting inside a Claude Code session
    env["CLAUDE_CODE_DISABLE_BACKGROUND_TASKS"] = "1"  # forked skills answer in the same run
    env["CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH"] = "3"   # the reviewer spawns finders and verifiers (default depth)
    return env


def need_claude() -> None:
    if not shutil.which("claude"):
        print("claude CLI not found: install Claude Code to run evals (`check` and `list` work without it)", file=sys.stderr)
        sys.exit(2)


def load_triggers() -> list[dict]:
    return json.load(open(os.path.join(EVALS, "triggers", "cases.json"), encoding="utf-8"))


def load_reviewer() -> list[dict]:
    """Public cases in reviewer/, plus held cases in reviewer-held/ (git-ignored) when present:
    cases that mirror security findings not fixed yet stay out of the public repo."""
    out = []
    for sub in ("reviewer", "reviewer-held"):
        base = os.path.join(EVALS, sub)
        if not os.path.isdir(base):
            continue
        for d in sorted(os.listdir(base)):
            p = os.path.join(base, d, "case.json")
            if os.path.isfile(p):
                with open(p, encoding="utf-8") as f:
                    c = json.load(f)
                c["_dir"] = os.path.join(base, d)
                out.append(c)
    return out


def run_trigger(case: dict, model: str | None, timeout: int) -> bool:
    with tempfile.TemporaryDirectory(prefix="ak-trig-") as tmp:
        subprocess.run(["git", "init", "-q", tmp], check=True)
        cmd = ["claude", "-p", case["query"], "--plugin-dir", PLUGIN, "--output-format", "stream-json", "--verbose",
               "--permission-mode", "dontAsk", "--allowedTools", "Skill", "Read", "Glob", "Grep", "--max-turns", "4"]
        if model:
            cmd += ["--model", model]
        try:
            p = subprocess.Popen(cmd, cwd=tmp, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, env=claude_env())
        except OSError as e:
            print(f"cannot start claude: {e}", file=sys.stderr)
            return False
        triggered, start = False, time.time()
        try:
            for line in p.stdout:  # type: ignore[union-attr]
                if time.time() - start > timeout:
                    break
                try:
                    ev = json.loads(line)
                except json.JSONDecodeError:
                    continue
                msg = ev.get("message") if isinstance(ev, dict) else None
                content = msg.get("content") if isinstance(msg, dict) else None
                for block in content if isinstance(content, list) else []:
                    if isinstance(block, dict) and block.get("type") == "tool_use" and block.get("name") == "Skill":
                        name = str((block.get("input") or {}).get("skill", ""))
                        # strict: the bundled /review, /verify, /debug... share short names
                        if name == f"arffornia:{case['skill']}":
                            triggered = True
                if triggered:
                    break
        finally:
            p.kill()
            p.wait()
        return triggered


def cmd_triggers(a) -> int:
    need_claude()
    cases = [c for c in load_triggers() if not a.only or c["id"] in a.only.split(",")]
    def one(c):
        votes = [run_trigger(c, a.model, a.timeout) for _ in range(a.runs)]
        got = sum(votes) * 2 > len(votes)
        return c, got, votes
    fails = 0
    with ThreadPoolExecutor(max_workers=a.workers) as ex:
        for c, got, votes in ex.map(one, cases):
            ok = got == c["should_trigger"]
            fails += not ok
            print(f"{'PASS' if ok else 'FAIL'}  {c['id']:<8} {c['skill']:<16} expected={'trigger' if c['should_trigger'] else 'no-trigger'} "
                  f"got={'trigger' if got else 'no-trigger'} ({sum(votes)}/{len(votes)})  {c['query'][:70]}")
    print(f"triggers: {len(cases) - fails}/{len(cases)} passed")
    return 1 if fails else 0


def build_repo(case: dict, tmp: str) -> None:
    def sh(*args: str) -> None:
        r = subprocess.run(args, cwd=tmp, capture_output=True, text=True)
        if r.returncode != 0:
            raise RuntimeError(f"{' '.join(args)}: {r.stderr.strip() or r.stdout.strip()}")
    sh("git", "init", "-q", "-b", "main")
    sh("git", "config", "user.email", "eval@agent-kit.invalid")
    sh("git", "config", "user.name", "agent-kit eval")
    sh("git", "config", "commit.gpgsign", "false")  # throwaway fixture repo, never pushed
    shutil.copytree(os.path.join(case["_dir"], "base"), tmp, dirs_exist_ok=True, copy_function=shutil.copy)
    sh("git", "add", "-A")
    sh("git", "commit", "-q", "-m", "base")
    sh("git", "switch", "-q", "-c", "feature")
    for root, _, files in os.walk(tmp):
        if "/.git" in root:
            continue
        for f in files:
            os.remove(os.path.join(root, f))
    shutil.copytree(os.path.join(case["_dir"], "head"), tmp, dirs_exist_ok=True, copy_function=shutil.copy)
    sh("git", "update-index", "-q", "--really-refresh")  # same size + same mtime would look unchanged
    sh("git", "add", "-A")
    sh("git", "commit", "-q", "-m", case["pr_title"])
    sh("git", "update-ref", "refs/remotes/origin/main", "main")


def run_reviewer(case: dict, model: str | None, outdir: str, timeout: int) -> tuple[bool, str]:
    with tempfile.TemporaryDirectory(prefix="ak-rev-") as tmp:
        build_repo(case, tmp)
        task = (f"Review the branch `feature` against `main` in this repository ({case['repo']}). It is not on GitHub: "
                f"use git diff main...feature and read files locally.\n\nPR title: {case['pr_title']}\n\nPR body:\n{case['pr_body']}")
        # The reviewer runs as a subagent, as in real use: `skills:` preloading applies to subagents,
        # not to a main-thread `--agent` session.
        prompt = ("Delegate this review to the arffornia:reviewer subagent with the Agent tool, passing the task below "
                  "verbatim. Do not review it yourself. Then print the subagent's answer verbatim and nothing else.\n\n"
                  f"TASK:\n{task}")
        cmd = ["claude", "-p", prompt, "--plugin-dir", PLUGIN, "--output-format", "json",
               "--permission-mode", "dontAsk", "--allowedTools", "Read", "Glob", "Grep", "Agent", "Skill",
               "Bash(git *)", "Bash(python3 *)", "Bash(grep *)", "Bash(rg *)", "Bash(ls *)", "Bash(cat *)",
               "Bash(head *)", "Bash(tail *)", "Bash(sed -n *)", "Bash(wc *)", "Bash(find *)", "Bash(cd *)"]
        if model:
            cmd += ["--model", model]
        try:
            r = subprocess.run(cmd, cwd=tmp, capture_output=True, text=True, timeout=timeout, env=claude_env())
        except subprocess.TimeoutExpired:
            return False, "timeout"
    try:
        text = json.loads(r.stdout).get("result", "")
    except json.JSONDecodeError:
        text = r.stdout
    with open(os.path.join(outdir, f"{case['id']}.md"), "w", encoding="utf-8") as f:
        f.write(text)
    m = FINDINGS.search(text)
    if not m:
        return False, "no parsable 'Findings: N (blocking b, major m' line"
    blocking = int(m.group(2))
    exp = case["expect"]
    why = []
    if "min_blocking" in exp and blocking < exp["min_blocking"]:
        why.append(f"blocking {blocking} < {exp['min_blocking']}")
    if "max_blocking" in exp and blocking > exp["max_blocking"]:
        why.append(f"blocking {blocking} > {exp['max_blocking']}")
    for rx in exp.get("must_match", []):
        if not re.search(rx, text, re.I):
            why.append(f"missing /{rx}/")
    for rx in exp.get("must_not_match", []):
        if re.search(rx, text):
            why.append(f"unexpected /{rx}/")
    return not why, "; ".join(why) or f"blocking={blocking}"


def cmd_reviewer(a) -> int:
    need_claude()
    cases = [c for c in load_reviewer() if not a.only or c["id"] in a.only.split(",")]
    outdir = os.path.join(EVALS, ".results", time.strftime("%Y%m%d-%H%M%S"))
    os.makedirs(outdir, exist_ok=True)
    fails = 0
    with ThreadPoolExecutor(max_workers=a.workers) as ex:
        for c, (ok, why) in zip(cases, ex.map(lambda c: run_reviewer(c, a.model, outdir, a.timeout * 25), cases)):
            fails += not ok
            print(f"{'PASS' if ok else 'FAIL'}  {c['id']:<32} {why}")
    print(f"reviewer: {len(cases) - fails}/{len(cases)} passed · outputs in {outdir}")
    return 1 if fails else 0


def cmd_check(_a) -> int:
    bad = 0
    names = {d for d in os.listdir(os.path.join(PLUGIN, "skills")) if os.path.isfile(os.path.join(PLUGIN, "skills", d, "SKILL.md"))}
    ids = set()
    for c in load_triggers():
        for k in ("id", "skill", "should_trigger", "query"):
            if k not in c:
                print(f"trigger case missing '{k}': {c}"); bad += 1
        if c.get("skill") not in names:
            print(f"trigger case {c.get('id')}: unknown skill {c.get('skill')}"); bad += 1
        if c.get("id") in ids:
            print(f"duplicate trigger id {c.get('id')}"); bad += 1
        ids.add(c.get("id"))
    for c in load_reviewer():
        for sub in ("base", "head"):
            if not os.path.isdir(os.path.join(c["_dir"], sub)):
                print(f"reviewer case {c['id']}: missing {sub}/"); bad += 1
        for k in ("id", "source", "pr_title", "pr_body", "expect"):
            if k not in c:
                print(f"reviewer case {c.get('id')}: missing '{k}'"); bad += 1
        for rx in c.get("expect", {}).get("must_match", []) + c.get("expect", {}).get("must_not_match", []):
            try:
                re.compile(rx)
            except re.error as e:
                print(f"reviewer case {c['id']}: bad regex {rx}: {e}"); bad += 1
    sync = os.path.join(PLUGIN, "skills", "_shared", "sync.sh")
    if os.path.isfile(sync) and subprocess.run([sync, "--check"]).returncode != 0:
        bad += 1
    t = subprocess.run([sys.executable, os.path.join(EVALS, "test_helpers.py")], capture_output=True, text=True)
    if t.returncode != 0:
        print(t.stderr[-2000:]); bad += 1
    else:
        print("helper script tests: " + (t.stderr.strip().splitlines() or ["ok"])[-1])
    covered = {c["skill"] for c in load_triggers()}
    missing = sorted(names - covered)
    if missing:
        print(f"skills without a trigger case: {', '.join(missing)}")
    print(f"check: {'ok' if not bad else f'{bad} problem(s)'} · {len(ids)} trigger cases, {len(load_reviewer())} reviewer cases")
    return 1 if bad else 0


def cmd_list(_a) -> int:
    for c in load_triggers():
        print(f"trigger   {c['id']:<8} {c['skill']:<16} {'+' if c['should_trigger'] else '-'}  {c['query']}")
    for c in load_reviewer():
        print(f"reviewer  {c['id']:<32} {c['expect']}  ({c['source'][:60]}...)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("what", choices=["list", "check", "triggers", "reviewer", "all"])
    ap.add_argument("--only")
    ap.add_argument("--runs", type=int, default=1)
    ap.add_argument("--model")
    ap.add_argument("--workers", type=int, default=3)
    ap.add_argument("--timeout", type=int, default=120, help="seconds per trigger run (reviewer: x25; finders + per-candidate verifiers take 20-40 min)")
    a = ap.parse_args()
    if a.what == "list":
        return cmd_list(a)
    if a.what == "check":
        return cmd_check(a)
    if a.what == "triggers":
        return cmd_triggers(a)
    if a.what == "reviewer":
        return cmd_reviewer(a)
    rc = cmd_check(a) or 0
    return max(rc, cmd_triggers(a), cmd_reviewer(a))


if __name__ == "__main__":
    sys.exit(main())
