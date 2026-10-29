---
paths:
  - "app/**/*.php"
  - "routes/**/*.php"
  - "config/**/*.php"
  - "database/**/*.php"
  - "resources/views/**/*.blade.php"
  - "tests/**/*.php"
  - "lang/**"
---

# Laravel 12 / PHP 8.3 conventions (Arffornia_Website)

- **Layering**: Controller → Service → Repository → Eloquent. Controllers stay thin: no
  `DB::`/model queries in controllers (StagesController is the known exception being split).
- **Validation in FormRequests**, not inline `Validator::make`. Every `$request->input()` that
  reaches a query, a command string or a file path is validated first (types, `exists:`, max sizes).
- **Responses through API Resources**. Never return a raw model: it leaks columns
  (`ShopItem::commands`, password hashes). The JSON shape is a contract with the mod, proxy and
  launcher: change it only with a contract test and a note in the PR.
- **Auth**: Sanctum tokens for API callers, roles via the `anyRole`/`allRole` middleware. New
  routes state their guard and role explicitly in `routes/api.php`. A GET never mutates state.
- **Money and rewards** (`shop`, `pending_rewards`, votes): inside `DB::transaction()` with
  `lockForUpdate()`; test the concurrent path on Postgres, not only sqlite.
- **Strings**: user-visible text goes through `__('key')` with keys in `lang/en` and `lang/fr`
  (run `php artisan lang:publish` once if `lang/` is missing). No French or English literals in Blade.
- **Config, not literals**: URLs, reward commands, starting balance → `config/*.php` reading `env()`.
  `env()` is only called inside `config/`, never in app code (it returns null once config is cached).
- **HTTP calls** (`Http::`) always set `->timeout()` and `->connectTimeout()` and check `->successful()`.
- **Tests**: PHPUnit 12, `RefreshDatabase`, factories for every model you touch, `Http::fake()` for
  outbound calls, a 401/403/200 role matrix for each new endpoint. `make check` runs `build` before
  `test` because feature tests render Blade views that need `public/build/manifest.json`.
- Formatting is Pint (`make fmt FILE=...`); static analysis is phpstan (`make phpstan`, baseline pending).
- Never commit `.env`, `_ide_helper.php` regenerations, or `public/build/`.
