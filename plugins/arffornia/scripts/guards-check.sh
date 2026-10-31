#!/usr/bin/env bash
# Which deterministic guards does this repo run, and which are missing for its stacks?
#   bash guards-check.sh [repo-dir] [--strict]
# Reads files only (no network, no build). Detects the stacks (PHP/Laravel, JS/TS, Java/Gradle,
# Go, shell, GitHub Actions, Kubernetes/Helm) and looks for each expected guard in the repo's
# config, Makefile and workflows. Prints one line per guard: ok / MISSING (with the fix).
# Exit 0 always, or 1 with --strict when something is missing (for CI and the harness audit).
# The list and the reasons: agent-kit docs/GUARDS.md. Portable: macOS bash 3.2 + BSD tools.
set -uo pipefail
dir="${1:-.}"; strict=0
for a in "$@"; do [ "$a" = --strict ] && strict=1; done
[ "${1:-}" = --strict ] && dir=.
cd "$dir" 2>/dev/null || { echo "guards-check: no such dir $dir" >&2; exit 2; }
missing=0
# All the text a guard can be wired from: Makefile, package.json scripts, workflows, pre-commit.
wired="$(cat Makefile package.json .pre-commit-config.yaml .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null)"
has() { printf '%s' "$wired" | grep -Eqi "$1"; }
file() { for f in "$@"; do [ -e "$f" ] && return 0; done; return 1; }
row() { # <stack> <guard> <found 0|1> <fix>
  if [ "$3" = 1 ]; then printf 'ok       %-10s %s\n' "$1" "$2"
  else printf 'MISSING  %-10s %s -> %s\n' "$1" "$2" "$4"; missing=$((missing+1)); fi
}
yes() { if "$@"; then echo 1; else echo 0; fi; }

# Every repo
row all "make check" "$(yes grep -Eq '^check:' Makefile 2>/dev/null)" "add a 'check' target running lint + tests + guards (agent-kit templates)"
row all "gitleaks (secrets)" "$(yes has 'gitleaks')" "copy templates/ci/gitleaks.yml and the pre-commit hook"
if ls .github/workflows/*.y*ml >/dev/null 2>&1; then
  row actions "actionlint" "$(yes has 'actionlint')" "copy templates/ci/workflow-lint.yml"
  row actions "zizmor (workflow security)" "$(yes has 'zizmor')" "copy templates/ci/workflow-lint.yml"
  row all "CodeQL or Semgrep (security patterns)" "$(yes has 'codeql|semgrep')" "CodeQL is free on public repos (security.yml); Semgrep CE otherwise"
fi
if [ -n "$(git ls-files '*.sh' 2>/dev/null | head -n 1)" ]; then
  row shell "shellcheck" "$(yes has 'shellcheck')" "add 'shellcheck' on git ls-files '*.sh' to make check / workflow-lint.yml"
fi
# PHP / Laravel
if file composer.json; then
  row php "PHPStan/Larastan" "$(yes file phpstan.neon phpstan.neon.dist phpstan.dist.neon)" "composer require --dev larastan/larastan; phpstan.neon with a baseline; wire into make check"
  row php "deptrac (architecture)" "$(yes file deptrac.yaml deptrac.yml)" "templates/guards/laravel"
  row php "Pint or PHP-CS-Fixer (format)" "$(yes has 'pint|php-cs-fixer')" "vendor/bin/pint --test in make check"
  row php "composer audit" "$(yes has 'composer audit')" "add composer audit to CI"
fi
# JS / TS
if file package.json; then
  row js "ESLint" "$(yes file eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts .eslintrc .eslintrc.js .eslintrc.json .eslintrc.cjs)" "ESLint 9 flat config; npm run lint in make check"
  if file tsconfig.json; then row ts "tsc --noEmit" "$(yes has 'tsc( |\")|vue-tsc|--noEmit')" "add tsc --noEmit (or vue-tsc) to make check"; fi
  row js "dependency-cruiser (architecture)" "$(yes file .dependency-cruiser.cjs .dependency-cruiser.js .dependency-cruiser.json)" "templates/guards/electron (apps; optional for small libraries)"
  row js "npm audit / OSV" "$(yes has 'npm audit|osv-scanner|trivy')" "npm audit --omit=dev in CI, or Trivy fs"
fi
# Java / Gradle
if file build.gradle build.gradle.kts; then
  row java "ArchUnit (architecture)" "$(yes grep -Rqs 'archunit' build.gradle build.gradle.kts)" "templates/guards/neoforge"
  row java "Error Prone or SpotBugs" "$(yes grep -Eqs 'errorprone|spotbugs' build.gradle build.gradle.kts)" "add the SpotBugs Gradle plugin with an exclude file for today's findings"
fi
# Go
if file go.mod; then
  row go "go vet + staticcheck" "$(yes has 'staticcheck|golangci')" "golangci-lint run in make check"
  row go "govulncheck" "$(yes has 'govulncheck')" "govulncheck ./... in CI"
fi
# Kubernetes / Helm
if [ -n "$(git ls-files '*Chart.yaml' 'charts/*' 2>/dev/null | head -n 1)" ] || grep -RqsE '^kind: (Deployment|StatefulSet)' --include='*.yaml' . 2>/dev/null; then
  row k8s "kubeconform / helm lint" "$(yes has 'kubeconform|helm lint|kube-linter')" "validate rendered manifests in CI (kubeconform -strict)"
fi
printf '%d missing\n' "$missing"
[ "$strict" = 1 ] && [ "$missing" -gt 0 ] && exit 1
exit 0
