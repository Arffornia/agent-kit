---
name: prio
description: "Propose what to work on next across Arffornia repos: rank open issues by impact x urgency / effort plus an unblock bonus, flag work in progress and items waiting on a decision. Proposes only, never moves cards or edits labels. Use when asked what to do next, to prioritise, triage, plan the week or pick the next ticket."
argument-hint: "[repos...] [--top N]"
context: fork
agent: general-purpose
background: false
---

# Prioritise (propose, never move)

Scope: `$ARGUMENTS` (repo names like `Arffornia_Mods`; default: Arffornia_Mods,
Arffornia_Website, Arffornia_Launcher_V.5.2, Arffornia_Provisioning, Arffornia_Proxy).
You run in a fresh context. You read GitHub; you never edit issues, labels, milestones or
project boards, and never comment. The output is a proposal for Brian.

## 1. Score (deterministic)

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/prio.py Arffornia/Arffornia_Mods Arffornia/Arffornia_Website \
  Arffornia/Arffornia_Launcher_V.5.2 Arffornia/Arffornia_Provisioning Arffornia/Arffornia_Proxy --top 25
```
Score = impact (type) x urgency (priority) / effort + 1.5 per issue it unblocks; open PRs
that close an issue mark it "in progress" (x0.2); `needs-decision` x0.5; `proposal` x0.3.
The weights and why: [references/scoring.md](references/scoring.md). A repo the script cannot
read is reported as unreadable, never as "nothing to do".

## 2. Apply judgement on the top 25

Read each candidate's body and comments. Adjust, and say why, when the labels are wrong or
stale: a P2 bug that now blocks a release, a security item mislabelled `type: bug`, an issue
already fixed on `main`, a duplicate, missing acceptance criteria (not really agent-ready).
Group items that one PR should cover together.

## 3. Propose

```
Next up (proposal, nothing moved):
1. <issue URL> - <title>; score 20.0 (5x4/1); agent-ready; why now: <one line>
2. ...
Needs Brian first:
- <issue URL> - <decision needed, options, recommendation>
In progress:
- <issue URL> - <PR URL>, <CI state>
Label fixes to consider:
- <issue URL> - priority: P2 -> P1 because <evidence>
Unreadable: <repo> - <error>
```
At most 10 "next up" items. Links follow [references/reporting.md](references/reporting.md).
