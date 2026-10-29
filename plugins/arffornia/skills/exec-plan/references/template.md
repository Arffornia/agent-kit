# Exec plan template

Inspired by OpenAI's ExecPlans (PLANS.md) and Anthropic's long-running agent harness notes:
self-contained, living, verifiable, with the decision log kept in the file.

```markdown
# <Short imperative title>

| | |
|---|---|
| **Status** | active · started 2026-10-29 · owner: <agent/session or person> |
| **Issues** | https://github.com/Arffornia/<repo>/issues/<n> - <one line> |
| **Spec / ADR** | https://arffornia.github.io/docs/specs/002-machine-framework/ - <one line> |
| **Repos** | Arffornia_Mods (code), docs (spec updates) |

## Purpose
What a player, admin or developer can do after this that they cannot do now, in 2-4
sentences. How to see it working.

## Context and orientation
The files and modules involved, with paths; terms defined in plain words; what exists today.
Written for someone who has never seen the repo.

## Plan of work
Milestones in order. Each one:
### M1 · <name>
- Change: <files, what>
- Verify: `./gradlew runGameTestServer --no-daemon -Dorg.gradle.jvmargs=-Xmx2g` → `All N required tests passed :)`
  including `machineCraftsWithEnergy`
- Ships as: one PR `feat(machine): ...`
- Rollback: <how to undo>

## Progress
- [ ] M1 · <name>
- [x] (2026-10-29 14:15Z) M0 · spike: FE capability registration works for two BE types

## Surprises & discoveries
- <observation> - evidence: <log line / link>

## Decision log
- Decision: <what>. Rationale: <why>. Date/Author: 2026-10-29 / <who>.

## Open questions
- <question> - options A/B, recommendation, blocking? - <needs-decision issue URL>

## Outcomes & retrospective
<filled at close: shipped (PR links), not shipped, lessons>
```

`tasks.json` (same folder, same basename):

```json
{
  "plan": "2026-10-29-machine-framework",
  "updated": "2026-10-29T14:15:00Z",
  "tasks": [
    {"id": "M1", "title": "MachineType registry + one BE type", "status": "doing",
     "verify": "./gradlew runGameTestServer --no-daemon -Dorg.gradle.jvmargs=-Xmx2g",
     "depends_on": [], "evidence": [], "pr": null},
    {"id": "M2", "title": "Port Crafter onto the framework", "status": "todo",
     "verify": "GameTest crafter* all green", "depends_on": ["M1"], "evidence": [], "pr": null}
  ]
}
```

Statuses: `todo`, `doing`, `done`, `blocked` (with `"blocked_on": "<URL>"`). Never delete a
task: mark it `dropped` with a reason. Validate with `jq . tasks.json >/dev/null`.
