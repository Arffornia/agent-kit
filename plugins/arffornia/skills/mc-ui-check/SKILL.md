---
name: mc-ui-check
description: "Check Arffornia in-game screens for text problems in English and French at GUI scales 2-4: raw keys, missing French, Component.literal prose, French text likely to overflow, typography, and (when the client test harness of spec 004/006 exists) rendered screenshots and the text-fits report. Use after changing a mod screen, GUI widget, tooltip or lang file, or before publishing a GUI PR."
argument-hint: "[screen or lang keys]"
paths:
  - "**/client/screen/**"
  - "**/assets/arffornia/lang/**"
  - "**/assets/arffornia/textures/gui/**"
---

# UI check for mod screens

Scope: `$ARGUMENTS` (default: everything the branch changed). French strings are ~20-30%
longer than English and the vanilla font is wide; overflow and raw keys are the usual bugs.

## 1. Static checks (always)

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/mc_lang_lint.py                  # from the Arffornia_Mods root
python3 ${CLAUDE_SKILL_DIR}/scripts/mc_lang_lint.py --pseudo build/ui-check/en_xx.json
```
ERRORs (exit 1): a key used in Java but missing from `en_us.json`, a key missing from
`fr_fr.json`, placeholder mismatch, `Component.literal` prose. WARNs: French over 1.3x English
on GUI keys (overflow risk), missing no-break spaces in French, keys outside the
`gui|tooltip|message.arffornia.<screen>.<element>` convention. `--pseudo` writes the spec 006
pseudo-locale (+30% length, brackets, accents) for a manual or harness run.

For each overflow WARN on a screen you changed: read the widget code. If its width comes from
`font.width(component)` + padding, wrapping (`font.split`) or an ellipsis with a tooltip, it is
fine; if it is a fixed width, shorten the French or fix the layout.

## 2. Rendered checks (when a client can run)

Which mode applies, and how: [references/harness.md](references/harness.md).
- **Harness present** (`./gradlew tasks --all | grep -i clientTest`): run it under `xvfb-run`
  for the changed screens x `en_us`, `fr_fr`, `en_xx` x GUI scale 2, 3, 4; attach the
  contact sheet and `report.json` (no raw keys, no overflow).
- **No harness yet** (today): with a display, `make run-client`, open each changed screen in
  both languages at scales 2-4, screenshot (F2), and look for clipped text, overlapping
  widgets, raw keys. Without a display: say "not rendered" and rely on step 1.

## 3. Checklist a reviewer can tick

[references/checklist.md](references/checklist.md): text never baked into textures, numbers
formatted with the locale, tooltips for truncated text, contrast on dark panels, the same
layout id for machines that share it.

## Result

```
UI check: <screens> · static: <e> errors, <w> warnings · rendered: <yes (harness|manual) | no, reason>
Errors: ...
Overflow risks reviewed: <key> - fine (font.width) | fixed (<change>)
Screenshots / contact sheet: <paths or CI artifact URL>
```
Links follow [references/reporting.md](references/reporting.md).
