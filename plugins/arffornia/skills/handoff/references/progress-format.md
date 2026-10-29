# PROGRESS.md format

Follow the repo's `PROGRESS.md` (agent-kit `templates/PROGRESS.md`): a short **Now** block that
the SessionStart hook shows to every new session, and a **Log** where the PreCompact and
SessionEnd hooks append automatic entries. A handoff rewrites **Now** and replaces the
automatic Log entries of this session with one real summary line.

```markdown
# Progress

<intro lines from the template, unchanged>

## Now

- Goal: HTTP timeouts and one re-auth on 401 in the API client - https://github.com/Arffornia/Arffornia_Mods/issues/22
- Done: client timeouts + 401 re-auth on https://github.com/Arffornia/Arffornia_Mods/tree/fix/22-http-timeouts
  (3 commits; `make check` green at 14:15 UTC, `ApiClientTest` 6 passed); PR https://github.com/Arffornia/Arffornia_Mods/pull/52 draft, CI green
- Next step: apply the same timeouts to the proxy's `ApiService`; start with
  `./gradlew test --no-daemon -Dorg.gradle.jvmargs=-Xmx2g` in Arffornia_Proxy to confirm green
- Blockers / decisions needed: none
- Verify with: `make check` and `./gradlew runGameTestServer --no-daemon -Dorg.gradle.jvmargs=-Xmx2g`
- Plan: docs/exec-plans/active/2026-10-29-api-client-hardening.md (if any)

## Log

- 2026-10-29 14:20 UTC · fix/22-http-timeouts - timeouts + re-auth done, PR #52 opened (https://github.com/Arffornia/Arffornia_Mods/pull/52)
- 2026-10-28 · chore/foundation - merged as https://github.com/Arffornia/Arffornia_Mods/pull/41
```

Rules: "Now" stays under ~10 lines and is about the current branch only; Log entries are one
line each, newest first; every PR, issue and commit is a full link (see reporting.md); times
in UTC; facts only (what ran and its result). Gotchas that will bite again go to `AGENTS.md`
or a `.claude/rules/` file, not here.

Without a template in the repo, create `PROGRESS.md` with exactly these two sections.

## Exec plan update

In `docs/exec-plans/active/<plan>.md` (sections of agent-kit's `TEMPLATE.md`):
- `## Progress`: `- [x] (2026-10-29 14:15Z) Step 3: reject paths tested`; split a half-done
  step into its done and remaining parts.
- `## Verification evidence`: the latest `make check` tail and test names.
- `## Decision log`: a table row per choice made (reversible ones only; others are pending
  rows for Brian with a `needs-decision` issue).
- `## Surprises and follow-ups`: what you learned, with evidence, and follow-up issue links.
- `tasks.json`: set `status` and `evidence` per task; never delete tasks.
