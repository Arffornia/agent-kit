---
name: modpack-change
description: Add, upgrade or remove a mod (or plugin) in Arffornia_Provisioning safely - CurseForge/Modrinth/GitHub ids, client vs server side, duplicates, dependencies, index regeneration, and a separate content PR. Use whenever a change touches config/*/modList.json or config/*/storage/ in Arffornia_Provisioning.
argument-hint: "add|upgrade|remove <mod> [launcher|server|proxy]"
---

# Change the modpack

`main` of Arffornia_Provisioning is **live production**: launchers pick it up at next start,
servers at next pod start. A wrong id or a client-only mod on the server breaks every player.

## Rules

- **One content change per PR, never batched with tooling** (`src/`, `generateIndexes.ts`,
  workflows, Makefile). Branch `content/<kind>-<slug>`, title `content(<kind>): <what>`, and the
  body says explicitly that it changes what players or servers get.
- Never edit `index.json` by hand. Never commit secret values (`${CFG_*}` placeholders only).
- Ask Brian before adding a mod that changes gameplay; that is a design decision.

## Steps

1. **Identify the exact file.** For each source, record the ids from the project page or API:
   - CurseForge: `{ "displayName", "projectId", "fileId" }` (file for **NeoForge 1.21.1**).
   - Modrinth: `{ "displayName", "versionId" }` (the version, not the project).
   - GitHub releases: `{ "displayName", "owner", "repoName", "tag", "assetName" }`.
   Check loader = NeoForge and game version = 1.21.1 on that file. Note its required dependencies.
2. **Decide the side(s).** `config/launcher/` = client, `config/server/` = server,
   `config/proxy/` = Velocity plugins.
   - Client-only (shaders, minimaps UI, rich presence): launcher only.
   - Server-only (admin tools, backups): server only.
   - Both (content, blocks, items, recipes): launcher **and** server, **same file id** on both.
3. **Check duplicates.** The mod must not already be in `modList.json` under another source
   or display name, nor committed as a jar in `config/<kind>/storage/mods/`:
   ```bash
   jq -r '.mods[][] | .displayName' config/*/modList.json | sort | uniq -c | sort -rn | head
   ls config/*/storage/mods/
   ```
   Also check its dependencies are present (and not twice).
4. **Edit** `config/<kind>/modList.json` (keep the existing order and indentation). For removal,
   also remove its configs under `storage/` if nothing else uses them, and dependencies that only
   it needed.
5. **Regenerate** if anything under `storage/` changed: `make indexes`. (The bot commit
   "🔃 Update indexes" also runs on `main`; regenerating in the PR keeps the diff reviewable.)
6. **Check:** `make check` (schema, duplicates and index freshness tests where present).
7. **PR body** lists, per kind: mod, source, old → new file id, side, dependencies added or
   removed, and "Players get this at next launcher start / next server restart". Link the mod's
   changelog for upgrades. Under Risk & revert: revert the PR; a removed mod's world data
   (blocks, items) is lost on servers, so say so.
