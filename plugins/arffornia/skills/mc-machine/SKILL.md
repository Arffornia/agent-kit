---
name: mc-machine
description: "Add a production machine to the Arffornia mod: on the machine framework of spec 002 (MachineType + model + lang + data recipes) once it exists, otherwise a guided checklist on today's Crafter-style code (block, block entity, menu, screen, validated packets, capabilities, GameTests, en/fr). Use when asked to add, scaffold or port a machine, multiblock or Crafter-like block, or to plan tier content from spec 003."
argument-hint: "<machine id> [tier] [single|multiblock]"
paths:
  - "**/machine/**"
  - "**/block/entity/**"
  - "**/screen/**"
---

# Add a machine

Machine: `$ARGUMENTS`. Machines are gameplay: the list, tiers, numbers and recipes come from
spec 003 (Satisfactory-inspired tier plan) and Brian's decisions, never from you. If the
machine or its numbers are not in an approved spec or issue, draft the proposal and stop.

## 0. Which path?

```bash
test -f src/main/java/fr/thegostsniperfr/arffornia/machine/MachineType.java && echo framework || echo legacy
```

## A. Framework exists (spec 002 implemented)

A standard machine is **data + model**, no new Java:
1. Register a `MachineType` in the machine registry (`MachineType.builder("<id>")` with
   `slots(SlotLayout.of(in(n), out(m)))`, `energy(buffer, maxIn)`, `recipes("arffornia:<id>")`,
   `gui("<layout id>")`, `tier(n)`), following the existing machines.
2. Assets: blockstate, block and item model, texture (`assets/arffornia/...`); run datagen
   (`make data`) so blockstates, loot tables and lang stubs are generated and the asset
   completeness check passes.
3. Recipes as data under `data/arffornia/recipe/machine/<id>/` with their stage gating
   (spec 001); per-machine numbers in the `arffornia:machine_stats` data map.
4. Lang keys in `en_us` and `fr_fr` (`block.arffornia.<id>`, `gui.arffornia.<id>.*`).
5. GameTests from the shared machine test kit: crafts with energy, pauses without, output
   blocked, side config respected, select-recipe rejected when locked or far, save/load.
6. Multiblock: a `MultiblockDef` with its template `.nbt`, controller and port offsets;
   tests for all 4 rotations x mirror and disassembly.
Details and the class map: [references/framework.md](references/framework.md).

## B. Framework not there yet (today)

Do not build a one-off machine that the framework will have to port again unless the issue
asks for it. If it does, follow the Crafter's structure and the checklist in
[references/legacy-checklist.md](references/legacy-checklist.md): block (+ part block for
two-tall), block entity with server-only ticking, `ItemStackHandler` with role checks, FE
`EnergyStorage`, menu with `stillValid` and distance, screen with lang keys, **validated**
serverbound packets (menu open, distance, owner's stage), capabilities in
`CapabilityRegistration`, registration in `ModBlocks` / `ModBlockEntities` / `ModMenuTypes` /
`ModItems` / `ModCreativeTabs`, JEI category, GameTests, en/fr.

## Done means

`make check` and `runGameTestServer` green (`--no-daemon -Dorg.gradle.jvmargs=-Xmx2g`), the
UI checks for its screen (lang parity, no `Component.literal` prose, French length), a
screenshot of the screen in `en_us` and `fr_fr` when a client can run, and the PR lists the
spec and decision it implements. Report per [references/reporting.md](references/reporting.md).
