# Rendering screens headless (specs 004 and 006)

Status at writing: research specs, not implemented. Spec 004 recommends a **dev-only test
harness mod** (own source set, never in the release jar) run by a `clientTest` Gradle run under
`xvfb-run` with Mesa llvmpipe; spec 006 adds LDLib2 `UIScenario`s if LDLib2 is adopted.

## When the harness exists (pilot: Crafter screen)

```bash
xvfb-run -a -s "-screen 0 1280x720x24" ./gradlew runClientTest --no-daemon -Dorg.gradle.jvmargs=-Xmx2g
```
Run properties from spec 004: `-Darffornia.backend=fake`, `-Darffornia.testharness=true`,
fixed window 1280x720, `-Dfml.earlyWindowControl=false`, `LIBGL_ALWAYS_SOFTWARE=1`. Check that
the log shows `GL_RENDERER` = llvmpipe (a silent fallback is a known trap).
Outputs: `{screen}.{locale}.gui{scale}.png` for `en_us`, `fr_fr`, `en_xx` x scales 2, 3, 4,
a contact sheet, and `report.json` with: raw keys found, widgets whose text overflows
(`font.width(component)` > box width), widgets present, bound values. The **text-fits** check is
the gate; golden-image diffs only for a few key screens (brittle across Mesa versions).

## Before the harness (today)

- With a display: `make run-client` (or `./gradlew runClient --no-daemon -Dorg.gradle.jvmargs=-Xmx2g`),
  Options → Language (English / Français), Video Settings → GUI Scale 2, 3, 4; open the screen;
  F2 screenshots land in `run/screenshots/`.
- Pseudo-locale: copy `build/ui-check/en_xx.json` to `run/resourcepacks/<pack>/assets/arffornia/lang/en_us.json`
  in a local resource pack (never commit it) to see +30% strings in the English slot.
- Headless without the harness: the dev client can boot under `xvfb-run` with llvmpipe at a
  few FPS; opening a specific screen needs a world and the block, so this is rarely worth it
  before the harness. Say "not rendered".
