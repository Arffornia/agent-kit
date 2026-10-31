# Deterministic guards

Rule: whatever a tool can check, a tool checks, in `make check` (so the Stop hook enforces it in
every agent session) and in CI. The in-session AI review looks only for what tools cannot see.
All tools here are free and open source (CodeQL is free on public repos, which Arffornia's are).
Generic pattern: agent-playbook `runbook/patterns/deterministic-guards.md`.

## What each stack must run

| Stack | Static analysis | Architecture | Security / supply chain | Dynamic |
|---|---|---|---|---|
| Every repo | `make check`; formatter check | — | gitleaks (pre-commit + CI), CodeQL (`security.yml`), Dependabot | — |
| GitHub Actions + shell | actionlint, zizmor, shellcheck (`templates/ci/workflow-lint.yml`) | — | zizmor (injection, permissions, unpinned actions) | — |
| PHP / Laravel (Website) | PHPStan + Larastan with a baseline; Pint `--test` | deptrac (`templates/guards/laravel`) | `composer audit`, Trivy image scan | Pest/PHPUnit, Playwright E2E, Infection nightly on critical modules |
| Electron + Vue (Launcher) | ESLint 9 flat config; `vue-tsc`/`tsc --noEmit` where typed | dependency-cruiser + preload exposure check (`templates/guards/electron`) | `npm audit --omit=dev` | Playwright-for-Electron, Stryker nightly |
| TypeScript libraries (Nexus_*) | ESLint, `tsc --noEmit` (strict) | dependency-cruiser optional | `npm audit`, trusted publishing (no token) | unit tests, fast-check properties on paths and parsers |
| NeoForge mod, Velocity proxy (Java) | SpotBugs (or Error Prone) with an exclude file for today's findings | ArchUnit with a frozen store (`templates/guards/neoforge`) | Dependabot (Gradle) | GameTests, PIT nightly, jqwik on packet handlers |
| Kubernetes / Helm (infra, charts) | `helm lint`, kubeconform `-strict` on rendered manifests | — | Trivy config scan, kube-linter | — |

`plugins/arffornia/scripts/guards-check.sh <repo> [--strict]` reads a repo (no network) and
prints which expected guards are wired and which are missing, with the fix. The harness audit
runs it monthly on every repo; `--strict` can gate CI once a repo is complete.

Adopting a tool in an existing repo: add it with a baseline (today's findings frozen), fail only
on new findings, shrink the baseline over time. Make the failure message say what to do.

## Gap list (2026-10-31)

Measured with `guards-check.sh` on each repo's default branch. Most "missing" rows on `main`
are already in the open foundation PRs of chantiers C2-C7 (Makefile `check`, gitleaks, CI); the
list below is what stays missing after those merge.

| Gap | Repos | Fix | Where |
|---|---|---|---|
| actionlint + zizmor + shellcheck on workflows and scripts | all product repos | copy `templates/ci/workflow-lint.yml` | one PR per repo, next foundation pass |
| deptrac / dependency-cruiser / ArchUnit | Website, Mods; Launcher in its pilot PR | templates in `templates/guards/` | pilots: Launcher #68, Mods #51; Website after C4 |
| SpotBugs (Java static analysis) | Arffornia_Mods, Arffornia_Proxy | Gradle plugin + exclude file | new issue per repo |
| `composer audit` in CI | Arffornia_Website | one CI step | with the deptrac PR |
| ESLint on Nexus_Mods (check after its foundation PR #20 merges) | Nexus_Mods | flat config like the other Nexus libs | new issue if still missing |
| kubeconform on the website chart | Arffornia_Website (`chart/`), minecraft-server-charts | rendered-manifest validation as in infra #42 | new issue per repo |
| Property tests / fuzzing | Nexus_Mods paths, Mods packet handlers | fast-check, jqwik | tech-watch card 01 proposal 5 |
| Mutation on changed lines in the verify step | Website, Launcher, Mods | `make mutate-diff` | tech-watch card 01 proposal 1 |
