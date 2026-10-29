---
name: debug
description: "Find and prove the root cause of a bug before fixing it: reproduce, hypothesise, test each hypothesis, fix the cause, add a regression test that failed before. Use whenever something crashes, throws, errors, hangs or misbehaves (a stack trace, a null or undefined error, a failing test or CI run, a player bug report), when asked why something breaks or to find out why, and when a previous fix did not work."
argument-hint: "<symptom, issue number or failing command>"
---

# Debug: root cause first

Symptom: `$ARGUMENTS`. No fix is written until the cause is proven. A fix for a guessed cause
hides the bug and adds a second one. If you catch yourself editing code "to see if it helps",
stop and go back to step 2.

## 1. Reproduce

Get a command that shows the failure every time, as small and fast as possible:
a failing test, a `curl`, a GameTest, a Playwright spec, a script. Write down the exact
command, the expected result and the actual one (paste the output). Per-stack recipes:
[references/techniques.md](references/techniques.md).

Cannot reproduce: collect more facts (logs with timestamps, versions, the player's config,
CI run URL) and say so. Do not fix what you cannot see fail.

## 2. Hypothesise

List 2-4 candidate causes, each with a prediction that would distinguish it from the others
("if the token cache is stale, the second request after a 401 still sends the old token").
Start from facts: the stack trace's first frame in our code, the diff since the last good
state (`git log --oneline <good>..<bad>`, `git bisect`), what changed in config or data.

## 3. Test the hypotheses

One experiment per hypothesis: a log line, a breakpoint, an assertion, a smaller input, a
bisect step. Record each result in a short table (hypothesis · experiment · result ·
kept/rejected). The cause is proven when you can turn the failure on and off by changing
that one thing.

```bash
git bisect start <bad> <good> && git bisect run <repro-command>   # when a regression has a known good commit
```

## 4. Fix the cause

The smallest change at the cause, not at the symptom (do not catch-and-ignore the exception,
do not add a retry around a race). If the cause is in a Nexus_* library, fix it there (or open
an issue there) instead of working around it in the caller.

## 5. Regression test

A test that runs the reproduction and **failed before the fix** (show both runs). Then the
full `make check`. Remove debug logging you added, unless it is useful at `debug` level and
never logs secrets.

## 6. Write it down

In the PR or the issue: symptom, root cause (with `path:line` links), why it was not caught,
the fix, the test, and the hypothesis table. If the cause class can recur (a missing timeout,
an unvalidated packet), propose a guard: a lint, an ArchUnit test, a rule line in `AGENTS.md`.
Report per [references/reporting.md](references/reporting.md).
