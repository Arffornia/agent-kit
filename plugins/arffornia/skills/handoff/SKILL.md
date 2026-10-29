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

Keep the file short: the newest entry on top, older entries trimmed to one line each once
they are done (history is in git). Use the repo's template when it has one
(`templates/PROGRESS.md` from agent-kit); otherwise the shape in
[references/progress-format.md](references/progress-format.md):

- **Now**: branch URL, PR URL (or "not pushed"), CI state, `make check` result with the time.
- **Done this session**: each item with its commit or PR link and a one-line summary.
- **Next step**: one concrete action the next session does first, with the exact command.
- **Open questions / blocked on**: each with who decides (Brian, upstream) and the issue link.
- **Gotchas found**: anything that cost time and is not yet in `AGENTS.md` or a rule file.
  If it will bite again, also add it there (map, not manual: one line + a pointer).

Never paste secrets, tokens or personal paths. Facts only: no "should work", say what ran.

## 3. Update the exec plan, if one is active

Tick finished steps in `Progress` with a UTC timestamp, append to `Surprises & discoveries`
and `Decision log`, and keep `tasks.json` statuses in sync. The plan format is in
[references/progress-format.md](references/progress-format.md) under "Exec plan update".

## 4. Commit the handoff

Commit `PROGRESS.md` (and the plan) on the working branch: `docs(progress): handoff <topic>`
with the session trailers. Do not push unless the user asked; a pushed branch is what makes
the handoff reach a cloud session.

## 5. Tell the human

The final message follows [references/reporting.md](references/reporting.md): the handoff
file path or URL, then Decide / Review / Act / FYI / Not done, each item a link with one line.
