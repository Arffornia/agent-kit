# Ecosystems in Arffornia

| Repo | Ecosystem | List outdated | Upgrade one |
|---|---|---|---|
| Arffornia_Website | Composer (PHP 8.3) | `composer outdated --direct --format=json` | `composer require vendor/pkg:^X.Y -W` |
| Arffornia_Website | npm (Vite assets) | `npm outdated --json` | `npm install pkg@X.Y.Z` |
| Arffornia_Launcher_V.5.2 | npm (Electron, Vue) | `npm outdated --json` | `npm install pkg@X.Y.Z` (exact for electron) |
| Nexus_Mods / Nexus_Saver / Nexus_Logger | npm (TypeScript) | `npm outdated --json` | same; then bump the dependent repo in its own PR |
| Arffornia_Mods | Gradle (NeoForge 1.21.1, Java 21) | `gradle.properties` versions vs the NeoForge / mod maven metadata | edit `gradle.properties`, `./gradlew --no-daemon -Dorg.gradle.jvmargs=-Xmx2g build` |
| Arffornia_Proxy, Nexus_Java | Gradle (Java 17/21) | dependencies block vs Maven Central | edit `build.gradle` |
| all | GitHub Actions | `grep -rn 'uses:' .github/workflows` vs latest majors | edit the `uses:` ref (pin by SHA for release workflows) |
| infra | Helm charts, images | chart `version:` vs repo index | edit `Chart.yaml` / `kustomization.yaml`; `kustomize build --enable-helm` |

## Care points

- **NeoForge**: stay on 1.21.1; a NeoForge patch bump can break mods in the pack. Test with
  `runGameTestServer` and, when possible, a server boot with the full modpack.
- **Electron**: majors change Chromium and Node; check `contextIsolation`/sandbox defaults,
  `electron-updater` compatibility, and run the Playwright-Electron smoke.
- **Laravel**: follow the upgrade guide; `php artisan test` + Playwright; check config files
  that changed upstream (`config/*.php`).
- **minecraft-launcher-core (MCLC)**: re-check that launch arguments with tokens are still
  redacted from logs.
- **Nexus_\***: the owner's libraries. Upgrade within them and in their callers; never swap
  for a third-party package.
- Security advisories first (`npm audit --omit=dev`, `composer audit`, Dependabot alerts).
