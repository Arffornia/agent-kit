# PR body

Use the repo's `.github/pull_request_template.md` when it exists; these are the sections it has.

- **What** - the change as behaviour, 1-5 bullets. Not the file list.
- **Why** - the problem in one or two sentences, then `Closes #<n>` (full issue URL in the
  final report, the keyword form here so GitHub links it).
- **How it was tested** - the commands you ran and their real output, trimmed:
  ```
  $ make check
  ... 128 tests, 0 failures
  BUILD SUCCESSFUL
  ```
  Plus the verify evidence: GameTest summary line (`All N required tests passed :)`), the
  Playwright test names that passed, screenshot paths or artifact URLs, and the
  "broke it, test failed, restored" check for new tests. Say what could not run offline.
- **Risk & revert** - what could break, who would notice (players, admins, CI), how to undo
  (revert the PR; for Provisioning content: players get the revert at next launcher start).
- **Checklist** - tick only what is true.
- **Review** - one line: `Reviewed by arffornia:reviewer: Findings 0 (…)` or the open
  questions.

Footer: exactly the lines the session or repo requires (STANDARDS.md), nothing else.

Title: Conventional Commit form, scope = component: `fix(launcher): redact tokens from launch logs`.
Security fixes for unfixed public weaknesses: neutral title and body ("Harden IPC input
validation"), no exploit steps.
