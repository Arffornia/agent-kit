# AGENTS.md — agent-kit

## Purpose
The AI harness for every Arffornia repo: the Claude Code plugin `arffornia` (skills, subagents,
hooks), the templates repos copy, a cloud setup script and a Codex skills sync. Design:
`docs/HARNESS.md`. Catalog: `SKILLS.md`. Install and adoption: `README.md`.

## Map
| Path | What |
|---|---|
| `.claude/settings.json` | This repo's own settings: the v2 template's deny rules and sandbox (no plugin enablement: develop with `claude --plugin-dir plugins/arffornia`), so kit work and the weekly harness-feedback run are sandboxed |
| `.claude-plugin/marketplace.json` | Marketplace `agent-kit`; one entry `arffornia` → `./plugins/arffornia` |
| `plugins/arffornia/.claude-plugin/plugin.json` | Plugin manifest (no `version`: users track commits) |
| `plugins/arffornia/hooks/hooks.json` | Hook wiring (exec form, `${CLAUDE_PLUGIN_ROOT}`), loaded automatically |
| `plugins/arffornia/scripts/*.sh` | Hook scripts; `lib.sh` is shared; `review-stamp.sh` holds the in-session review state; `tests/run.sh` is the suite, `tests/portability.sh` the bash 3.2 / BSD lint |
| `plugins/arffornia/skills/<name>/SKILL.md` | One folder per skill, namespaced `/arffornia:<name>` |
| `plugins/arffornia/agents/*.md` | Subagents (`arffornia:reviewer`, …) |
| `templates/` | AGENTS.md map, REVIEW.md, `.claude/settings.json` + `rules/`, PROGRESS.md, exec plans, GOLDEN_PRINCIPLES, QUALITY_SCORE, risk.yml, `scripts/init`, `ci/`, `guards/` |
| `cloud/setup.sh` | Cloud environment setup script |
| `codex/sync-skills.sh` | Skills → `.agents/skills` in a repo |
| `automations/`, `evals/` | Scheduled agents with trifecta cards; harness eval cases |
| `docs/HARNESS.md`, `docs/MODELS.md`, `docs/SETUP.md` | Design, model per role (with evidence), machine setup |
| `flake.nix`, `Brewfile`, `.github/workflows/ci.yml` | Toolchains (nix, Homebrew); the kit's own CI (Linux + macOS bash 3.2) |

## Check before handing back
```bash
claude plugin validate . && claude plugin validate plugins/arffornia
bash plugins/arffornia/scripts/tests/run.sh          # hook suite, offline, ~5 s
bash plugins/arffornia/scripts/tests/portability.sh  # bash 3.2 / BSD traps in every shell script
shellcheck -S warning plugins/arffornia/scripts/*.sh cloud/setup.sh codex/sync-skills.sh templates/scripts/init
jq . plugins/arffornia/hooks/hooks.json templates/.claude/settings.json >/dev/null
```

## Rules
- English. Conventional Commits (`feat(hooks): …`, `fix(templates): …`), one concern per PR,
  never merge: the maintainer merges. Commit trailers and PR footer as in the session standards.
- Read the current Claude Code docs before changing a hook, setting or plugin file
  (https://code.claude.com/docs/en/hooks, /plugins-reference, /settings, /memory); use the
  exact documented formats and validate.
- Hook scripts: portable bash (macOS bash 3.2 + Linux), `set -euo pipefail`, guard every
  `grep` in a pipeline with `|| true`, quiet no-op when a tool is missing or outside a git repo,
  state only under `.git/claude-harness/` (the review snapshots also write ordinary loose git
  objects, which `git gc` prunes). Block messages say why and what to do instead.
  Keep SessionStart, PreToolUse and SessionEnd under ~2 s. Add a case to `tests/run.sh` for
  every behaviour change.
- Skills: concrete commands, under ~150 lines, long material in sibling files. Anything that
  pushes, publishes, deletes or releases sets `disable-model-invocation: true`. One owner-approved
  exception: `harness-feedback` opens or comments `harness-feedback` issues in this repo, marked
  `<!-- side-effect-approved: … -->` so the lint accepts it; any new exception needs Brian's OK. Nothing tells
  an agent to merge, tag, release, push to `main` or touch secrets.
- Keep the marketplace entry `name` and `plugin.json` `name` identical (`arffornia`).
- A template change is a change in every repo that adopts it next: say so in the PR.
- No AI review in CI and no API key or OAuth token anywhere: review runs in the session
  (`/arffornia:review`), automations run as Claude Code scheduled tasks or `claude -p`.
- When something in the harness gets in your way or could be better, record it with
  `/arffornia:harness-feedback` (search first, then append or open, with a patch).
- **Reporting**: every PR, issue, commit or page you mention to a human is a full clickable URL
  with a one-line summary, grouped by what the human should do. Never "I opened the PR" without
  the link.

## Gotchas
- Plugin hook `timeout`s do not raise the SessionEnd budget (1.5 s): `handoff.sh` must stay fast.
- A `SessionStart` hook's plain stdout is context, but on `PostToolUse`/`Stop` only JSON
  `additionalContext`/`reason` or exit 2 + stderr reach Claude (`lib.sh emit_context` handles it).
- `gh pr list`/`gh issue list` use GraphQL; the scripts use `gh api` REST so they also work
  where GraphQL is unavailable.
- Hooks run outside the Bash sandbox, with the user's full access: never run repo-provided code
  from a hook beyond the repo's Makefile targets and its installed dev tools (`node_modules/.bin`, `vendor/bin`).
