# Arffornia ecosystem map

Docs site: https://arffornia.github.io/docs/ (source: https://github.com/Arffornia/docs,
architecture model in `architecture/arffornia/`, specs in `docs/specs/`, ADRs in `docs/decisions/`).

| Component | Repo | Stack | Runs on | Start reading |
|---|---|---|---|---|
| Website + central API | https://github.com/Arffornia/Arffornia_Website | Laravel 12, PHP ^8.2, Vite, Postgres, Sanctum | cluster (nginx + php-fpm) | `routes/web.php`, `routes/api.php`, `app/Http/Controllers/`, `app/Services/UserService.php` |
| Launcher | https://github.com/Arffornia/Arffornia_Launcher_V.5.2 | Electron, electron-vite, Vue 3, Pinia, vue-i18n | players' PCs | `src/main/` (IPC handlers, `minecraftManager.js`, `msAuthManager.js`), `src/preload/`, `src/renderer/src/` |
| Mod | https://github.com/Arffornia/Arffornia_Mods | NeoForge 1.21.1, ModDevGradle, Java 21 | server and clients | `src/main/java/fr/thegostsniperfr/arffornia/` (`network/`, `block/entity/`, `api/`, `gametest/`) |
| Proxy plugin | https://github.com/Arffornia/Arffornia_Proxy | Velocity, Java 17 | proxy pod | `ApiService.java` (votes → website) |
| Modpack + provisioning | https://github.com/Arffornia/Arffornia_Provisioning | TypeScript, Docker, `@arffornia/nexus_mods` | init containers; `main` is live | `config/{launcher,server,proxy}/modList.json`, `src/` |
| Nexus libraries | https://github.com/Arffornia/Nexus_Mods, Nexus_Java, Nexus_Logger, Nexus_Saver | TypeScript / Java | launcher, config-updater | improved, never replaced (ADR-0003) |
| Infrastructure | https://github.com/TheGostsniperfr/infra | Kubernetes, Kustomize, Argo CD, Vault | homelab | `k8s/config/arffornia/`, `k8s/apps/arffornia/` |
| Agent harness | https://github.com/Arffornia/agent-kit | Claude Code plugin | every repo | `SKILLS.md`, `plugins/arffornia/` |

## A player's path

1. Installs the launcher, signs in with Microsoft (`msAuthManager.js`, msmc).
2. The launcher reads the modpack manifest from Provisioning `main` and downloads mods with
   Nexus_Mods, installs Java 21 and NeoForge, starts the game (MCLC).
3. The client connects to the Velocity proxy (Arffornia_Proxy plugin), forwarded to the
   NeoForge server running the `arffornia` mod and ~330 other mods.
4. The mod authenticates to the website API with a service account (`POST /api/auth/token/svc`)
   and reads/writes progression (milestones, stages, recipes, rewards).
5. On the website, the player sees the progression graph, the shop and votes (Microsoft OAuth
   login via `minecraft-oauth`). Votes arrive through NuVotifier on the proxy.

## Roles

- **Mod developer**: the mod + specs 001-003 (recipes, machine framework, tiers), GameTests.
- **Web developer**: the website, its Feature tests and Playwright e2e.
- **Launcher developer**: Electron security (IPC, tokens), Playwright-Electron.
- **Infra**: the infra repo, Argo CD, the docs' Noodle model.
- **Translator**: `en`/`fr` files in the launcher (`src/renderer/src/i18n/locales/`), website
  (`lang/`), mod (`assets/arffornia/lang/`).
