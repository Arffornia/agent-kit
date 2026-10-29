# Architecture guards

Deterministic sensors for the layering rules agents break most. Each failure message says what
is wrong **and how to fix it**, so an agent can repair its own change without asking. All three
start with a **baseline** of the violations that exist on adoption: CI stays green, every new
violation fails, and the baseline may only shrink (reviewers and the AI review flag growth).

| Stack | Tool | Files | Rules |
|---|---|---|---|
| Laravel (Website) | [deptrac](https://github.com/deptrac/deptrac) 4.x | `laravel/deptrac.yaml`, `laravel/deptrac.baseline.yaml`, `laravel/tools/deptrac-explain.php` | Controllers → Services → Repositories → Models; no Eloquent/DB/Models/Repositories in controllers; Http facade/client only in Services |
| Electron + Vue (Launcher) | [dependency-cruiser](https://github.com/sverweij/dependency-cruiser) 18.6 | `electron/.dependency-cruiser.cjs`, `electron/tools/check-preload-exposure.mjs`, `electron/tools/preload-exposure-known.json` | renderer ↛ main/preload/Node/electron; main ↛ renderer/preload; preload imports only `electron`; preload exposes only `window.api`; circular imports warn |
| NeoForge (Mod) | [ArchUnit](https://www.archunit.org) 1.5 | `neoforge/ArchitectureTest.java`, `neoforge/archunit.properties`, `neoforge/build.gradle.snippet` | common code ↛ client classes; every `Serverbound*` payload calls the validation helper; no `Component.literal` outside an allow-list |

## Laravel: deptrac

```bash
composer require --dev deptrac/deptrac:^4.7
cp $KIT/guards/laravel/deptrac.yaml $KIT/guards/laravel/deptrac.baseline.yaml .
mkdir -p tools && cp $KIT/guards/laravel/tools/deptrac-explain.php tools/
vendor/bin/deptrac analyse --formatter=baseline --output=deptrac.baseline.yaml   # freeze today's debt once
```
Makefile:
```make
arch: ## Architecture guard (deptrac); prints a fix for each violation
	@mkdir -p build
	vendor/bin/deptrac analyse --no-progress --formatter=json --output=build/deptrac.json >/dev/null || true
	php tools/deptrac-explain.php build/deptrac.json

check: lint arch test   # add arch to the existing check prerequisites
```
`deptrac-explain.php` maps each `(FromLayer on ToLayer)` violation to a one-line fix and exits 1.
If the maintainer wants route-model binding in controllers, add `Model` to the `Controller`
ruleset (Eloquent stays forbidden). Not executed in the kit's CI: verify on first adoption.

## Electron launcher: dependency-cruiser

```bash
npm install --save-dev dependency-cruiser@18.6.0
cp $KIT/guards/electron/.dependency-cruiser.cjs .
mkdir -p tools && cp $KIT/guards/electron/tools/* tools/
npx depcruise src --config .dependency-cruiser.cjs --output-type baseline \
  --output-to .dependency-cruiser-known-violations.json                     # freeze today's debt once
```
package.json scripts and Makefile:
```json
"arch": "depcruise src --config .dependency-cruiser.cjs --ignore-known --output-type err-long && node tools/check-preload-exposure.mjs",
"arch:baseline": "depcruise src --config .dependency-cruiser.cjs --output-type baseline --output-to .dependency-cruiser-known-violations.json"
```
```make
arch: ## Architecture guards (dependency-cruiser + preload exposure)
	npm run arch

check: lint arch test build
```
`err-long` prints each rule's `comment`, which holds the fix. Put pre-existing extra preload
globals (e.g. `"electron"`) in `tools/preload-exposure-known.json`; the script reminds you to
remove an entry once it is gone. Add `.dependency-cruiser-known-violations.json` to
`.prettierignore` (generated). Re-run `arch:baseline` only after fixing violations, never to
accept new ones. Piloted in Arffornia_Launcher_V.5.2.

## NeoForge mod: ArchUnit

```bash
cp $KIT/guards/neoforge/ArchitectureTest.java src/test/java/<base/package/path>/architecture/
cp $KIT/guards/neoforge/archunit.properties src/test/resources/
# add the build.gradle.snippet lines (JUnit 5 + archunit, useJUnitPlatform, -Darchunit.* forwarding)
./gradlew test --no-daemon -Darchunit.freeze.store.default.allowStoreCreation=true   # freeze today's debt once
git add src/test/resources/archunit_store
```
`make check` already runs `./gradlew build`, which runs `test`. Adapt `BASE`,
`VALIDATION_HELPER`, `CLIENT_ENTRY_POINTS` and `LITERAL_ALLOW_LIST` at the top of the test.
Rules are wrapped in `FreezingArchRule`: the store keeps existing violations (matched without line
numbers), fails on new ones, and drops entries automatically when they are fixed (commit that).
The store is keyed by the rule text, including the `because` message: editing a message means
re-creating the store (`-Darchunit.freeze.store.default.allowStoreCreation=true` after deleting
it, then check the diff only removed or kept lines). Piloted in Arffornia_Mods.

## Writing a new guard

Add one when a review finding repeats twice ("a rule an agent ignores twice becomes a sensor").
The message must name the rule, why it exists, and the concrete fix (file, API, pattern). Start
with a baseline, never with a wall of red.
