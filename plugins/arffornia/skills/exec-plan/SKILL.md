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
2. Copy the repo's `docs/exec-plans/TEMPLATE.md` (from agent-kit `templates/`) to
   `docs/exec-plans/active/<YYYY-MM-DD>-<slug>.md`; without one, use
   [references/template.md](references/template.md) (same sections). Fill every section; delete
   none. Link the plan from the "Now" block of `PROGRESS.md`.
3. Milestones are independently verifiable: each has the exact command that proves it
   (`make check`, a GameTest name, a Playwright spec, a curl) and what its output looks like.
   Prefer small milestones that each end in a mergeable PR.
4. Write `tasks.json` next to it (format in the template): one task per PR-sized step with
   `id`, `title`, `status`, `verify`, `depends_on`, `evidence`. Agents update JSON; the
   Markdown is for humans.
5. Questions that need Brian go in the `Decision log` as a pending row (options, your
   recommendation, "Decided by: maintainer, pending") and, when they block, to an issue
   labelled `needs-decision`. Do not pick an option for him.
6. Commit: `docs(plan): add <slug> exec plan`.

## update

Before stopping and after each milestone: tick `Progress` with a UTC timestamp, fill
`Verification evidence`, add rows to the `Decision log` table, append to `Surprises and
follow-ups` (with evidence), and set task statuses and evidence links in `tasks.json`. If
the plan turned out wrong, revise it in place and say why in the decision log; the plan must
always describe the current intent.

## close <slug>

Every box ticked and the verification evidence filled; add what shipped (PR links), what did
not, and what to do differently under `Surprises and follow-ups`, then `git mv` the plan to
`docs/exec-plans/completed/`. Gotchas worth keeping go to `AGENTS.md` or a `.claude/rules/`
file as one line plus a pointer.

Report per [references/reporting.md](references/reporting.md): the plan URL or path, the next
task with its verify command, and pending decisions as links.
