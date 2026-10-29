# Machine checklist on today's code (before spec 002 lands)

Model: the Crafter. Paths under `src/main/java/fr/thegostsniperfr/arffornia/`.

| # | Piece | Where (Crafter example) | Must |
|---|---|---|---|
| 1 | Block | `block/crafterblock/CrafterBlock.java` (+ `CrafterPartBlock` for the top) | facing, drops contents, part block removed with the master |
| 2 | Registration | `block/ModBlocks.java`, `item/ModItems.java`, `creative/ModCreativeTabs.java` | block item, creative tab |
| 3 | Block entity | `block/entity/CrafterBlockEntity.java`, `block/entity/ModBlockEntities.java` | ticks on the server only; `setChanged` on state change; save/load all state |
| 4 | Inventory | `ItemStackHandler` in the BE | input/output roles enforced in `isItemValid`; outputs not insertable |
| 5 | Energy | FE `EnergyStorage` | clamped, max input per tick, pause (not reset) without power |
| 6 | Capabilities | `compat/CapabilityRegistration.java` | item and energy capabilities; output-only faces extract only |
| 7 | Menu | `screen/CrafterMenu.java`, `screen/ModMenuTypes.java` | `stillValid` + distance; quick-move by role; `ContainerData` for progress/energy |
| 8 | Screen | `client/screen/CrafterScreen.java`, `ArfforniaClient.onRegisterMenuScreens` | every string a lang key; sizes from `font.width`; readable at GUI scale 2-4 |
| 9 | Packets | `network/PacketHandler.java` (`playToServer`), `network/ServerboundSelectRecipePacket.java` | validate on the server thread: menu open, `ServerPayloadChecks.isInteractingWith` (distance ≤ 8), owner's stage unlocked, ids exist; re-check after async futures |
| 10 | Recipes | today fetched from the website (`recipe/CustomRecipeManager`); spec 001 moves them to datapacks | follow the current issue's decision |
| 11 | JEI | `compat/jei/CrafterRecipeCategory.java`, `CrafterRecipeTransferHandler.java` | transfer checks the same inventory range it consumes |
| 12 | Assets | `assets/arffornia/{blockstates,models,textures}`, `data/arffornia/{loot_table,recipe}` | blockstate, models, loot table, crafting recipe |
| 13 | Lang | `assets/arffornia/lang/en_us.json`, `fr_fr.json` | `block.arffornia.<id>`, `gui.arffornia.<id>.*`, parity |
| 14 | GameTests | `gametest/ArfforniaGameTests.java` | crafts with energy, stalls without, output full, save/load, packet reject paths, removing the block removes the part |

Classes of bugs to avoid: packets trusted without server-side checks, energy cost rounding,
null item ids in ingredients, JEI transfer reading a different inventory range than it consumes.
