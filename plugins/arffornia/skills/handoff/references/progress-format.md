# PROGRESS.md format

```markdown
# Progress

<!-- Newest first. Done entries shrink to one line; git keeps the history. -->

## 2026-10-29 14:20 UTC · fix/22-http-timeouts

**Now**
- Branch: https://github.com/Arffornia/Arffornia_Mods/tree/fix/22-http-timeouts - 3 commits ahead of main
- PR: https://github.com/Arffornia/Arffornia_Mods/pull/52 - draft; CI green (gametest, build)
- `make check` green at 14:15 UTC (`All 18 required tests passed :)`)

**Done this session**
- https://github.com/Arffornia/Arffornia_Mods/commit/<sha> - API client: connect/request timeouts
- https://github.com/Arffornia/Arffornia_Mods/commit/<sha> - tests against a stub server: 401 then one re-auth

**Next step**
- Apply the same timeouts to the proxy's `ApiService`; start with
  `./gradlew runGameTestServer --no-daemon -Dorg.gradle.jvmargs=-Xmx2g` to confirm green.

**Open questions**
- https://github.com/Arffornia/Arffornia_Mods/issues/17 - machine framework direction; Brian decides (spec 002 D1)

**Gotchas**
- FakePlayer.openMenu is a no-op: set `player.containerMenu` (added to AGENTS.md)

## Earlier
- 2026-10-28 · chore/foundation - merged as https://github.com/Arffornia/Arffornia_Mods/pull/41
```

Rules: under ~60 lines in total; one "Now" block (the current branch); links for every PR,
issue and commit (see reporting.md); times in UTC.

## Exec plan update

In `docs/exec-plans/active/<plan>.md`:
- `## Progress`: `- [x] (2026-10-29 14:15Z) Step 3: reject paths tested` - tick with a time;
  split a step that is half done into done and remaining parts.
- `## Surprises & discoveries`: what you learned, with evidence (a log line, a link).
- `## Decision log`: `- Decision: ... Rationale: ... Date/Author: ...` for every choice made
  without Brian that he may want to revisit (small, reversible ones only; others go to Open
  questions).
- `tasks.json`: set `status` (`todo` / `doing` / `done` / `blocked`) and `evidence` per task.
  JSON is harder to corrupt than a checklist on long runs; never delete tasks, mark them.
