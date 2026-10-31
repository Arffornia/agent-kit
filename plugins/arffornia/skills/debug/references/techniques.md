# Reproduction and inspection per stack

## Mod (NeoForge 1.21.1, Java 21)
- Repro as a GameTest (`runGameTestServer --no-daemon -Dorg.gradle.jvmargs=-Xmx2g`): fastest
  deterministic loop; one Gradle build at a time.
- Logs: `run/logs/latest.log` (dev), `build/gametest-run.log`; raise a logger with
  `-Dlog4j2.level=DEBUG` or `LOGGER.debug` behind a flag.
- Threads: packet handlers run in `enqueueWork` (server thread); backend calls return futures
  completing elsewhere: check every `thenAccept`/`thenApplyAsync(..., server)` hop.
- Client-only crash on server: `net.minecraft.client` class loaded from common code.
- Unit tests: `./gradlew test --no-daemon` for pure logic (recipes, codecs).

## Launcher (Electron + Vue)
- Main process: `npm run dev`, logs in `launcher_log.txt` and the terminal; renderer: DevTools
  console. IPC: log the channel and argument types on both sides, never values of tokens.
- Repro in Vitest with `electron` mocked, or Playwright-Electron (`xvfb-run -a npm run test:e2e`).
- Async: missing `await` (a Promise is never null), unhandled rejections; run with
  `node --trace-warnings` style flags via `ELECTRON_ENABLE_LOGGING=1`.

## Website (Laravel 12, PHP 8.3)
- Repro as a Feature test: `php artisan test --filter <name>`; HTTP with
  `curl -i http://127.0.0.1:8000/...` against `php artisan serve`.
- `storage/logs/laravel.log`; `php artisan tinker` for one-off queries; `DB::listen` to dump
  SQL in a test. Never turn on `APP_DEBUG` outside local.
- Queues and schedule: `php artisan queue:work --once`, `schedule:test`.

## Proxy (Velocity, Java 17) and libraries (TypeScript Nexus_*)
- Proxy: unit test `ApiService` against a local `HttpServer` stub; `run-velocity` for manual.
- Nexus_* libs: reproduce in the library's own test suite first, then bump in the caller.

## Infra (Kubernetes, Argo CD)
- Read-only: `kubectl get/describe/logs`, `argocd app diff`; render with
  `kustomize build --enable-helm` and diff against what is live. Never apply by hand.

## General
- Bisect: `git bisect run` with an exit-code script; skip unbuildable commits with exit 125.
- Minimise input: halve the data, the mod list, the config until the failure disappears.
- Compare a good and a bad environment field by field (versions, env vars, feature flags).
- Time-related: freeze the clock in tests (`Carbon::setTestNow`, `vi.useFakeTimers`).
