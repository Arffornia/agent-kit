# Postmortem template

```markdown
# <Date> · <Short title, e.g. "Launcher could not start: duplicate mod in modList">

| | |
|---|---|
| **Status** | Draft (blameless) |
| **Severity** | SEV1 players blocked · SEV2 degraded · SEV3 internal only |
| **Duration** | 2026-10-20 18:05 → 21:40 UTC (3 h 35 min) |
| **Detected by** | player report on Discord, 18:40 (35 min after start) |
| **Repos** | Arffornia_Provisioning, Arffornia_Launcher_V.5.2 |

## Summary
Three sentences: what happened, impact, how it was fixed.

## Impact
Who, what they saw, how many, data lost (yes/no, what).

## Timeline (UTC)
| Time | Event | Source |
|---|---|---|
| 18:05 | PR merged: content(launcher): add X | https://github.com/.../pull/N |
| 18:06 | index bot commit | https://github.com/.../commit/sha |
| 18:40 | first player report | Discord #support (screenshot provided) |

## Root cause
The chain, with code links. The condition that allowed it.

## What went well
## What went wrong
## Where we got lucky

## Action items
| # | Issue title (proposed) | Labels | Prevents / detects |
|---|---|---|---|
| 1 | Fail Provisioning CI on duplicate modList entries | type: ci, area: provisioning, priority: P1 | prevents |

## Follow-up for the harness
Rules or guards that would have stopped an agent from doing the same (a hook, a lint, a
skill step), and an eval case if a review missed it.
```
