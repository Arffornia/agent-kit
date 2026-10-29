# agent-kit

The shared Claude Code setup for the Arffornia repositories: one plugin marketplace with one
plugin, `arffornia`, plus the templates each repo copies (`AGENTS.md`, `REVIEW.md`,
`.claude/settings.json`, `CLAUDE.md`). Skills are written once here and used in every repo.

```
.claude-plugin/marketplace.json     marketplace "agent-kit", lists the plugin
plugins/arffornia/
  .claude-plugin/plugin.json        plugin "arffornia"
  skills/<name>/SKILL.md            the six skills below
  agents/reviewer.md                read-only review subagent
templates/                          files a repo copies to adopt the setup
```

## Install

In a Claude Code session:

```
/plugin marketplace add Arffornia/agent-kit
/plugin install arffornia@agent-kit
```

That installs it for you (user scope). **Project scope** (everyone working in a repo): copy
`templates/.claude/settings.json` into the repo and commit it. Its `extraKnownMarketplaces` and
`enabledPlugins` keys register the marketplace and enable `arffornia@agent-kit` for each
contributor once they trust the folder. The same file can be produced with
`claude plugin marketplace add Arffornia/agent-kit --scope project` and
`claude plugin install arffornia@agent-kit --scope project`.

Updates: `/plugin marketplace update agent-kit`, or turn on auto-update for the marketplace in
`/plugin` → Marketplaces. The plugin has no `version`, so users track commits on `main`.

## Skills

Invoke as `/arffornia:<skill>`; Claude also loads them on its own when the task matches,
except `publish`.

| Skill | What it does |
|---|---|
| `work-ticket` | Issue → branch `<type>/<n>-slug` → implement + test → `make check` → PR with the template, labels and `Closes #n`. Also drafts issues with the label taxonomy (`type:`, `area:`, `priority:`, `effort:`; `agent-ready` only with acceptance criteria). Arffornia edition of Brian's `work-ticket`. |
| `publish` | **Human-invoked only** (`disable-model-invocation: true`). Verifies the branch, tree and secrets, runs `make check`, fills the PR template, pushes and opens a **draft** PR. |
| `mc-gametest` | Write, run and debug NeoForge 1.21.1 GameTests in Arffornia_Mods (`platform` template, `@GameTestHolder`, fake backend, `runGameTestServer`, reading failures). Based on Arffornia_Mods PR #48. |
| `modpack-change` | Add/upgrade/remove a mod in Arffornia_Provisioning: exact CurseForge/Modrinth/GitHub ids, client vs server side, duplicates, `make indexes`, one `content(<kind>):` PR never mixed with tooling. |
| `review` | Risk-based review following the repo's `REVIEW.md`: depth by risk, `path:line` evidence for every finding, max 3 style remarks, findings count first. |
| `i18n-sync` | Keep en/fr keys in sync (launcher vue-i18n, Laravel `lang/`, mod `en_us`/`fr_fr`), draft missing French and list it under "Translations to review" in the PR. |

Agent: `arffornia:reviewer` (Opus, read-only tools, preloads `review`). Use it before
`/arffornia:publish`, or ask "review PR #12 with the reviewer agent".

## Adopt in a repo

1. Copy the templates:
   ```bash
   KIT=../agent-kit/templates
   mkdir -p .claude && cp $KIT/.claude/settings.json .claude/
   cp $KIT/REVIEW.md.template REVIEW.md
   [ -f AGENTS.md ] || cp $KIT/AGENTS.md.template AGENTS.md
   [ -f CLAUDE.md ] || cp $KIT/CLAUDE.md CLAUDE.md
   ```
2. Fill `REVIEW.md` with the repo's real risk paths, invariants and files to skip.
3. Keep `AGENTS.md` under 150 lines; add the "AI setup" section from the template.
4. The repo needs `make check`; `make fmt` is optional (the formatter hook does nothing without it).
5. One PR, title `chore: AI setup (agent-kit plugin, settings, REVIEW.md)`. Arffornia_Proxy is the pilot.

### What `templates/.claude/settings.json` does

- **deny**: reading/editing `.env*` (except `.env.example`) and `secrets/**`; reading keys and
  credential files (`*.pem`, `*.key`, `*.jks`, `credentials.json`, `~/.ssh`, `~/.aws`, `~/.kube`,
  `~/.config/gh`, `~/.npmrc`, `~/.gradle/gradle.properties`); `gh pr merge` and `gh release`.
- **ask**: `git push` always asks.
- **PostToolUse** after `Edit|Write|MultiEdit`: runs `make fmt FILE=<edited file>` when the
  Makefile has a `fmt` target. Never blocks.
- **Stop #1**: if the branch has changes, runs `make check`; when it fails, blocks the stop and
  feeds the last 40 lines back to Claude. A pass is cached per tree state in `.git/`, so an
  unchanged tree is not rebuilt. `stop_hook_active` prevents loops.
- **Stop #2**: if source dirs (`src/ app/ routes/ resources/ lib/ database/`) changed on the
  branch but `AGENTS.md`, `README.md` and `docs/` did not, reminds Claude once per change set.

The hooks are inline shell because settings cannot reference plugin files; they are written to
be no-ops outside a git repo or without a Makefile.

## Propose a new skill: "twice → a skill"

When you (or an agent) do the same multi-step action twice, it becomes a skill.

1. Open an issue here: `type: feature`, `area: ai`, title `Add <name> skill`, with the two times
   it happened and the steps.
2. Add `plugins/arffornia/skills/<name>/SKILL.md`: a `description` that says what and when,
   steps that can be followed literally, under ~150 lines. Add
   `disable-model-invocation: true` if it pushes, publishes or deletes anything.
3. `claude plugin validate .` and `claude plugin validate plugins/arffornia` pass.
4. Add a row to the Skills table above. PR, Brian merges.

## Validate

```bash
claude plugin validate .                    # marketplace
claude plugin validate plugins/arffornia    # plugin, skills, agent
```
