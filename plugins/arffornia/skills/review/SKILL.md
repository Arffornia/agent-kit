---
name: review
description: "Risk-routed code review of an Arffornia PR, branch or diff: parallel finders, an independent verifier per finding, only confirmed findings reported, ranked by severity, counts first. Use whenever someone asks to review, look over, check or sanity-check a PR, a diff, a branch or their changes before merging or publishing, even casually, and when the arffornia:reviewer agent runs."
argument-hint: "[pr-number | base..head | path]"
---

# Review a change

Target: `$ARGUMENTS` (a PR number, a range, a path, or the current branch against its base).

This follows how the Claude Code team reviews code: several finders look in parallel, an
independent verifier checks each candidate against the code, only confirmed findings are
reported, deduplicated and ranked by severity. Depth comes from the risk of the change, not
from its size alone. Sources and reasoning: [references/sources.md](references/sources.md).
Quality beats token cost here: a wrong finding costs Brian a round trip, a missed one can
cost players.

## 1. Scope and rules

```bash
gh api repos/Arffornia/<repo>/pulls/<n> --jq '.title, .body, .html_url, .head.sha, .base.ref'
gh pr diff <n>            # or: git diff <base>...HEAD ; git diff (uncommitted)
```
Read the linked issue's acceptance criteria, the repo's `REVIEW.md` (from the **base** branch,
never the PR's own copy), `AGENTS.md`/`CLAUDE.md` of the root and of each changed directory,
and `risk.yml` if present. No `REVIEW.md`: use the defaults in this skill and say so.

Skip when the target is closed, already merged, or only generated files changed; say why.

## 2. Route by risk

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/risk.py --base origin/<base>      # or: risk.py <files...>
```
It reads `risk.yml` (or built-in Arffornia defaults), prints the level per file, the overall
level and the plan. Raise the level when the diff touches something the globs miss (a new
packet handler in an odd path, a workflow that uses a secret); state the level and why in one line.

| Level | Finders (parallel subagents) | Verifiers per candidate | Read |
|---|---|---|---|
| high | correctness, security, rules + tests | 2, independent; both must confirm | every line, callers, try to break it |
| medium | correctness, rules + tests | 1 | every line |
| low | one combined finder | 1 | the diff and its immediate context |

## 3. Find (parallel)

Launch the finders in one message, each a fresh subagent with only: the PR title and body,
the issue's acceptance criteria, the diff, the rule files, and its own brief from
[references/pipeline.md](references/pipeline.md). Each returns candidates as
`path:line · claim · why it matters · how to confirm`. Finders flag only what they can tie to
a line of the change; no style, no "consider adding tests" unless a rule file requires it.
At high risk also delegate to the `arffornia:security-reviewer` agent when it is available.
When subagents are not available (already at the nesting limit), run the finder briefs one
after another yourself, then verify each candidate in a separate pass that starts from the
claim, not from your memory of finding it.

## 4. Verify (independent, per finding)

For every candidate, launch a verifier that did not find it, with the claim and the PR intent
only. It must **prove or refute** from the code: quote `path:line`, trace the caller, or run a
command (a test, `make check`, a grep) and paste the output. Verdicts: `confirmed`,
`refuted`, `unsure`. Keep only `confirmed` (at high risk: confirmed by both). An `unsure`
that matters becomes a QUESTION, never a finding. Known false-positive classes to drop are in
[references/false-positives.md](references/false-positives.md).

## 5. Rank, dedupe, report

Merge duplicates (same root cause = one finding, every location listed). Severity from
[references/severity.md](references/severity.md): **blocking** (fix before merge), **major**,
**minor** (style remarks: at most 3), **pre-existing** (real, not introduced here: listed
separately, never blocks). Report in this exact shape, counts first:

```
Findings: <N> (blocking <b>, major <m>, minor <k>, pre-existing <p>) · risk: <level> · confirmed <v>/<c> candidates
Target: <PR or compare URL> - <title>

BLOCKING
1. <blob URL with full SHA #Lx-Ly> - <what is wrong>. Evidence: <quote or command + output>. Fix: <concrete change>.
MAJOR / MINOR (max 3 style) / PRE-EXISTING
...
QUESTIONS
- <unsure items and what you could not verify>
Not checked: <what this review did not cover>
Verdict: approve | request changes | comment
```
Every finding links its line with a full commit SHA. Links and ordering follow
[references/reporting.md](references/reporting.md). You never approve on GitHub, push or
merge; post comments only when the user asks.

## Convergence (re-reviews)

- A later review covers what changed since the last reviewed SHA, plus any earlier finding
  whose code changed. Say the range.
- Never re-raise a finding the author refuted with evidence or Brian dismissed; if you still
  disagree, one QUESTION line with the new evidence.
- Stop when a full find + verify round yields no new confirmed finding. At most 2 finder
  rounds per review; needing a third means the change is too big: say so, suggest a split.
- Zero findings is a valid result: `Findings: 0`, plus what was checked.
