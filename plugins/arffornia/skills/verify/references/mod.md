# Mod (NeoForge 1.21.1)

## Server logic: GameTests

```bash
./gradlew runGameTestServer --no-daemon -Dorg.gradle.jvmargs=-Xmx2g
```
One Gradle build at a time on the small machine. Pass = `All N required tests passed :)` and
exit 0. Evidence: that line plus the names of the tests covering each check (grep the test
class), and the "broke the guarded code, test failed, restored" note for new tests.
Tests run with `arffornia.backend=fake` (in-memory progression, never the website).

## Screens (until the client harness of spec 004 exists)

- Static checks: lang key parity (`en_us` / `fr_fr`), every `Component.translatable` key exists,
  no `Component.literal` prose, French length ratio for GUI keys.
- Manual run when a display is available: `make run-client` (or `./gradlew runClient`), open the
  screen in `en_us` and `fr_fr` at GUI scale 2, 3 and 4, screenshot (F2) each; under xvfb with
  `LIBGL_ALWAYS_SOFTWARE=1` and `-Dfml.earlyWindowControl=false` it boots slowly but works.
  Log `GL_RENDERER` (must be llvmpipe headless).
- When the `clientTest` harness lands (spec 004 pilot: `./gradlew runClientTest` under
  `xvfb-run`), use it: it writes `{screen}.{locale}.gui{scale}.png`, a contact sheet and
  `report.json` (no raw keys, no overflow). Attach the contact sheet.

## Preview server (spec 004 / ADR-0007, later)

RCON on `arffornia-pr-mods-N` with allow-listed commands only; never cluster credentials.
