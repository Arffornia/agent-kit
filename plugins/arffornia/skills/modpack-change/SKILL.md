---
name: modpack-change
description: "Add, upgrade or remove a mod or plugin in Arffornia_Provisioning safely: resolve the exact CurseForge/Modrinth/GitHub file, check NeoForge 1.21.1, client vs server side, duplicates and dependencies, regenerate indexes, one content PR. Use whenever a change touches config/*/modList.json or config/*/storage/."
argument-hint: "add|upgrade|remove <mod> [launcher|server|proxy]"
paths:
  - "config/*/modList.json"
  - "config/*/storage/**"
---

# Change the modpack

`main` of Arffornia_Provisioning is **live production**: launchers pick it up at next start,
servers at next pod start. A wrong file id or a client-only mod on the server breaks every
player. Request: `$ARGUMENTS`.

## Rules

- One content change per PR, never mixed with tooling (`src/`, `generateIndexes.ts`,
  workflows, Makefile). Branch `content/<kind>-<slug>`, title `content(<kind>): <what>`; the
  body says it changes what players or servers get.
- Never edit `index.json` by hand. Never commit secret values (`${CFG_*}` placeholders only).
- A mod that changes gameplay or progression is Brian's decision: draft the proposal, stop.

## Steps

All commands from the Provisioning root; the script is read-only.

1. **Resolve the exact file** and check loader and game version:
   ```bash
   S=${CLAUDE_SKILL_DIR}/scripts/modpack.py
   python3 $S resolve curseforge <projectId>              # lists NeoForge 1.21.1 files, newest first
   python3 $S resolve curseforge <projectId> <fileId>     # FAIL if not NeoForge 1.21.1
   python3 $S resolve modrinth <slug|versionId>           # also prints client/server side + required deps
   ```
   CurseForge dependencies need `CF_API_KEY` in the environment (never print it); without it,
   read the project's Relations tab. Prefer `release` files; say why if you pick a beta.
2. **Decide the side(s)**: `config/launcher/` = client, `config/server/` = server,
   `config/proxy/` = Velocity plugins. Content mods (blocks, items, recipes, entities) go on
   launcher **and** server with the **same file id**. How to classify the unclear ones:
   [references/sides.md](references/sides.md).
3. **Check duplicates and dependencies:**
   ```bash
   python3 $S dupes --name "<display name>" [--project <id> | --version <id>]
   ```
   `PRESENT` lines mean the mod is already there (another source, name or committed jar):
   upgrade that entry instead. `PRE-EXISTING` lines are problems already on `main`: list them
   in the PR as follow-ups, do not fix them in this PR. Every required dependency must be
   present once, on the same sides.
4. **Edit** `config/<kind>/modList.json`, keeping order and 4-space indentation. Get the entry
   text with `python3 $S entry curseforge <projectId> <fileId>` (or `entry modrinth <versionId>`).
   Removal: also its configs under `storage/` if nothing else uses them, and dependencies only
   it needed. Validate: `jq . config/<kind>/modList.json >/dev/null`.
5. **Regenerate** if anything under `storage/` changed: `make indexes`.
6. **Check:** `make check`, then `python3 $S dupes` again (no new problem).
7. **PR body:** per kind, mod, source, old → new file id, side, dependencies added/removed, the
   changelog link for upgrades, and "Players get this at next launcher start / next server
   restart". Risk & revert: revert the PR; a removed mod's blocks and items are lost from
   server worlds, so say so. Template: [references/pr-body.md](references/pr-body.md).

Report per [references/reporting.md](references/reporting.md): the PR (or the proposal when it
needs Brian), the mod's project page URL, and pre-existing problems as follow-ups.
