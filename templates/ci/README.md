# CI templates

GitHub Actions and hooks a repo copies to get the agent-kit v2 sensors. Copy, adapt the marked
lines, open one PR. Every workflow uses `permissions: {}` or `contents: read` by default and
grants more per job.

| File | Copy to | What |
|---|---|---|
| `claude-review.yml` + `claude-review/` | `.github/workflows/claude-review.yml`, `.github/claude-review/` | Multi-agent AI review on every PR (below) |
| `claude-mention.yml` | `.github/workflows/claude-mention.yml` | `@claude` in issues/PRs; implements `agent-ready` issues on request; never merges |
| `gitleaks.yml` | `.github/workflows/gitleaks.yml` | Secret scan: PR range, pushes, weekly full history |
| `.pre-commit-config.yaml` | repo root | gitleaks + hygiene hooks + the stack's formatter (keep one block) |
| `adr-lint.yml` + `scripts/adr_lint.py` | `.github/workflows/`, `.github/scripts/` | ADR front-matter: status, date, supersedes/superseded_by both ways |
| `mutation-nightly-php.yml` | `.github/workflows/mutation-nightly.yml` | Infection on critical PHP modules, report only |
| `mutation-nightly-js.yml` | same | Stryker on critical JS/TS modules, report only |
| `mutation-nightly-gradle.yml` + `pitest.init.gradle` | same, `.github/pitest.init.gradle` | PIT on critical Java packages, report only, no build.gradle change |

Architecture guards (deptrac, dependency-cruiser, ArchUnit) are in `templates/guards/` and run
inside `make check`, so the repo's existing `ci.yml` already enforces them.

## Secrets (Claude workflows)

Set **one** of these as a repository or organization Actions secret:

| Secret | Get it | Billing | Use when |
|---|---|---|---|
| `ANTHROPIC_API_KEY` | [Claude Console](https://platform.claude.com) → API keys | API tokens | Org-wide secret shared by many repos |
| `CLAUDE_CODE_OAUTH_TOKEN` | `claude setup-token` on your machine | Your Claude Pro/Max/Team/Enterprise plan | One maintainer's repos |

Both workflows pass both inputs to `anthropics/claude-code-action@v1`; the empty one is ignored.
Do not set both. Also install the [Claude GitHub App](https://github.com/apps/claude) on the repo
(or run `/install-github-app` in Claude Code), because the action authenticates to GitHub through it
(`id-token: write`). Fork PRs get no secrets, so the review skips them.

## The AI review pipeline (`claude-review.yml`)

Modelled on how the Claude Code team reviews code at Anthropic ([Bringing Code Review to Claude
Code](https://claude.com/blog/code-review); summary of the internal write-up "How the Claude Code
team does code review": [alexop.dev](https://alexop.dev/tils/how-claude-code-team-does-code-review)):
several agents hunt in parallel, other agents verify each candidate to remove false positives, the
survivors are ranked by severity, depth scales with the change, the number of AI rounds is capped,
and past mistakes become evals.

```
pull_request ─▶ triage ─▶ find (matrix, one agent per lens) ─▶ verify (matrix, N independent voters) ─▶ publish (no model)
                 │           bugs · security · conventions        each votes confirmed/rejected/unsure     one review, ranked,
                 │           (+ bugs-crosscut · tests when deep)   with its own evidence                    inline where possible
                 └─ risk.yml (from the BASE branch) + size + labels → light | standard | deep, round n/3
```

| Level | When | Finders | Verifiers (quorum) |
|---|---|---|---|
| light | every changed file is a light path (docs, lang, tests only) | 1 `quick` pass | none; only evidenced blocking/major findings, max 5, marked unverified |
| standard | default | `bugs`, `security`, `conventions` | 2 (both must confirm) |
| deep | any deep path, or > `escalate.lines_changed` on standard, or label `ai-review:deep` | + `bugs-crosscut`, `tests` | 3 (2 must confirm) |

- **Depth comes from the change, not the author.** Labels can only raise it (`ai-review:deep`);
  `ai-review:skip` skips a PR (use for reverts and generated bumps). `risk.yml`, prompts and the
  pipeline script are read from the base branch, so a PR cannot lower its own review.
- **Evidence or nothing.** Finders must quote code or command output; verifiers re-check from the
  code and vote. A finding is posted only with the quorum. Severity = median of the confirmers'.
- **One review per round**, event `COMMENT` (never approve, never request changes: a human decides).
  First line: `Findings: N (blocking b, major m, minor k) · risk: level · round r/3`. Findings off the
  diff go in the body. A lens or verifier that did not finish is listed as "did not complete";
  silence is never reported as approval.
- **Max 3 rounds** per PR (`MAX_ROUNDS`): the 4th push gets one comment asking to rethink or split.
  A head sha is reviewed once; re-adding `ai-review:deep` forces one more pass.
- **Thread labels feed evals.** Each inline finding asks for a one-word reply: `fixed`, `wrong`,
  `intended`, `noise`. The `review-feedback` automation (`automations/review-feedback.md`) harvests
  them weekly; `wrong`/`noise` become eval cases in `evals/`, `fixed` counts as a useful comment.
- **Cost.** Model `claude-opus-5-5` for every agent: the maintainer prefers spending tokens to
  reading weak findings. A standard PR is 5 agent runs, deep is 8. Tune `AI_REVIEW_MODEL`,
  `MAX_TURNS`, `timeout-minutes`, or the lens lists in `review_pipeline.py`.
- **Trifecta.** Finders and verifiers read untrusted PR text but have read-only tools (no Edit,
  Write, web), no GitHub write token, and return JSON only. The only job that writes to GitHub
  (`publish`) runs no model. The repo's `.claude/settings.json` hooks are removed in the review jobs.

### `risk.yml` (repo root)

```yaml
default: standard            # level for files that match nothing
levels:                      # globs, gitignore-like (** spans dirs; a pattern without / matches at any depth)
  deep:                      # always deep: untrusted input, auth, money, release, infra
    - "src/main/java/**/network/**"
    - ".github/workflows/**"
  standard: ["src/**"]
  light:                     # carve-outs from standard: docs, lang, tests only
    - "**/*.md"
    - "docs/**"
escalate:
  lines_changed: 400         # more changed lines raises the level by one
```

Per file: deep wins, then light, then standard, then `default`. The PR takes its highest file
level. Aliases `high`/`medium`/`low` and top-level `deep:` keys are accepted.

### Adopt

```bash
KIT=../agent-kit/templates/ci
mkdir -p .github/workflows .github/claude-review
cp $KIT/claude-review.yml $KIT/claude-mention.yml .github/workflows/
cp -r $KIT/claude-review/. .github/claude-review/
python3 -m unittest .github/claude-review/test_review_pipeline.py   # 13 tests, stdlib only
```
Add `risk.yml` and `REVIEW.md`; add the secret and the GitHub App. The first PR (the one adding
the workflow) reviews itself with the head copy of the pipeline; later PRs use the base copy.

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
