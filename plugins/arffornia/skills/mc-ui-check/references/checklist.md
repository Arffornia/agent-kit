# GUI review checklist (spec 006 rules)

- [ ] Every visible string is a lang key (`gui.arffornia.<screen>.<element>`), present in
      `en_us` and `fr_fr`; no `Component.literal` prose.
- [ ] No text inside textures (`textures/gui/**`): labels are drawn from lang keys.
- [ ] Widget widths come from `font.width(component)` + padding, wrap with `font.split`, or
      ellipsis + full text in a tooltip. No fixed pixel widths for text.
- [ ] Sentences are not built by concatenation; arguments via `%s` / `%1$s`.
- [ ] Numbers formatted with the client locale (`1 000`, `2,5` in French); energy with units.
- [ ] Layout positioned relative to the screen size; checked at GUI scale 2, 3, 4 and the
      smallest supported window (854x480).
- [ ] French typography: no-break space before `:` `;` `?` `!`, `« »`.
- [ ] Locked/disabled states readable (not only colour); tooltips explain why ("Locked: Stage 3").
- [ ] Contrast of text on dark panels; accent colour from the tier palette.
- [ ] Screens of machines sharing a `GuiLayout` still fit every machine's longest label.
