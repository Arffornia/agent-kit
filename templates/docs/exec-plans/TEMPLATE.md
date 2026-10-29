# <Title: the outcome, not the activity>

Status: active · Owner: <agent/session or person> · Started: <YYYY-MM-DD> · Issue: <full URL>

Copy to `docs/exec-plans/active/<slug>.md`. Move to `completed/` when every box is ticked and
the verification evidence is filled in. The SessionStart hook shows the newest active plan.

## Goal
<What is true when this is done, in 2-3 sentences. Include what is explicitly out of scope.>

## Acceptance criteria
- [ ] <observable, testable>
- [ ] <observable, testable>

## Plan
1. <step> — <how it will be verified>
2. <step> — <how it will be verified>

## Progress
- [ ] Step 1
- [ ] Step 2
- [ ] Docs, AGENTS.md and rules updated (or "unchanged: <reason>")
- [ ] PR opened: <full URL>

## Decision log
| Date | Decision | Options considered | Why | Decided by |
|---|---|---|---|---|
| <YYYY-MM-DD> | <what> | <A / B> | <reason> | <maintainer / agent (reversible only)> |

Design choices that are not reversible, or that the issue does not settle, are the
maintainer's: write the question here, label the issue `needs-decision`, and stop.

## Verification evidence
```text
$ make check
<tail of the output>
```
- Tests added: <names>
- Manual / e2e evidence: <screenshot path, GameTest name, rendered manifest diff>

## Surprises and follow-ups
- <What you learned that the next person needs; file issues for follow-ups and link them.>
