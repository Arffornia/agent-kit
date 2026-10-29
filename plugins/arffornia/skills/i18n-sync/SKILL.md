---
name: i18n-sync
description: "Keep English and French translations in sync across Arffornia (launcher vue-i18n JSON, Laravel lang PHP/JSON, mod en_us/fr_fr lang JSON): key parity, placeholders, hardcoded strings, French drafts marked for review. Use after adding or changing player-facing text, or when asked to check or fix translations."
paths:
  - "**/lang/**"
  - "**/locales/**"
  - "**/*.vue"
  - "**/*.blade.php"
---

# Keep en and fr in sync

Player-facing text is never hardcoded: it goes through i18n with at least `en` and `fr`.
English is the source of truth for keys; French is most players' language, so its wording
matters as much.

## 1. Check parity (deterministic)

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/i18n_parity.py            # from the repo root; auto-detects the stack
python3 ${CLAUDE_SKILL_DIR}/scripts/i18n_parity.py --strict   # also flags fr values identical to en
```
It finds `src/renderer/src/i18n/locales/{en,fr}.json` (launcher), `lang/{en,fr}/*.php` and
`lang/{en,fr}.json` (website, needs `php`), `assets/*/lang/{en_us,fr_fr}.json` (mod), and
reports missing keys, stale keys, placeholder mismatches (`{name}`, `:name`, `%s`/`%1$s`),
plural form counts, empty values and values equal to their key. Exit 1 = something to fix.
Formats and edge cases: [references/formats.md](references/formats.md).

## 2. Find hardcoded strings in what you changed

```bash
git diff --name-only origin/<base>...HEAD | xargs grep -nE \
  'Component\.literal\("[^"]*[A-Za-z]{3,} |>[A-Z][a-z]+( [a-z]+)+<|alert\(["'"'"'][A-Z]|addNotification\(`?["'"'"'][A-Z]' 2>/dev/null
```
Move each to a key (`gui.arffornia.<screen>.<element>` in the mod, `<page>.<element>` on the
website, `<view>.<element>` in the launcher). Logs, exceptions and admin CLI output stay English.

## 3. Write the French

- Missing in fr: draft it. Keep placeholders, markup and punctuation structure; French
  typography and Minecraft vocabulary are in [references/french-style.md](references/french-style.md).
- Record every drafted key in the PR under **Translations to review**. Never put review
  markers in the files: they would show to players.
- Only in fr: usually old French source text. Add the English and check the code uses the key.
- Unused keys: list them in the PR; remove only if `grep -rn` finds no use, including dynamic
  keys (`'shop.' + id`, `__("stages.$slug")`).

## 4. Validate

- Rerun the parity script: exit 0.
- Files stay valid and keep their order and indentation (`jq . file >/dev/null`;
  `php -l lang/fr/x.php`).
- See both languages on screen when the repo runs locally (launcher, website); for the mod,
  name the keys a tester should see in game, or run its lang lint if present.

Report per [references/reporting.md](references/reporting.md): the PR, the parity result line,
and the list of drafted French keys for Brian to review.
