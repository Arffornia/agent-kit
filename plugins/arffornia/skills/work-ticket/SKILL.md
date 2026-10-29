---
name: work-ticket
description: Take an Arffornia GitHub issue from ticket to pull request (branch `<type>/<n>-slug`, implement, `make check`, PR with the repo template, labels and `Closes #n`), or draft a new issue with the Arffornia label taxonomy. Use when asked to work on, pick up, fix or implement an issue, or to write, draft or backfill tickets for an Arffornia repo.
argument-hint: "[issue-number | 'draft' <topic>]"
---

# Work a ticket (Arffornia edition)

Based on Brian's `work-ticket` skill. A ticket is read by the maintainer scanning the board, by
whoever decides what depends on it, and by someone searching history in six months. Write for
all three. The same rules hold for PRs.

Argument: `$ARGUMENTS`. A number means "work this issue". `draft <topic>` means "write an issue".

## A. Work an issue

1. **Read before touching code.** `gh api repos/Arffornia/<repo>/issues/<n>` (title, body, labels,
   comments). Read the repo's `AGENTS.md` and any ADR the issue links.
2. **Check it is workable.** Proceed only if the issue has `agent-ready` and acceptance criteria.
   If it has `needs-decision`, or you hit a design choice the issue does not settle, stop and
   ask in the issue (or ask Brian). Do not pick an option yourself.
3. **Branch** from the default branch, never commit on it:
   ```bash
   git fetch origin main && git switch -c <type>/<n>-<slug> origin/main
   ```
   `<type>` comes from the issue's `type:` label: `fix` (bug), `security`, `feat` (feature),
   `deps`, `test`, `docs`, `ci`, `refactor`, `chore`. `<slug>`: 2-5 lowercase words with hyphens.
   Example: `fix/12-http-timeouts`.
4. **Implement the smallest change that meets every acceptance criterion.** One concern per PR.
   Add or update a test that fails without the change (unit test, or a GameTest with the
   `mc-gametest` skill). Player-facing text goes through i18n in `en` and `fr` (`i18n-sync`).
5. **Check.** `make check` must pass. If something cannot run offline, say so in the PR.
   Update `AGENTS.md` or docs when commands, layout or behaviour changed.
6. **Commit** with Conventional Commits, scope = the component: `fix(proxy): add HTTP timeouts`.
7. **Open the PR** with the `publish` skill if Brian invokes it, otherwise as described there:
   draft PR, body from `.github/pull_request_template.md` (What / Why / How it was tested /
   Risk & revert / Checklist), `Closes #<n>` under Why, the issue's `type:` and `area:` labels.
   Never merge, tag, release or push to `main`.

## B. Draft an issue

Draft first, create only after Brian approves the text.

```
Title: <Imperative verb> <specific outcome>          (under ~80 chars, no "As a ...")

**Context**
<1-3 sentences: the problem and what triggered it.>

**Evidence**
- `path/to/file.ext:42` <what it shows>

**Acceptance criteria**
- [ ] <observable outcome a non-author can check>

**Notes**
<risks, out of scope, links. Delete if empty.>
```

Labels, all from the existing taxonomy (`gh api repos/Arffornia/<repo>/labels`), never new ones:

| Axis | Pick exactly one |
|---|---|
| `type: ` | `bug`, `security`, `feature`, `deps`, `test`, `docs`, `ci`, `refactor` |
| `area: ` | `website`, `launcher`, `mod`, `proxy`, `provisioning`, `libs`, `infra`, `ai` |
| `priority: ` | `P0` now (security, data loss), `P1` next, `P2` planned, `P3` nice to have |
| `effort: ` | `S` under half a day, `M` 1-3 days, `L` more |
| readiness | `agent-ready` **only** when acceptance criteria are written and no design question is open; otherwise `needs-decision`. An idea is `proposal`. |

Labels are spelled with a space after the colon (`type: bug`). Milestones: `M1 · Foundation & security`,
`M2 · Tests & CI`, `M3 · Gameplay foundations`.

Create with the REST API (GraphQL may be unavailable):
```bash
gh api repos/Arffornia/<repo>/issues -f title='...' -f body="$(cat body.md)" \
  -f 'labels[]=type: bug' -f 'labels[]=area: proxy' -f 'labels[]=priority: P1' \
  -f 'labels[]=effort: S' -f 'labels[]=agent-ready'
```

## Checklist before showing a ticket or PR

- Title readable alone on a board, imperative.
- First paragraph answers "why does this exist".
- At least one check a non-author can perform.
- Limitations or follow-ups stated, or deliberately absent.
- **Security:** an exploitable weakness that is not fixed gets a neutral title ("Harden IPC input
  validation") and no reproduction steps. No secrets, tokens or internal hostnames anywhere.
- Fits on one screen.
