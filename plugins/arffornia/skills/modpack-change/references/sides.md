# Client, server or both

| The mod... | Side | Examples |
|---|---|---|
| adds blocks, items, entities, fluids, recipes, dimensions, worldgen, menus | both, same file id | AE2, Create, Mekanism, KubeJS |
| is a library another both-sided mod needs | both | Architectury API, FTB Library, GuideME |
| only renders, adds HUD, minimap, shaders, sounds, input tweaks, rich presence | launcher only | Iris/Oculus, Xaero's Minimap, JEI client add-ons, Simple Discord Rich Presence |
| only runs server logic: admin, backups, performance, chunk pregen, forwarding | server only | NeoForwarding, FTB Essentials (server), Spark |
| is a Velocity plugin | proxy only | LuckPerms (Velocity), NuVotifier |

Check, in order:
1. Modrinth `client_side` / `server_side` (printed by `modpack.py resolve modrinth`):
   `required` on both = both; `unsupported` on one side = the other only.
2. The mod's page or README ("client-side only", "server-side only", "required on both").
3. Its `neoforge.mods.toml`: `displayTest = "IGNORE_SERVER_VERSION"` means it does not need
   to be on the server; `side = "CLIENT"` on dependencies.
4. In doubt: both. A client-only mod on a dedicated server usually crashes it at start
   (classes from `net.minecraft.client`), and a missing both-sided mod on the client makes
   joining fail with a registry mismatch.

Upgrades: the same file id on both sides. `modpack.py dupes` reports a `MISMATCH` when the
launcher and server list different files for one CurseForge project.
