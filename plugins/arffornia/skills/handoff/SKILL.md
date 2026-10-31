---
name: handoff
description: "Write the session handoff so the next session starts without searching: update PROGRESS.md (and the active exec plan) with state, evidence, next step and open questions, all as links. Use when stopping mid-task, at the end of a session, before compaction, when switching tasks, or when asked to hand off, wrap up or save progress."
argument-hint: "[short note on where you stopped]"
---

# Hand off to the next session

The next session (you, another agent, or Brian) reads `PROGRESS.md` first. It must be able
to continue from it alone, without this conversation. State lives in the repo, not in chat.

## 1. Gather facts, do not recall them

```bash
git branch --show-current; git status --short; git log --oneline -5
git rev-parse HEAD; git rev-list --count origin/<base>..HEAD
gh api "repos/Arffornia/<repo>/pulls?head=Arffornia:$(git branch --show-current)" --jq '.[] | [.html_url, .state, .draft] | @tsv'
gh run list --branch "$(git branch --show-current)" --limit 3 --json url,conclusion,name 2>/dev/null
ls docs/exec-plans/active/ 2>/dev/null
```
Run the verify command the repo documents (`make check`, or the narrower one you were using)
and keep its last lines: the handoff states whether the tree is green **now**.

## 2. Update PROGRESS.md

Use the repo's template (agent-kit `templates/PROGRESS.md`: a **Now** block the SessionStart
hook shows to every session, and a **Log** the PreCompact/SessionEnd hooks append to). Shape
and an example: [references/progress-format.md](references/progress-format.md).

- **Now** (rewrite it): Goal with the issue URL; Done with branch/PR links and the verify
  result with its time; Next step as one concrete action with the exact command; Blockers /
  decisions needed with who decides and the issue link; Verify with; the active plan's path.
- **Log**: replace this session's automatic entries with one summary line, newest first.
- **Gotchas** that cost time and will bite again go to `AGENTS.md` or a `.claude/rules/`
  file (map, not manual: one line plus a pointer), not to `PROGRESS.md`.

Never paste secrets, tokens or personal paths. Facts only: no "should work", say what ran.

## 3. Update the exec plan, if one is active

Tick finished steps in `Progress` with a UTC timestamp, refresh `Verification evidence`, add
`Decision log` rows and `Surprises and follow-ups`, and keep `tasks.json` statuses in sync
(details under "Exec plan update" in [references/progress-format.md](references/progress-format.md)).

## 4. Commit the handoff

Commit `PROGRESS.md` (and the plan) on the working branch: `docs(progress): handoff <topic>`
with the session trailers. Do not push unless the user asked; a pushed branch is what makes
the handoff reach a cloud session.

## 5. Tell the human

The final message follows [references/reporting.md](references/reporting.md): the handoff
file path or URL, then Decide / Review / Act / FYI / Not done, each item a link with one line.
