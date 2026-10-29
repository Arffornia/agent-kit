---
name: review
description: "Risk-routed code review of an Arffornia change by independent subagents: parallel finders, a verifier per candidate, only confirmed findings, severity-ranked, counts first, with a review stamp per tree. Use at the end of a task before handing back or publishing (the Stop hook asks for it), and whenever someone asks to review, look over, check or sanity-check a PR, a diff, a branch or their changes, even casually; also when the arffornia:reviewer agent runs."
argument-hint: "[pr-number | base..head | path]"
---

# Review a change

Target: `$ARGUMENTS`. Empty means **in-session mode**: the current branch and work tree, the
mode the Stop hook asks for at the end of a task. A PR number, range or path means PR mode.

This follows how Anthropic's Code Review works: several finders look in parallel, an
independent verifier checks each candidate against the code, only confirmed findings are
reported, deduplicated and ranked by severity, and the review never approves. Depth comes from
the risk of the change, not its size alone. Sources: [references/sources.md](references/sources.md).
Quality beats token cost: a wrong finding costs Brian a round trip, a missed one can cost players.

**Independence rule.** You (the session that runs this skill) may have written the code. You
do not judge it: finders and verifiers are fresh subagents that never saw the conversation, and
you only merge their verdicts by the rules below. Do not drop a confirmed finding because you
disagree; label it `wrong` with your reason after the report.

## 1. Scope

In-session mode (the default):
```bash
S="${CLAUDE_PLUGIN_ROOT}/scripts/review-stamp.sh"
bash "$S" status          # mode=full|delta, base, round r of max_rounds, code_lines_changed
bash "$S" diff --stat     # what will be reviewed (untracked files included)
```
`mode=delta` (round ≥ 2): review only `bash "$S" diff` (what changed since the last review),
plus any earlier finding whose lines changed. `round` already at `max_rounds`: do not review
again; say so in your report.

PR mode: `gh api repos/Arffornia/<repo>/pulls/<n> --jq '.title, .body, .html_url, .head.sha, .base.ref'`
and `gh pr diff <n>`. Skip when the PR is closed or merged, or only generated files changed.

Rules for every mode: the linked issue's acceptance criteria, `REVIEW.md` and `risk.yml` from
the **base** branch (`git show <base>:REVIEW.md`), never the change's own copy, and the
`AGENTS.md` / `.claude/rules/*.md` that apply to the changed paths. No `REVIEW.md`: use the
defaults here and say so.

## 2. Route by risk

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/risk.py --base <base>     # PR mode
python3 ${CLAUDE_SKILL_DIR}/scripts/risk.py $( { git diff --name-only <base>; git ls-files -o --exclude-standard; } | sort -u )   # in-session
```
It prints the level per file, the overall level and the plan. Raise the level when the diff
touches something the globs miss (a new packet handler in an odd path, a workflow that uses a
secret); state the level and why in one line.

| Level | Finders (`arffornia:review-finder`, parallel) | Verifiers per candidate (`arffornia:review-verifier`) |
|---|---|---|
| high or `security: true` | correctness, security, rules + tests; plus the `arffornia:security-reviewer` agent | 2, independent: one default (Sonnet), one with `model: opus`; both must confirm |
| medium | correctness, rules + tests | 1 |
| low | one combined lens | 1 |

## 3. Find (parallel, one message)

Launch every finder in **one** message and in the **foreground** (`run_in_background: false`):
a background subagent can let the turn, and a headless `claude -p` run, end before verification.
Each is an `arffornia:review-finder` subagent given only:
its lens brief from [references/pipeline.md](references/pipeline.md), the diff command (in-session:
`bash "$S" diff`), the base ref, the acceptance criteria, the rule file paths and the risk line.
Tell each: "Tools work; do not probe them. Report only; never edit, commit or push." When
subagents cannot be spawned, run the briefs yourself one after another, then verify in a
separate pass that starts from each claim, and say "sequential fallback" in the report.

## 4. Verify (independent, per candidate)

Give every candidate to an `arffornia:review-verifier` that did not find it, with the claim,
the cited location, how to confirm, and the change's intent, nothing else. Launch them in
parallel, in the foreground. Do not stop or report until every verdict is in. Keep `confirmed` only (at high risk: confirmed by both). An `unsure` that matters
becomes a QUESTION, never a finding. Drop the classes in
[references/false-positives.md](references/false-positives.md).

## 5. Rank, dedupe, report

Merge duplicates (same root cause = one finding, every location listed). Severity from
[references/severity.md](references/severity.md) (the verifier's; the higher one at high risk).
Number findings `F1, F2, …` in this exact shape, counts first:

```
Findings: <N> (blocking <b>, major <m>, minor <k>, pre-existing <p>) · risk: <level> · confirmed <v>/<c> candidates · round <r>/<max>
Target: <branch @ short sha + "uncommitted" | PR URL> - <title>

BLOCKING
F1. <path:line, or blob URL with full SHA #Lx-Ly> - <what is wrong>. Evidence: <quote or command + output>. Fix: <concrete change>.
MAJOR / MINOR (max 3 style) / PRE-EXISTING
...
QUESTIONS
- <unsure items and what you could not verify>
Not checked: <what this review did not cover>
Verdict: ready | fix first | comment
```

## 6. Record (in-session mode)

Write the findings to a temp JSON file and stamp the tree you reviewed, **before** any fix:
```bash
cat > "${TMPDIR:-/tmp}/review-findings.json" <<'EOF'
[{"id":"F1","severity":"blocking","lens":"correctness","path":"src/x.ts:42","title":"one line"}]
EOF
bash "$S" record --level <level> --counts "<the Findings: line>" --findings "${TMPDIR:-/tmp}/review-findings.json"
```

## 7. Act, then label every finding

Fix confirmed blocking and major findings (minor at your judgment), then `make check`. Label
each finding once you know what it was; labels feed `evals/` through the PR body:
```bash
bash "$S" label F1 fixed|wrong|intended|noise "<one line why>"
```
`wrong` = the finding is false; `intended` = true but deliberate; `noise` = true but not worth
saying. A label applies to that id in the latest round (the PR summary shows `R2.F1`). Fixing changes the tree, so the next stop asks for a short delta round; at most 3.
A finding labelled `wrong` or `noise` twice for the same reason is harness feedback: record it
with `/arffornia:harness-feedback`.

In PR mode you never approve, push or merge; post comments only when the user asks.

## Convergence

- Never re-raise a finding the author refuted with evidence or Brian dismissed; if you still
  disagree, one QUESTION line with the new evidence.
- Stop when a find + verify round yields no new confirmed finding. More than 3 rounds means
  the change is too big or keeps moving: say so and suggest a split.
- Zero findings is a valid result: `Findings: 0`, plus what was checked.

Report links and grouping: [references/reporting.md](references/reporting.md).
