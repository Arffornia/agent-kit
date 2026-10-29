---
name: mc-gametest
description: Write, run and debug NeoForge 1.21.1 GameTests for the Arffornia mod (structure templates, @GameTestHolder, runGameTestServer, reading failures). Use when adding a test for a block, block entity, menu, packet handler or progression rule in Arffornia_Mods, or when runGameTestServer fails.
paths:
  - "**/gametest/**"
  - "**/build.gradle"
---

# NeoForge GameTests in Arffornia_Mods

GameTests run a headless dedicated server, place a structure template, run your code tick by tick
and fail the build when a required test fails. Arffornia uses them for behaviour a unit test
cannot reach: block entities, menus, packets, the progression backend. The suite was introduced
by Arffornia_Mods PR #48 (`gametest/ArfforniaGameTests.java`); follow it.

## How the suite is wired

- `build.gradle`, run `gameTestServer`:
  `systemProperty 'neoforge.enabledGameTestNamespaces', project.mod_id` (only `arffornia` tests
  register, production servers never set it) and `systemProperty 'arffornia.backend', 'fake'`
  (tests use `InMemoryProgressionBackend`, never the website).
- FTB Teams needs FTB Library at runtime: `localRuntime("dev.ftb.mods:ftb-library-neoforge:…")`.
  Without it no dev run starts ("Mod ftbteams requires ftblibrary").
- Template: `src/main/resources/data/arffornia/structure/platform.nbt`, 5x4x5, stone floor at y=0,
  air above. Machines go at `new BlockPos(2, 1, 2)` (relative to the template).
- Class: `@GameTestHolder(Arffornia.MODID)` + `@PrefixGameTestTemplate(false)` so
  `template = "platform"` resolves to `arffornia:platform`.
- CI: `.github/workflows/gametest.yml` runs `./gradlew runGameTestServer` on every PR.

## Write a test

```java
@GameTest(template = PLATFORM, timeoutTicks = 100)
public static void crafterStallsWithoutEnergy(GameTestHelper helper) {
    int id = nextId();                       // unique ids: tests in a batch run in parallel
    registerRecipe(recipe(id, id, 10, 20));  // against the shared in-memory backend
    CrafterBlockEntity be = placeCrafter(helper, playerNearMachine(helper, "owner" + id), id);
    be.itemHandler.setStackInSlot(0, new ItemStack(Items.COBBLESTONE, 4));
    be.setSelectedRecipe(id);
    helper.runAfterDelay(40, () -> {
        helper.assertTrue(be.itemHandler.getStackInSlot(CrafterBlockEntity.INPUT_SLOTS).isEmpty(),
                "No energy: nothing should be crafted");
        helper.succeed();
    });
}
```

Rules:
- Method name = test id (lowercased in logs). Name the behaviour: `selectRecipeRejectedForLockedMilestone`.
- **Positive tests** end with `helper.succeedWhen(() -> assert…)` (passes as soon as true).
  **Negative tests** ("nothing happens") wait with `runAfterDelay(n, …)` then `succeed()`.
- Every assertion has a message with the actual value.
- Use relative positions (`helper.absolutePos`, `helper.absoluteVec`), never world coordinates.
- Players: `FakePlayerFactory.get(helper.getLevel(), new GameProfile(UUID.randomUUID(), name))`.
  `FakePlayer.openMenu` is a no-op: build the menu and set `player.containerMenu` yourself.
- Packets: call the server handler with the FakePlayer as sender; test the reject paths
  (menu not open, too far away, locked milestone), not only the happy path.
- Test-only hooks (e.g. `CustomRecipeManager.putRecipeForTesting`) stay small and clearly named.
- A new template: build it in a dev world, save it with a structure block or `/test export`,
  commit the `.nbt` under `data/arffornia/structure/`. Prefer reusing `platform`.

## Run

```bash
./gradlew runGameTestServer --no-daemon -Dorg.gradle.jvmargs=-Xmx2g
```
One Gradle build at a time on the small machine. Success ends with
`All N required tests passed :)` and exit 0.

## Read a failure

- Summary line: `1 required tests failed: <testname>`; above it, the assertion message and the
  block position. The task exits 1.
- `Timed out`: the condition never became true. Check the tick budget and that the block entity
  actually ticks (both blocks of two-block machines placed?).
- An exception/crash in a test is a real bug more often than a test bug: reproduce it, fix the
  code in its own commit, keep the test.
- Harmless noise: recipes of absent optional mods failing to parse, `api.minecraftservices.com`
  unreachable offline.
- **Prove the test bites:** break the guarded code locally, confirm the test fails, restore. Put
  that negative check in the PR's "How it was tested".
