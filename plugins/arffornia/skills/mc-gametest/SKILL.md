---
name: mc-gametest
description: "Write, run and debug NeoForge 1.21.1 GameTests in Arffornia_Mods (platform template, @GameTestHolder, fake progression backend, runGameTestServer, reading failures). Use when adding a test for a block, block entity, menu, packet handler, machine or progression rule, or when runGameTestServer fails."
paths:
  - "**/gametest/**"
  - "**/build.gradle"
  - "**/network/**"
  - "**/block/entity/**"
---

# NeoForge GameTests in Arffornia_Mods

GameTests run a headless dedicated server, place a structure template, run code tick by tick
and fail the build when a required test fails. Use them for what a unit test cannot reach:
block entities, menus, packets, the progression backend. The suite is
`src/main/java/.../gametest/ArfforniaGameTests.java` (introduced by Arffornia_Mods PR #48):
read it first and follow its helpers.

## How the suite is wired

- `build.gradle`, run `gameTestServer`: `neoforge.enabledGameTestNamespaces = mod_id` (only
  `arffornia` tests register) and `arffornia.backend = fake` (`InMemoryProgressionBackend`,
  never the website).
- FTB Teams needs FTB Library at runtime (`localRuntime`), or no dev run starts.
- Template `data/arffornia/structure/platform.nbt`: 5x4x5, stone floor at y=0; machines at
  `new BlockPos(2, 1, 2)`. `@GameTestHolder(Arffornia.MODID)` + `@PrefixGameTestTemplate(false)`
  so `template = "platform"` resolves.
- CI: `.github/workflows/gametest.yml` runs it on every PR.

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

- Method name = test id; name the behaviour (`selectRecipeRejectedForLockedMilestone`).
- Positive tests end with `helper.succeedWhen(() -> assert…)`; negative tests ("nothing
  happens") wait with `runAfterDelay(n, …)` then `succeed()`.
- Every assertion message carries the actual value. Relative positions only
  (`helper.absolutePos`).
- Packets: call the server handler (`processOnServer`) with a FakePlayer and test the reject
  paths (menu not open, too far, locked stage), not only the happy path.

More patterns (fake players and menus, async backend futures, energy, two-block machines,
new templates): [references/patterns.md](references/patterns.md).

## Run

```bash
${CLAUDE_SKILL_DIR}/scripts/run_gametests.sh        # caps: --no-daemon, -Xmx2g, one build at a time
```
Success ends with `All N required tests passed :)` and exit 0. The script prints the verdict
and the failure lines; the full log is `build/gametest-run.log`.

## Read a failure

Summary `1 required tests failed: <name>`, the assertion message and block position above it.
`Timed out`: the condition never became true (tick budget, block entity not ticking). An
exception in a test is a real bug more often than a test bug: reproduce, fix in its own
commit, keep the test. Details and known noise: [references/failures.md](references/failures.md).

**Prove the test bites:** break the guarded code locally, see the test fail, restore. Put
that in the PR's "How it was tested". Report per [references/reporting.md](references/reporting.md).
