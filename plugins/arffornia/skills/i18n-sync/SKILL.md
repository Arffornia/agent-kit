---
name: i18n-sync
description: Keep English and French translation keys in sync across Arffornia (launcher vue-i18n locales, Laravel lang files, mod en_us/fr_fr lang JSON) and draft missing translations marked for review. Use after adding or changing player-facing text, or when asked to check or fix translations.
---

# Keep en and fr in sync

Player-facing text is never hardcoded: it goes through i18n with at least `en` and `fr`.
English is the source of truth for keys; French is the players' main language, so its wording
matters as much.

## Where the files are

| Repo | English | French | Notes |
|---|---|---|---|
| Arffornia_Launcher_V.5.2 | `src/renderer/src/i18n/locales/en.json` | `…/fr.json` | nested JSON, vue-i18n; `{name}` placeholders |
| Arffornia_Website | `lang/en/*.php` or `lang/en.json` | `lang/fr/…` | Laravel; `:name` placeholders. If `lang/` does not exist yet, `php artisan lang:publish` first |
| Arffornia_Mods | `src/main/resources/assets/arffornia/lang/en_us.json` | `…/fr_fr.json` | flat keys (`block.arffornia.crafter`); `%s` / `%1$s` placeholders |

## Steps

1. **Diff the key sets** (flatten nested JSON to dotted keys):
   ```bash
   flat() { jq -r '[paths(scalars) | map(tostring) | join(".")] | .[]' "$1" | sort; }
   comm -3 <(flat en.json) <(flat fr.json)    # left: missing in fr, right: missing in en
   ```
   For Laravel PHP arrays: `php -r 'echo json_encode(require "lang/en/x.php");'` then the same.
2. **Find hardcoded strings** in the files you changed (text in templates, `Component.literal("…")`,
   `__()` missing) and move them to keys.
3. **Missing in fr:** draft a French translation. Keep placeholders, markup and punctuation
   identical; keep Minecraft terms as the French game client says them (e.g. "Établi").
   Record every drafted key in the PR under a **Translations to review** heading.
   Do not put review markers inside the JSON: it would show to players.
4. **Missing in en:** a key that exists only in fr is usually old French source text: add the
   English and check the code uses the key.
5. **Unused keys:** list them in the PR; remove only if `grep -r` finds no use, including dynamic
   keys (`'shop.' + id`).
6. Keep key order and indentation of each file; valid JSON (`jq . file >/dev/null`).
7. Check both languages on screen when the repo can run locally (launcher, website); for the mod,
   name the keys a tester should see in game.
