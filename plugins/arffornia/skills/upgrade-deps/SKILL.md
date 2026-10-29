---
name: upgrade-deps
description: "Upgrade dependencies in an Arffornia repo one PR per dependency: read the changelog between versions, upgrade, run tests and the real app, write a risk note, open a draft PR. Human-invoked only (it pushes and opens PRs): Brian runs /arffornia:upgrade-deps when dependencies are outdated or a security advisory lands."
disable-model-invocation: true
argument-hint: "[package[@version] | --outdated]"
---

# Upgrade dependencies, one PR each

Target: `$ARGUMENTS`. `--outdated` lists candidates and stops so Brian picks; a package name
upgrades that one. Never batch unrelated libraries: one dependency (or one tightly coupled
group such as `@vue/*` or `laravel/framework` + its first-party packages) per branch and PR,
so a revert is one click. The modpack's mods are not dependencies: changing them is a
content change in Arffornia_Provisioning with its own rules (modList, sides, indexes).

## 1. List what is outdated

Commands per ecosystem, and which ones need care (Nexus_* are the owner's libraries:
upgrade, never replace): [references/ecosystems.md](references/ecosystems.md).
Skip a dependency that has an open Dependabot or human PR; review that one instead.

## 2. For each dependency

1. Branch from the default branch: `deps/<name>-<version>` (e.g. `deps/electron-33`).
2. **Read the changelog** between the current and target version (GitHub releases,
   `CHANGELOG.md`, the migration guide). Write down breaking changes, deprecations that hit
   our code (grep for each changed API), security fixes (with advisory ids), and new
   minimum runtime versions (Node, PHP, Java).
3. Upgrade with the package manager (never hand-edit lock files) and apply the code changes
   the changelog requires. Patch and minor first; a major gets its own PR even when the
   same library also has a minor pending.
4. **Prove it**: `make check`, then run the real thing for anything runtime-facing (Playwright
   for the website, Playwright-Electron for the launcher, `runGameTestServer` for the mod).
   Gradle: `--no-daemon -Dorg.gradle.jvmargs=-Xmx2g`, one build at a time.
5. Commit `deps(<scope>): bump <name> from <a> to <b>` with the session trailers.
6. **Risk note** in the PR body (template: [references/risk-note.md](references/risk-note.md)):
   changelog link, what changed for us, what was tested and how, what is not covered, risk
   low/medium/high, rollback.
7. Push and open a **draft** PR (Claude Code asks before the push):
   ```bash
   git push -u origin HEAD
   gh api repos/Arffornia/<repo>/pulls -f title='deps(<scope>): bump <name> from <a> to <b>' \
     -f head=<branch> -f base=<default> -f body="$(cat pr.md)" -F draft=true --jq .html_url
   gh api repos/Arffornia/<repo>/issues/<pr>/labels -f 'labels[]=type: deps' -f 'labels[]=area: <area>'
   ```

Stop and report instead of upgrading when the changelog shows a breaking change that needs
a design choice (a new auth flow, a dropped platform), when tests fail for reasons outside
the upgrade, or when the new version needs a runtime the deploy does not have.

## 3. Report

One line per dependency per [references/reporting.md](references/reporting.md): PR URL, from →
to, risk, CI state; then the skipped ones with the reason.
