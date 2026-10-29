---
name: release-notes
description: "Draft player-facing release notes in English and French from the PRs merged since the last release of an Arffornia repo (mod, launcher, website, modpack), plus a short technical changelog. Drafts only, never creates a release or tag. Use when preparing a release, an update announcement, a changelog or patch notes."
argument-hint: "<repo> [--since <tag|date>]"
context: fork
agent: general-purpose
background: false
---

# Release notes (EN + FR draft)

Scope: `$ARGUMENTS`. You run in a fresh context. You read GitHub and write a draft; you never
create a release, tag, or post an announcement (Brian does).

## 1. Collect merged PRs

```bash
mkdir -p build/release-notes
python3 ${CLAUDE_SKILL_DIR}/scripts/merged_prs.py Arffornia/<repo> [--since <tag|YYYY-MM-DD>] --json > build/release-notes/prs.json
python3 ${CLAUDE_SKILL_DIR}/scripts/merged_prs.py Arffornia/<repo> [--since ...]    # readable list
```
Default `--since` = the latest release, else the latest tag. Each PR is tagged `PLAYER` or
`intern` from its labels and files. For the modpack (Arffornia_Provisioning), the player
changes are the `content(...)` PRs: read their tables (mod, old → new version).

## 2. Decide what players care about

Read each PLAYER PR's body (intent), not just the title. Keep what a player notices: new
content, fixed bugs they hit, changed behaviour, performance, removed things (and what
happens to their items). Drop CI, refactors, dependency bumps without visible effect, docs.
Security fixes: one neutral line ("Security hardening of …"), never the weakness.

## 3. Write

Shape and tone: [references/style.md](references/style.md). Two blocks, English then
French, same structure: **New**, **Improved**, **Fixed**, **Removed / heads-up**. One line per
item, player words ("The Crafter no longer…"), no PR jargon. The French is natural French
for players (vous, Minecraft vocabulary as the French client says it), not a word-for-word
translation; mark it "to review" for Brian.

Then a short **Technical changelog** for contributors: every merged PR as
`<PR URL> - <title>`.

## 4. Return

Save the draft to `build/release-notes/<repo>-<date>.md` (or return it inline when asked) and
report per [references/reporting.md](references/reporting.md): Decide (items you were unsure
are player-facing), Review (the draft path), FYI (PR count, range).
