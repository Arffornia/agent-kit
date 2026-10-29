---
name: exec-plan
description: "Write and maintain a checked-in execution plan (docs/exec-plans/active/<slug>.md plus tasks.json) for work that spans sessions, repos or more than a day: purpose, milestones with verify commands, progress with timestamps, decision log, surprises. Use when a task is too big for one session, an issue is effort L, a spec is being implemented, or when asked to plan, resume or close a plan."
argument-hint: "new <slug> | update | close <slug>"
---

# Execution plans

A plan is the memory of multi-session work. A newcomer (or a fresh agent with no chat
history) must be able to execute it from the file alone. It lives in the repo next to the
code it changes: `docs/exec-plans/active/` while running, `docs/exec-plans/completed/` after.
Argument: `$ARGUMENTS`.

## When to write one

- The work needs more than one session, touches several repos, or is `effort: L`.
- A spec (`docs/specs/NNN-*.md` in the docs repo) or an ADR is being implemented.
- Not for a single-PR fix: the issue and the PR are enough.

## new <slug>

1. Read the issue(s), spec, ADRs, `AGENTS.md` and the code the plan will touch. Plans written
   from the issue text alone miss the real constraints.
2. Copy the structure from [references/template.md](references/template.md) to
   `docs/exec-plans/active/<YYYY-MM-DD>-<slug>.md` (or the repo's template, if agent-kit's
   `templates/` gave it one). Fill every section; delete none.
3. Milestones are independently verifiable: each has the exact command that proves it
   (`make check`, a GameTest name, a Playwright spec, a curl) and what its output looks like.
   Prefer small milestones that each end in a mergeable PR.
4. Write `tasks.json` next to it (format in the template): one task per PR-sized step with
   `id`, `title`, `status`, `verify`, `depends_on`, `evidence`. Agents update JSON; the
   Markdown is for humans.
5. Open questions that need Brian go to `## Open questions` and, when they block, to an issue
   labelled `needs-decision`. Do not pick an option for him.
6. Commit: `docs(plan): add <slug> exec plan`.

## update

Before stopping and after each milestone: tick `Progress` with a UTC timestamp, append to
`Surprises & discoveries` (with evidence) and `Decision log` (decision, rationale, date), set
task statuses and evidence links. If the plan turned out wrong, revise it in place and say
why in the decision log; the plan must always describe the current intent.

## close <slug>

Fill `Outcomes & retrospective` (what shipped with PR links, what did not, what to do
differently), then `git mv` the plan to `docs/exec-plans/completed/`. Gotchas worth keeping go
to `AGENTS.md` or a `.claude/rules/` file as one line plus a pointer.

Report per [references/reporting.md](references/reporting.md): the plan URL or path, the next
task with its verify command, and open questions as links.
