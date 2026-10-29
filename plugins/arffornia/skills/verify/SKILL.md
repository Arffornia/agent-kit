---
name: verify
description: "Prove a change works by running the real thing and attaching evidence: the website with Playwright, the launcher with Playwright-Electron under xvfb, the mod with runGameTestServer, libraries and proxy with their tests. Use after implementing a behaviour change, before publishing, when asked to verify, test end to end, smoke test or check that something really works, or when the arffornia:verifier agent runs."
argument-hint: "[what to verify: issue number, acceptance criteria or a behaviour]"
---

# Verify: run it, prove it

`$ARGUMENTS` is the behaviour to prove. Passing unit tests is not proof that a player sees the
right thing. Verification drives the built artifact the way a user would and leaves evidence
a reviewer can open. Do not grade your own implementation from memory: run it.

## 1. Turn the claim into checks

Write the acceptance criteria as a numbered list of observable checks ("an anonymous visitor
sees the podium on /", "selecting a locked recipe is rejected and logged", "the launcher log
contains no `--accessToken`"). Each check gets: how to drive it, what to observe, pass rule.
Include at least one negative check (what must **not** happen).

## 2. Pick the harness

| Repo | Harness | Recipe |
|---|---|---|
| Arffornia_Website | Playwright in `e2e/` against `php artisan serve` with the E2E seeder | [references/website.md](references/website.md) |
| Arffornia_Launcher_V.5.2 | Playwright `_electron` on the built `out/`, endpoints mocked, `xvfb-run` | [references/launcher.md](references/launcher.md) |
| Arffornia_Mods | `runGameTestServer` (server logic); screens: the UI checks of spec 004/006 | [references/mod.md](references/mod.md) |
| Proxy, Nexus_*, Provisioning | the repo's tests plus one real run (stub HTTP server, `make indexes`) | [references/other.md](references/other.md) |

When the repo has no harness yet, use the closest real run (start the app, curl it, read the
log) and say in the result that an e2e test is missing, with the issue that tracks it.

## 3. Run and collect evidence

- Run from a clean build of the branch (`make build` or the repo's command), not a stale one.
- Keep: the command, the test names that passed, the summary lines, screenshots or traces
  (Playwright `--trace on`, `screenshot()`), relevant log excerpts (never with secrets).
- Put artifacts under `build/verify/<date>-<slug>/` (git-ignored) or attach the CI run URL.
- A check that cannot run here (no display, no network, missing secret): mark it
  `NOT RUN` with the reason. Never mark it passed.

## 4. Result

Shape: [references/evidence.md](references/evidence.md). First line:
`Verify: <passed>/<total> checks passed · <not run> not run · <harness>`. Then one line per
check (`PASS` / `FAIL` / `NOT RUN`, evidence link or path). A FAIL goes back to the
implementer with the reproduction command; the verifier does not fix code.

Links and ordering follow [references/reporting.md](references/reporting.md).
