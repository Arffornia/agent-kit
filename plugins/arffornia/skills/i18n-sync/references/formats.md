# i18n formats in Arffornia

| Repo | Source | Target | Shape | Placeholders | Notes |
|---|---|---|---|---|---|
| Arffornia_Launcher_V.5.2 | `src/renderer/src/i18n/locales/en.json` | `fr.json` | nested JSON (vue-i18n) | `{name}`, linked `@:key`, plural `one \| many` | `useI18n().t('a.b')`; main process notifications must be translated too, via a key sent to the renderer |
| Arffornia_Website | `lang/en/*.php`, `lang/en.json` | `lang/fr/...` | PHP arrays, flat JSON | `:name` (`:Name`, `:NAME` change case) | `__('file.key')`, `@lang`, `trans_choice` with `{0} ...\|[1,*] ...`; publish missing framework files with `php artisan lang:publish` |
| Arffornia_Mods | `src/main/resources/assets/arffornia/lang/en_us.json` | `fr_fr.json` | flat JSON, dotted keys | `%s`, `%1$s`, `%%` | `Component.translatable(key, args)`; a missing fr key falls back to en in game but fails the lang lint |

## What the parity script treats as equal

- Laravel and vue-i18n: placeholder **sets** (a translation may use `:attribute` once where
  English uses it twice). Laravel casing variants are the same placeholder.
- Minecraft: the **multiset** of `%s`/`%d`/`%1$s`: the count matters (positional arguments).
  `%s %s` in English may become `%2$s ... %1$s` in French only if you also change the English
  to positional form; the script reports it otherwise.
- vue-i18n plurals: the number of `|`-separated forms must match.

## Edge cases

- Keys with dots in flat JSON (Laravel `lang/en.json`, Minecraft): kept as is, never split.
- Arrays in PHP lang files: flattened with numeric indexes (`list.0`).
- Datagen: if the mod generates `en_us.json` with a `LanguageProvider`, edit the provider, not
  the JSON, and run `make data`.
- New language later (`de_de`): one more file; run the script with `--target de`.
