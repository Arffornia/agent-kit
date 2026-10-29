# agent-kit

The AI harness for the Arffornia repositories. One Claude Code plugin (`arffornia`) ships the
skills, subagents and hooks; `templates/` holds the files each repo copies; `cloud/` and
`codex/` make the same setup work in cloud sessions and for other agents.

The goal: an agent starts every session already knowing the repo state, what to do next and
how to verify it; it cannot break the rules that matter; and it proves its work before a human
sees it: a non-trivial change is reviewed by independent subagents **inside the agent's
session** at the end of the task (no AI review in CI, no API key or OAuth token in GitHub).

| Read | For |
|---|---|
| [SKILLS.md](SKILLS.md) | The skill and subagent catalog (the only list; this README does not repeat it) |
| [docs/HARNESS.md](docs/HARNESS.md) | The design, the end-of-task review, the improvement loop, the sandbox in plain words, sources |
| [docs/MODELS.md](docs/MODELS.md) | Which model each role uses, with the evidence and the cost per review |
| [docs/SETUP.md](docs/SETUP.md) | macOS (Homebrew, nix-darwin), Linux and NixOS setup; `nix develop` shells |
| [automations/README.md](automations/README.md) | Scheduled agents, run as Claude Code scheduled tasks on your account |

```
.claude-plugin/marketplace.json   marketplace "agent-kit" → plugins/arffornia
plugins/arffornia/
  .claude-plugin/plugin.json      plugin "arffornia"
  skills/  agents/                workflows and independent reviewers (see SKILLS.md)
  hooks/hooks.json                SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Stop, PreCompact, SessionEnd
  scripts/                        the hook scripts (portable bash), review-stamp.sh, tests/run.sh + tests/portability.sh
templates/                        what a repo copies to adopt the harness
cloud/setup.sh                    cloud environment setup script (warm toolchains and caches)
codex/sync-skills.sh              expose the skills to Codex via .agents/skills
docs/                             HARNESS.md (design), MODELS.md (model per role), SETUP.md (machines)
flake.nix, Brewfile               dev toolchains for nix (Linux, macOS) and Homebrew
.github/workflows/ci.yml          the kit's own CI: hook suite on Linux x86_64/arm64 and macOS arm64 (bash 3.2)
```

## Install (for you)

In Claude Code:

```
/plugin marketplace add Arffornia/agent-kit
/plugin install arffornia@agent-kit
```

Updates: `/plugin marketplace update agent-kit`, or enable auto-update for the marketplace in
`/plugin` → Marketplaces. The plugin has no `version`, so you track commits on `main`.

## Adopt in a repo (3 commands)

From the repo root, with agent-kit cloned next to it (`../agent-kit`):

```bash
(cd ../agent-kit/templates && cp -Rn .claude docs scripts CLAUDE.md PROGRESS.md GOLDEN_PRINCIPLES.md QUALITY_SCORE.md risk.yml "$OLDPWD")
cp -n ../agent-kit/templates/AGENTS.md.template AGENTS.md; cp -n ../agent-kit/templates/REVIEW.md.template REVIEW.md
scripts/init                       # fresh clone → deps → .env from example → green make check
```

`cp -n` never overwrites a file the repo already has. Then:

- delete the `.claude/rules/*.md` files for stacks the repo does not use (`java-neoforge.md`
  and `java-velocity.md` share `src/main/java/**`: keep one);
- fill the placeholders (`<...>`) in `AGENTS.md` (keep it ≤100 lines), `REVIEW.md`,
  `QUALITY_SCORE.md` and `risk.yml`, and the "repo-specific" block of `scripts/init`;
- **coming from v1**: the old `.claude/settings.json` was kept by `cp -n`. Replace it with the
  v2 file, or at least delete its `hooks` key: the plugin now ships those hooks, and keeping
  both runs `make fmt` and `make check` twice;
- CI workflows and architecture guards come from `templates/ci/` and `templates/guards/`
  (see their own README);
- open one PR: `chore: AI harness v2 (agent-kit templates)`. Everyone who trusts the folder
  gets the plugin through `.claude/settings.json` (`extraKnownMarketplaces` + `enabledPlugins`).

The repo needs a Makefile with `check` (and ideally `test`, `lint`, `fmt`, `build`). Make
`fmt` and `lint` accept `FILE=<path>` so the post-edit hook can work on one file:

```make
fmt:  ; $(if $(FILE),pint $(FILE),pint)
lint: ; $(if $(FILE),php -l $(FILE),composer validate)
```

## What each layer does

