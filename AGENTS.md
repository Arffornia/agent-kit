# AGENTS.md — agent-kit

## Purpose
The Claude Code plugin marketplace for Arffornia. Skills and the reviewer agent used in every
Arffornia repo live here, plus the templates repos copy to adopt them. See `README.md`.

## Layout
| Path | What |
|---|---|
| `.claude-plugin/marketplace.json` | Marketplace `agent-kit`; one entry `arffornia` → `./plugins/arffornia` |
| `plugins/arffornia/.claude-plugin/plugin.json` | Plugin manifest (no `version`: users track commits) |
| `plugins/arffornia/skills/<name>/SKILL.md` | One folder per skill; namespaced `/arffornia:<name>` |
| `plugins/arffornia/agents/reviewer.md` | Read-only review subagent `arffornia:reviewer` |
| `templates/` | `AGENTS.md.template`, `REVIEW.md.template`, `.claude/settings.json`, `CLAUDE.md` |

## Check before handing back
```bash
claude plugin validate .
claude plugin validate plugins/arffornia
jq . templates/.claude/settings.json >/dev/null
```

## Rules
- English. Skills are instructions Claude follows literally: concrete commands, no filler,
  under ~150 lines each; put long reference material in a sibling file the skill links.
- `description` says what the skill does and when to use it, key use case first.
- Anything that pushes, publishes, deletes or releases sets `disable-model-invocation: true`.
- Skills never tell an agent to merge, tag, release, push to `main` or touch secrets.
- Keep the marketplace entry `name` and `plugin.json` `name` identical (`arffornia`); renaming
  breaks every `enabledPlugins` entry.
- A template change is a change in every repo that adopts it next: say so in the PR.
- New skill: the "twice → a skill" rule in `README.md`.
- Conventional Commits (`feat(skills): ...`, `fix(templates): ...`), one concern per PR, never
  merge; Brian merges.
