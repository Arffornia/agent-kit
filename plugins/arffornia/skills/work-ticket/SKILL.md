---
name: work-ticket
description: "Take an Arffornia GitHub issue from ticket to a verified, committed branch ready to publish (branch <type>/<n>-slug, test from the acceptance criteria, implement, make check, independent review), or draft a new issue with the Arffornia label taxonomy. Use when asked to work on, pick up, fix or implement an issue, or to write, draft or backfill tickets."
argument-hint: "[issue-number | draft <topic>]"
---

# Work a ticket

`$ARGUMENTS`: a number means "work this issue"; `draft <topic>` means "write an issue".
A ticket is read by Brian scanning the board, by whoever plans what depends on it, and by
someone searching history in six months. Write for all three; the same holds for PRs.

## A. Work an issue

1. **Read before touching code.** `gh api repos/Arffornia/<repo>/issues/<n>` (body, labels,
   comments) and the repo's `AGENTS.md`, `PROGRESS.md`, any active plan in
   `docs/exec-plans/active/` and any ADR or spec the issue links.
2. **Check it is workable.** Proceed only with `agent-ready` and written acceptance criteria.
   `needs-decision`, or a design choice the issue does not settle: stop, write the question
   with options and a recommendation, and leave the choice to Brian.
3. **Branch** from the default branch, never commit on it:
   ```bash
   git fetch origin <default> && git switch -c <type>/<n>-<slug> origin/<default>
   ```
   `<type>` from the `type:` label: `fix`, `security`, `feat`, `deps`, `test`, `docs`, `ci`,
   `refactor`, `chore`. `<slug>`: 2-5 lowercase words. Example: `fix/12-http-timeouts`.
4. **Tests first, independently.** Delegate to the `arffornia:test-writer` agent with the
   issue URL: it writes tests from the acceptance criteria without seeing your code. Bring its
   tests onto the branch and confirm they fail for the right reason. When the agent is not
   available, write the test yourself before the fix and show it failing.
5. **Implement the smallest change** that meets every criterion. One concern per PR. Player
   text goes through i18n in `en` and `fr`. Never replace a Nexus_* library; improve it.
   Multi-session work gets an exec plan (`docs/exec-plans/active/`).
6. **Check.** `make check` green. If something cannot run offline, say so. Update `AGENTS.md`
   or docs when commands, layout or behaviour changed.
7. **Prove it.** Run the real thing for behaviour changes (`arffornia:verifier` agent:
   Playwright for the website, Playwright-Electron for the launcher, `runGameTestServer`
   for the mod) and keep the evidence. Then run `/arffornia:review` (in-session mode: fresh
   finder and verifier subagents, a stamp for the tree; the Stop hook asks for it anyway),
   fix every confirmed blocking or major finding and label each finding.
8. **Commit** with Conventional Commits, scope = component, and the session's trailers:
   `fix(proxy): add HTTP timeouts`.
9. **Harness lessons.** If something in the harness got in the way (a misleading skill step,
   a guard that blocked a legitimate action, a missing rule), record it with
   `/arffornia:harness-feedback` before you finish.
10. **Publish.** With every check green and the review clean, run `/arffornia:publish <n>`
   yourself: it re-checks secrets, `make check` and the review stamp, then opens the PR. Write
   the handoff (`PROGRESS.md`) if the work continues.

PR body (for publish): What / Why (`Closes #<n>`) / How it was tested (commands and real
output, verify evidence) / Risk & revert / Checklist. Labels: the issue's `type:` and `area:`.

## B. Draft an issue

Draft the text, show it, and create it only when the user says so. Format, labels, milestones
and the create command: [references/issue-format.md](references/issue-format.md).

Checklist before showing a ticket or PR:
- Title readable alone on a board, imperative, under ~80 chars.
- First paragraph answers "why does this exist".
- At least one check a non-author can perform.
- Limitations or follow-ups stated.
- Security: an exploitable weakness that is not fixed gets a neutral title ("Harden IPC
  input validation") and no reproduction steps. No secrets, tokens or internal hostnames.
- Fits on one screen.

## Report

End with the list in [references/reporting.md](references/reporting.md): every issue, branch,
commit and PR as a full URL with a one-line state, grouped Decide / Review / Act / FYI / Not done.