| Layer | Where | What you get |
|---|---|---|
| Context | `templates/AGENTS.md.template` (≤100-line map), `templates/.claude/rules/*.md` (conventions loaded by path: Laravel, Electron/Vue, NeoForge, Velocity, TS libs, Kubernetes, docs/Noodle), `templates/GOLDEN_PRINCIPLES.md` | The agent reads a map, then only the rules for the files it touches |
| Repo-state card | `SessionStart` hook | Branch, dirty files, last commits, the PR and its CI, PROGRESS.md / active exec plan, top `agent-ready` issues, verify commands: before the first prompt |
| Issue context | `UserPromptSubmit` hook | Say `#12` and the issue's title, labels and acceptance criteria are already in context |
| Guards | `PreToolUse` hook + deny rules + sandbox | No force-push, no push to `main`, no `reset --hard` on a dirty tree, no hand-edited lockfiles or generated files, no secret reads; each block says what to do instead |
| Per-file feedback | `PostToolUse` hook | Format + lint the edited file, findings returned at once |
| Verify gate | `Stop` hook | `make check` must pass before the agent stops (cached per tree); docs and PROGRESS.md reminders |
| End-of-task review | `Stop` hook review gate + `/arffornia:review` | The session changed code, diff ≥ 10 code lines, no review stamp for the tree → the agent runs parallel finders and independent verifiers, confirmed findings only, max 3 rounds |
| Improvement loop | `prompt-signals.sh`, guard hint, `/arffornia:harness-feedback`, `/arffornia:learning-card` | Corrections and friction become `harness-feedback` issues with a patch; a weekly run makes the PR; state-of-the-art finds become learning cards |
| Handoff | `PreCompact` + `SessionEnd` hooks, `templates/PROGRESS.md`, `templates/docs/exec-plans/` | State survives compaction and session ends; never auto-committed |
| Review depth | `templates/risk.yml`, `REVIEW.md.template` | Paths → light / standard / deep + security |
| Quality | `templates/QUALITY_SCORE.md` | Area × grade × gaps (issue links), kept current by an automation |
| One-command setup | `templates/scripts/init` | Deps, `.env` from example, `make check`, next steps |
| Skills and subagents | `plugins/arffornia/skills/`, `agents/` | See [SKILLS.md](SKILLS.md) |
| CI, guards, automations | `templates/ci/`, `templates/guards/`, `automations/` | Deterministic CI (gitleaks, ADR lint, mutation nightly), architecture guards, scheduled agents without secrets |

Hook details, budgets and escape hatches (`ARFFORNIA_SKIP_CHECK=1`, `ARFFORNIA_SKIP_REVIEW=1`, `ARFFORNIA_NO_GH=1`):
[docs/HARNESS.md#the-hooks](docs/HARNESS.md#the-hooks).

## Cloud environments

Cloud sessions (claude.ai/code, Claude Code on the web) run in a fresh Ubuntu VM. A **setup
script** runs as root before Claude Code starts, and when it finishes in about five minutes
Anthropic snapshots the filesystem and reuses it for later sessions. So the slow part (Gradle
distributions, NeoForge/Minecraft artifacts, Composer and npm caches, helm/kustomize) is paid
once per environment, not once per session: sessions start hot and `make check` does not begin
with a 3-minute download.

1. Open [claude.ai/code](https://claude.ai/code), edit your environment (or create one named
   `arffornia`), select **Setup script**, then **Choose file** and pick `cloud/setup.sh` (or
   paste its content).
2. Keep network access on **Trusted** or add the hosts it needs (GitHub, Maven Central,
   `maven.neoforged.net`, `services.gradle.org`, Packagist, npm, `get.helm.sh`).
3. Optional: edit the settings block at the top (`WARM`, `TOOLS`, `PHP_VERSION="8.5"`, `PHP_EXTRA`,
   `BUDGET`). Environment variables are not set while the script runs, so set values there.
4. Save. The first session runs the script (log: `/var/log/arffornia-setup.log`); later ones
   start from the snapshot. The cache is rebuilt when you change the script or after ~7 days.

The script is idempotent, runs its jobs in parallel under a 270 s budget, never fails the
session (it always exits 0), and warms caches from shallow clones in `/opt/arffornia/warm`, so
it is independent of which repo the session opens. PHP: the website moves to Laravel 13 on
PHP 8.5 ([Arffornia_Website#103](https://github.com/Arffornia/Arffornia_Website/pull/103)), so
the script installs PHP `PHP_VERSION="8.5"` from the ondrej PPA and selects it (the VM ships an
older PHP); set `PHP_VERSION=""` to keep the VM's PHP, `PHP_EXTRA` to add a second one.

## Codex and other agents

Skills follow the open SKILL.md format. To make them visible to Codex (which scans
`.agents/skills/` from the working directory up to the repo root):

```bash
../agent-kit/codex/sync-skills.sh            # copy into .agents/skills/ (commit for Codex cloud)
../agent-kit/codex/sync-skills.sh --link     # symlink to your kit checkout (local only)
../agent-kit/codex/sync-skills.sh --check    # exit 1 when the copies drift (CI / audit)
../agent-kit/codex/sync-skills.sh --clean    # remove what the script added
```

It only touches the folders it lists in `.agents/skills/.agent-kit`; skills the repo wrote
itself are never overwritten. Hooks are Claude Code specific; Codex gets the same rules
through `AGENTS.md`, which it reads natively.

## Propose a new skill: "twice → a skill"

When you (or an agent) do the same multi-step action twice, it becomes a skill: record it with
`/arffornia:harness-feedback` (an issue labelled `harness-feedback` with the two occurrences and
the steps), then follow [SKILLS.md](SKILLS.md). The same rule applies to sensors: a rule ignored twice becomes a hook,
lint or CI check ([docs/HARNESS.md](docs/HARNESS.md#guides-and-sensors-the-escalation-rule)).

## Validate a change to the kit

```bash
claude plugin validate . && claude plugin validate plugins/arffornia
bash plugins/arffornia/scripts/tests/run.sh            # hook suite (112 cases, offline)
bash plugins/arffornia/scripts/tests/portability.sh    # bash 3.2 / BSD traps
shellcheck -S warning plugins/arffornia/scripts/*.sh plugins/arffornia/scripts/tests/*.sh cloud/setup.sh codex/sync-skills.sh templates/scripts/init
nix develop --command bash plugins/arffornia/scripts/tests/run.sh   # same, in the pinned nix toolchain
```
