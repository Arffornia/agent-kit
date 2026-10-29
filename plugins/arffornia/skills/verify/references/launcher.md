# Launcher (Electron + Vue) with Playwright-Electron

From the launcher's e2e branch: `playwright.config.cjs` (`testDir: test/e2e`, one worker),
`test/e2e/fixtures.cjs` mocks every remote endpoint the renderer calls (no real network),
`test/e2e/smoke.spec.cjs` launches the built app in a throwaway CWD (game data is
CWD-relative).

```bash
npm ci
npm run build                                  # bundles out/ (main, preload, renderer)
xvfb-run -a npx playwright test                # headless Linux; `npm run test:e2e` builds then runs
xvfb-run -a npx playwright test -g "boots" --trace on
```

Launching (copy the smoke spec's `launchApp`): `electron.launch({ args: ['--no-sandbox', APP_DIR],
cwd: workDir, env: { ...process.env, NODE_ENV: 'production', ELECTRON_ENABLE_LOGGING: '1' } })`,
then `mockRemoteEndpoints(window)` and `window.reload()` so first fetches hit the mocks.
WebGL errors from the 3D skin viewer are expected headless.

Typical checks:
- Renderer isolation: `window.evaluate(() => typeof require)` is `'undefined'`.
- IPC hardening: calling `window.api.<channel>` with a hostile argument (a `../` path, a
  `file://` URL) is refused; check the main-process log line, not only the return value.
- Logs: after a launch attempt, read `launcher_log.txt` in `workDir` and assert it has no
  `--accessToken`, `--uuid` value or refresh token.
- i18n: switch the language setting and assert a French label.
- Main-process behaviour with no UI: Vitest with `electron` mocked.

Never run the real Microsoft login or download the full modpack in verify: mock them.
Evidence: passed test names, `test-results/` traces or screenshots, log excerpts.
