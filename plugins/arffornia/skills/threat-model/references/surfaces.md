# Surface prompts

Guidance distilled from the Arffornia audits. Specific findings live in the private audit
reports and in neutral issues; do not restate them in public files.

## Serverbound packets (Arffornia_Mods)
- The client is hostile: any field can be any value. Validate on the server thread:
  the player has the matching menu open (`player.containerMenu instanceof X && menu.stillValid`),
  distance to the claimed `BlockPos` ≤ `ServerPayloadChecks.MAX_INTERACTION_DISTANCE`, the
  block entity at that position is the one the menu is bound to, the stage/milestone is
  unlocked for the **owner's** progression, ids exist.
- Every serverbound packet that changes a block entity gets the same checks, including ones
  that look harmless (recipe selection, launch buttons, mode toggles).
- DoS: a packet that triggers an HTTP call or a DB write per receipt; rate-limit or debounce.
- Async: re-check the conditions after a backend future completes (menu may be closed).

## Electron IPC (Arffornia_Launcher_V.5.2)
- The renderer is untrusted (XSS, a compromised remote page). Every `ipcMain.handle` validates
  argument types, checks `event.senderFrame.url` origin, and exposes intent-level channels,
  never generic ones (a generic key/value read can hand any stored secret to the page).
- `shell.openExternal(url)` only for an `https:` allow-list. File names from the renderer:
  `path.basename`, reject `..`, resolve inside the target dir.
- Tokens: stored with `safeStorage` or the OS keychain, never in plain JSON, never readable
  through IPC; launch arguments and library debug output redacted before logging.

## HTTP endpoints (Arffornia_Website)
- AuthN (Sanctum: token expiry, which guard), AuthZ (policy per model, not just "logged in"),
  validation (FormRequest), rate limits on auth/token/reward endpoints, CSRF on web routes,
  mass assignment (`$fillable`), IDOR on ids in the URL.
- Secrets: `APP_DEBUG=false` and no debug error renderer (ignition) in production images;
  no tokens in logs.
- Service accounts (`auth/token/svc`): secret rotation, one token per service, scope by role.

## Downloads and manifests (launcher, Nexus_Mods, Provisioning)
- Provisioning `main` is live: who can change a manifest, and does the client verify a hash
  per file? HTTPS only, hash checked before use, written to a temp file then renamed, no
  path from the manifest outside the game dir.
- Auto-update: signed builds (`publisherName`, notarisation), otherwise anyone with repo write
  or the release PAT can ship code to every player.

## CI workflows and scheduled agents
- `pull_request_target` + checkout of PR code = secrets exposed. Minimal `permissions:`.
  Pin third-party actions by SHA for release workflows.
- Agents reading issues/PRs (untrusted) must not hold write tokens and a way to exfiltrate at
  once (lethal trifecta).
