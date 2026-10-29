---
paths:
  - "src/**/*.ts"
  - "tests/**/*.ts"
  - "test/**/*.ts"
  - "package.json"
  - "tsconfig*.json"
---

# TypeScript library conventions (Nexus_* libraries, config-updater)

- These are the owner's libraries: improve them, keep their public API stable, and bump the
  version with a changelog line. Never swap them for a third-party package.
- **Dependencies**: anything imported at runtime (e.g. `axios`, `tar`) is in `dependencies`, not
  `devDependencies`. Never depend on the npm placeholder packages `fs`/`path`.
- **Network**: every request has a timeout; retries are bounded with backoff; metadata lookups run
  with bounded concurrency. A failed lookup or download is reported and makes the caller exit
  non-zero; it never deletes the existing file.
- **Files**: download to a temp file, verify the hash, then `rename` (atomic). Reject paths that
  escape the base dir (`path.resolve(base, p)` must stay under `base`). Writes of settings files
  are write-temp-then-rename too.
- `tsconfig` has `"strict": true`; no `any` in exported types.
- **Tests**: unit tests with mocked HTTP (`nock` or an axios adapter) run on PRs; live-network
  tests are tagged and run nightly only. Test files end in `.test.ts` (others never run).
- Commit `package-lock.json`; CI uses `npm ci` on Node 22.
