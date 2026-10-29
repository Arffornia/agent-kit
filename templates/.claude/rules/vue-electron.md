---
paths:
  - "src/main/**"
  - "src/preload/**"
  - "src/renderer/**"
  - "electron.vite.config.*"
  - "package.json"
---

# Electron + Vue 3 conventions (Arffornia launcher)

- **Process boundary**: the renderer never imports from `src/main/**`. Shared constants go in a
  module both sides import (`src/shared/`), or come over IPC. The preload exposes one typed
  `window.api`; do not expose `ipcRenderer` or `@electron-toolkit` `electronAPI`.
- **IPC handlers**: `ipcMain.handle(channel, (event, ...args) => …)`: the first argument is the
  event (forgetting it is a real bug here: `logger`, `set-lang`). Validate every argument and
  `event.senderFrame.url`. Subscriptions exposed by the preload return an unsubscribe function.
- **Security defaults** stay on: `contextIsolation: true`, `sandbox: true`, no `webSecurity: false`,
  no `v-html` with remote data, `shell.openExternal` only for `https:` URLs on an allow-list.
- **Paths**: game, Java and settings dirs come from `app.getPath('userData')`, never `./` (the CWD
  can be `Program Files` or `System32`).
- **Downloads**: verify the published hash (sha1/sha256/sha512), write to `<file>.part`, then
  rename. A partial file is never reused. Every request has a timeout.
- **Secrets**: refresh tokens go through `safeStorage`; logs never contain access tokens
  (MCLC `debug` lines carry `--accessToken`: redact before logging).
- **Async**: `await` every auth and launch promise; a Promise is never `null`.
- **Strings**: every user-visible string is a vue-i18n key in both `en` and `fr`, including
  notifications and button states (`Play`/`Running...`). Run `/arffornia:i18n-sync` after edits.
- **Libraries**: Nexus_Java, Nexus_Logger, Nexus_Saver, Nexus_Mods are the owner's: fix them
  upstream (PR to the lib), never replace them with another package.
- Lint is ESLint 9 flat config (`eslint.config.mjs`); format with Prettier (`make fmt`).
  `npm run lint` must not `--fix` in CI.
