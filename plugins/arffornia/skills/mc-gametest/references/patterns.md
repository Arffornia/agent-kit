# GameTest patterns (Arffornia_Mods)

Helpers already in `ArfforniaGameTests.java`; reuse them rather than writing new ones:
`nextId()`, `fake()` (the `InMemoryProgressionBackend`), `player(helper, name, relativeVec)`,
`playerNearMachine(helper, name)`, `recipe(unlockId, milestoneId, energy, time)`,
`registerRecipe(r)`, `placeCrafter(helper, owner, progressionId)`, `placeElevator(...)`,
`placeTwoBlockMachine(helper, master, part)`, `openCrafter(player, be)`, `openElevator(...)`,
`milestone(id, amount)`.

## Players and menus

- `FakePlayerFactory.get(level, new GameProfile(UUID.randomUUID(), name))`, positioned with
  `helper.absoluteVec(...)`. A random UUID per test: tests in a batch run in parallel.
- `FakePlayer.openMenu` is a no-op: build the menu and set `player.containerMenu = menu`
  (`openCrafter` does it). Without that, every "menu open" check rejects, which is what the
  `...RejectedWithoutOpenMenu` tests rely on.
- "Too far": place the player 40 blocks away (`new Vec3(2.5, 1, 40.5)`); the server checks
  use `ServerPayloadChecks.MAX_INTERACTION_DISTANCE` (8 blocks from the block centre) and `menu.stillValid`.

## Packets and async backends

Handlers that call the progression backend return a `CompletableFuture` completing on the
server thread (`processOnServer`). Collect results and assert in `succeedWhen` or after a
delay, never `join()` on the server thread (deadlock):

```java
List<Boolean> results = new CopyOnWriteArrayList<>();
ServerboundSelectRecipePacket.processOnServer(player, new ServerboundSelectRecipePacket(be.getBlockPos(), id))
        .thenAccept(results::add);
helper.runAfterDelay(20, () -> {
    helper.assertTrue(results.equals(List.of(false)), "Expected rejection, got " + results);
    helper.assertTrue(be.getSelectedRecipeMilestoneUnlockId() == null, "Nothing should be selected");
    helper.succeed();
});
```

Every serverbound packet gets at least: accepted when valid, rejected without the open menu,
rejected from far away, rejected when the stage is locked, and (for side effects such as the
Space Elevator) "a failure refunds".

## Energy, inventories, ticking

- Energy: set it through the block entity's storage, not by ticking a generator.
- Two-block machines: place both blocks (`placeTwoBlockMachine`) or the master never ticks.
- Save/load: `be.saveWithFullMetadata(registries)` then `loadWithComponents` into a fresh BE,
  compare fields (see `crafterKeepsStateAcrossSaveAndLoad`).
- Output full: fill the output slot first and assert inputs are not consumed.

## Machine framework (spec 002, when it lands)

One shared test class per machine kind, parameterised by `MachineType`: crafts with energy,
pauses without energy (progress kept), output blocked, side config respected (hopper
insertion only into input faces), select-recipe validation, save/load. Multiblocks: forms in
all 4 rotations x mirror, fails with the first wrong position, breaking a part restores the
original blocks and drops the inventory.

## New templates

Build in a dev world (`make run-client`), save with a structure block or `/test export`,
commit the `.nbt` under `data/arffornia/structure/`. Prefer `platform`; a template is a binary
file a reviewer cannot read, so say in the PR what it contains.
