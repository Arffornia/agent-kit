# Machine framework (spec 002) - class map

Source: https://arffornia.github.io/docs/specs/002-machine-framework/ (docs repo
`docs/specs/002-machine-framework.md`). Status at writing: **Draft, needs decisions D1-D7**.
Re-read the spec before using this map; it wins over this file.

Package `fr.thegostsniperfr.arffornia.machine`:

| Class | Role |
|---|---|
| `MachineType` (record) | id, `SlotLayout`, `EnergySpec`, `TankSpec`s, recipe machine id, `SideConfigDefaults`, `MultiblockDef?`, sounds, GUI layout id, tier |
| `MachineTypes` | `DeferredRegister` helper: block, item, BE type and menu type from one `MachineType` |
| `MachineBlock` / `MachineBlockEntity` | facing + `ACTIVE`; BE owns the parts and ticks `RecipeProcessor` server side only |
| `SlotLayout`, `MachineItemHandler` | slot roles `INPUT/OUTPUT/CATALYST/UPGRADE/FLUID_ITEM`, role-filtered views |
| `MachineEnergyStorage`, `MachineFluidTanks` | clamped FE storage, role tanks |
| `SideConfig` | face x resource → `NONE/IN/OUT/BOTH`, relative to facing |
| `RecipeProcessor` | `IDLE → CHECK → RUNNING → OUTPUT_BLOCKED`; owner-team stage check at start; consumes inputs at start, energy per tick, outputs at end; pauses without power |
| `MachineData`, `MachineMenu`, `MachineScreen` | synced progress/energy/status; menu validates `stillValid` and distance; screen from a `GuiLayout` JSON |
| `ServerboundSelectRecipe` | validated: open menu, distance, recipe exists for this machine, stage unlocked |

Capabilities: registered once for all machine BEs in `RegisterCapabilitiesEvent`, each
returning a `SideConfig`-filtered view per face (cached).

Multiblocks: `MultiblockDef` (template `data/arffornia/structure/multiblock/<id>.nbt`,
controller offset, IO ports), formed with the Wrench (4 rotations x mirror), parts are
`MultiblockPartBlock` with a master offset, master renders one baked model, breaking any part
restores original blocks. Blueprint item shows a hologram.

Work order (spec 002 work breakdown): MachineType/registry → slots/energy/fluids → SideConfig
+ capabilities → RecipeProcessor → menu/data/select payload → GUI kit → port Crafter → datagen
+ completeness check → `machine_stats` data map → multiblock core → rendering + Blueprint →
Foundry → Jade provider.

Tier content (which machine at which tier, parts, power): spec 003, a **proposal**; numbers
are starting points for playtests and need Brian's approval.
