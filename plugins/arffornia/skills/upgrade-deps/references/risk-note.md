# Risk note (PR body section)

```
**What**
Bump electron from 31.4.0 to 33.2.1.

**Why**
Security fixes (Chromium CVE-…), 31 is out of support. Changelog: https://github.com/electron/electron/releases/tag/v33.2.1

**What changed for us**
- `webContents.getPrinters` removed: not used (grep: 0 hits).
- Default `sandbox: true` for renderers: already set in `src/main/index.js:42`.

**How it was tested**
$ make check → ... passed
$ xvfb-run -a npx playwright test → 6 passed (48s)

**Not covered**
macOS notarisation and the Windows installer (no signing in CI).

**Risk & revert**
Risk: medium (runtime major). Revert this PR; players get the previous build at next update.
```
