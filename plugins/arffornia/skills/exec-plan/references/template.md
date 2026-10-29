# Exec plan template

Use the repo's `docs/exec-plans/TEMPLATE.md` when it exists (agent-kit ships it in
`templates/docs/exec-plans/TEMPLATE.md`). This fallback has the same sections, plus
"Context" for a reader who has never seen the repo and a `tasks.json` for long runs.
Self-contained, living, verifiable, with the decision log kept in the file (after OpenAI's
ExecPlans and Anthropic's long-running harness notes).

```markdown
# <Title: the outcome, not the activity>

Status: active · Owner: <agent/session or person> · Started: <YYYY-MM-DD> · Issue: <full URL>
Spec / ADR: <full URL> - <one line>

## Goal
What is true when this is done, in 2-3 sentences, and what is explicitly out of scope.

## Context
Files and modules involved (paths), terms in plain words, what exists today. Written for
someone who has never seen the repo.

## Acceptance criteria
- [ ] <observable, testable>

## Plan
1. <step> — verify: `./gradlew runGameTestServer --no-daemon -Dorg.gradle.jvmargs=-Xmx2g`
   → `All N required tests passed :)` including `machineCraftsWithEnergy`; ships as one PR
2. <step> — verify: <command and expected output>

## Progress
- [x] (2026-10-29 14:15Z) Step 0: spike, FE capability registration works for two BE types
- [ ] Step 1
- [ ] Docs, AGENTS.md and rules updated (or "unchanged: <reason>")
- [ ] PR opened: <full URL>

## Decision log
| Date | Decision | Options considered | Why | Decided by |
|---|---|---|---|---|
| 2026-10-29 | <what> | <A / B> | <reason> | <maintainer / agent (reversible only)> |

## Verification evidence
```text
$ make check
<tail of the output>
```
- Tests added: <names>
- Manual / e2e evidence: <screenshot path, GameTest name, rendered manifest diff>

## Surprises and follow-ups
- <observation> - evidence: <log line / link>; follow-up issue: <URL>
```

`tasks.json` (same folder, same basename), for runs longer than a session:

```json
{
  "plan": "2026-10-29-machine-framework",
  "updated": "2026-10-29T14:15:00Z",
  "tasks": [
    {"id": "S1", "title": "MachineType registry + one BE type", "status": "doing",
     "verify": "./gradlew runGameTestServer --no-daemon -Dorg.gradle.jvmargs=-Xmx2g",
     "depends_on": [], "evidence": [], "pr": null},
    {"id": "S2", "title": "Port Crafter onto the framework", "status": "todo",
     "verify": "GameTest crafter* all green", "depends_on": ["S1"], "evidence": [], "pr": null}
  ]
}
```

Statuses: `todo`, `doing`, `done`, `blocked` (with `"blocked_on": "<URL>"`), `dropped` (with a
reason). Never delete a task. Validate with `jq . tasks.json >/dev/null`.
