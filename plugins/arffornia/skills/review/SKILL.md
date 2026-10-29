---
name: review
description: Risk-based code review of an Arffornia pull request or branch, following the repo's REVIEW.md, with evidence (file:line) for every finding and the findings count first. Use when asked to review a PR, a diff or a branch, or before publishing your own work.
argument-hint: "[pr-number | base..head]"
---

# Review a change

Target: `$ARGUMENTS` (a PR number, a range, or the current branch against its base).

## 1. Load the rules

Read the repo's `REVIEW.md` (risk areas, what to always check, what to skip) and `AGENTS.md`
(hard rules). If there is no `REVIEW.md`, use the defaults below and say so.

## 2. Get the change

```bash
gh api repos/Arffornia/<repo>/pulls/<n> -q '.title, .body'   # intent and linked issue
gh pr diff <n>   # or: git diff <base>...HEAD
```
Read the linked issue's acceptance criteria. Read the surrounding code, not only the hunks.

## 3. Choose depth by risk

| Risk | Typical files | Depth |
|---|---|---|
| High | auth, tokens, secrets, network input, payload/packet handlers, payments/shop, downloads and paths, release workflows, `main`-is-live content | Read every line, trace callers, try to break it |
| Medium | business logic, persistence, concurrency, public APIs, migrations | Read every line, check tests cover the change |
| Low | docs, comments, tests only, formatting, renames | Skim for correctness |

State the level you chose and why in one line.

## 4. Check

- Does it do what the issue asks, and nothing else? Does it change behaviour without a ticket?
- Correctness: edge cases, error paths, null/empty, timeouts, retries bounded.
- Security: untrusted input validated server side, no secret in code or logs, paths confined.
- Tests: a test fails without the change; the PR shows the command output.
- Arffornia rules: English, player text via i18n in en+fr, Nexus libraries not replaced, no merge or
  release steps.

**Evidence is required.** Every finding cites `path:line` and what you saw (quote the code, or the
command and its output). No evidence, no finding: write it as a question instead.

**At most 3 style remarks**, and only if they hurt readability. Formatting is the formatter's job.

## 5. Report (this format, findings count first)

```
Findings: <N> (blocking <b>, major <m>, minor <k>) · risk: <high|medium|low>

BLOCKING
1. path/file.ext:42 - <what is wrong>. Evidence: <quote or output>. Fix: <concrete change>.
MAJOR
...
MINOR / STYLE (max 3)
...
QUESTIONS
- <things you could not verify>

Verdict: approve | request changes | comment
```

`blocking` = wrong behaviour, security hole, data loss, broken build. `major` = a reviewer would
stop on it. Say what you did not check. You never approve on GitHub, push, or merge: you report.
