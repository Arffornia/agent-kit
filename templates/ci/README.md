# CI templates

GitHub Actions and hooks a repo copies to get the agent-kit v2 sensors. Copy, adapt the marked
lines, open one PR. Every workflow uses `permissions: {}` or `contents: read` by default and
grants more per job. **Everything here is deterministic: no model runs in CI, and no Anthropic
API key or OAuth token is ever stored in GitHub.** The AI review happens at the end of the task,
inside the agent's own session (`/arffornia:review`, gated by the plugin's Stop hook; see
agent-kit `docs/HARNESS.md`). Scheduled agents run as Claude Code scheduled tasks on the
maintainer's account (`automations/README.md`).

| File | Copy to | What |
|---|---|---|
| `gitleaks.yml` | `.github/workflows/gitleaks.yml` | Secret scan: PR range, pushes, weekly full history |
| `.pre-commit-config.yaml` | repo root | gitleaks + hygiene hooks + the stack's formatter (keep one block) |
| `adr-lint.yml` + `scripts/adr_lint.py` | `.github/workflows/`, `.github/scripts/` | ADR front-matter: status, date, supersedes/superseded_by both ways |
| `mutation-nightly-php.yml` | `.github/workflows/mutation-nightly.yml` | Infection on critical PHP modules, report only |
| `mutation-nightly-js.yml` | same | Stryker on critical JS/TS modules, report only |
| `mutation-nightly-gradle.yml` + `pitest.init.gradle` | same, `.github/pitest.init.gradle` | PIT on critical Java packages, report only, no build.gradle change |

Architecture guards (deptrac, dependency-cruiser, ArchUnit) are in `templates/guards/` and run
inside `make check`, so the repo's existing `ci.yml` already enforces them.

## Why there is no AI review workflow

An earlier draft of v2 shipped `claude-review.yml` (multi-agent review on every PR) and
`claude-mention.yml` (`@claude` in issues). Both needed an `ANTHROPIC_API_KEY` or
`CLAUDE_CODE_OAUTH_TOKEN` secret and posted on every PR. The maintainer chose instead: the agent
that did the work reviews its own diff with independent subagents before it hands back or
publishes, and the PR body carries the result (a findings list plus an
`<!-- arffornia-review v1 … -->` marker that the weekly `review-feedback` automation turns into
eval cases). The same design ideas moved there: risk routing by `risk.yml` read from the base
branch, parallel finders, independent verifiers with a quorum at high risk, confirmed findings
only, severity ranking, a 3-round cap, and `fixed / wrong / intended / noise` labels.

## `risk.yml` (repo root)

The canonical schema is the one in [`templates/risk.yml`](../risk.yml) (core harness): an ordered
list of rules, **first match wins** (top to bottom), files that match nothing get `default`.

```yaml
version: 1
default: standard
escalate:
  lines_changed: 400          # optional: more changed lines raises the PR one level (default 400)
rules:
  - name: network-boundary
    depth: deep               # light | standard | deep
    security: true            # forces deep and adds the `threat-model` finder lens
    paths: ["**/network/**", "src/preload/**"]
  - name: tests
    depth: standard
    paths: ["src/test/**"]
  - name: docs
    depth: light
    paths: ["**/*.md", "docs/**"]
```

- Globs are gitignore-like: `**` spans directories, `{a,b}` alternates, a pattern without `/`
  (e.g. `*Auth*`) matches at any depth.
- Put narrow, risky rules first: a file stops at its first matching rule.
- The change's level is the highest level among its files, then `security` and `escalate` apply.
  The in-session review reads `risk.yml` from the base branch, so a change cannot lower its own review.
- Check a rules file: `python3 <agent-kit>/plugins/arffornia/skills/review/scripts/risk.py --base origin/main`
  prints the level per changed file, the overall level and the review plan.

## gitleaks and pre-commit

`gitleaks.yml` downloads a pinned gitleaks release and verifies its checksum (the official
gitleaks-action needs a paid license for organization repos). Allow a false positive with a
`.gitleaksignore` line (the finding's Fingerprint) or `# gitleaks:allow` on the line, and say why
in the PR. A real finding: rotate first (repos are public), then remove.

`pre-commit install` once per clone. Formatter hooks are `repo: local` and call the repo's own
tools, so versions match the lockfile and `make fmt`.

## Mutation testing (nightly, report only)

Scope it to the critical modules (`MUTATE_PATHS`, `MUTATE`, `PIT_TARGET_CLASSES`): money, auth,
payload handlers, downloaders. The score goes to the job summary and an artifact; the
`quality-score` automation reads it. It never fails the run on a low score. A surviving mutant on a
critical path is a missing test: write the test that kills it.
