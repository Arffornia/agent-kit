---
paths:
  - "src/main/java/**/*.java"
  - "src/test/java/**/*.java"
  - "src/main/resources/**"
  - "build.gradle"
  - "gradle.properties"
---

# NeoForge 1.21.1 / Java 21 conventions (Arffornia_Mods)

- **Threads**: never block the server or render thread on I/O. No `.join()`/`.get()` on a
  `CompletableFuture` in event handlers, ticks or menus; hop back with `server.execute(...)` /
  `Minecraft.getInstance().execute(...)` before touching world or GUI state.
- **HTTP** goes through the one API service: `HttpClient` built with `connectTimeout`, each
  `HttpRequest` with `.timeout(...)`, status checked before Gson parsing, one re-auth on 401.
- **Server authority**: every C2S payload handler re-checks distance (`player.distanceToSqr`),
  open menu, ownership and unlock state on the server. The client only displays.
- **Registration** through `DeferredRegister` on the mod event bus; recipes, loot and tags you own
  come from **datagen** (`make data` → `src/generated/resources`, never edited by hand).
- **Recipes**: real `RecipeType` + `RecipeSerializer` with `MapCodec`/`StreamCodec`;
  `SizedIngredient` keeps tags and counts. Do not flatten ingredients to `items[0]`.
- **Energy/time math**: use ceilings (`Mth.ceil`) so a recipe never costs 0 FE per tick.
- **Capabilities**: registered in `RegisterCapabilitiesEvent`; multiblock parts forward the
  master's capabilities.
- **Strings**: player-facing text is `Component.translatable("arffornia.…")` with keys in
  `assets/arffornia/lang/en_us.json` and `fr_fr.json`. No `Component.literal` for UI text.
- **Logging**: the mod logger (`LogUtils.getLogger()`), never `System.out`; no tokens in logs.
- **Tests**: JUnit for pure logic; GameTests (`@GameTestHolder("arffornia")`, `make gametest`) for
  anything touching blocks, menus or the server. See `/arffornia:mc-gametest`.
- Builds: `--no-daemon -Dorg.gradle.jvmargs=-Xmx2g`, one Gradle build at a time.
