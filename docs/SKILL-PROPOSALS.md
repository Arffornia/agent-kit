# Skill proposals (first batch, 2026-10-31)

"Done twice -> skill": each row was done by hand at least twice in the Arffornia takeover. Status
`proposed` = spec only; an agent drafts the skill with the playbook's `propose-skill` once Brian
keeps the row. Generic candidates are also listed in the playbook
(`skills/propose-skill/references/candidates.md`).

| Skill | Layer | Seen | What it would do | Value |
|---|---|---|---|---|
| `keycloak-theme` | org (generic later) | theme repo foundation; login page wishes (animations, branding) | Build and preview the Keycloakify theme locally, screenshot every login page in light and dark, check i18n keys, ship the jar to the realm | High: Brian wants a much better login experience |
| `keycloak-ops` | org | proxy service-account secret, OAuth state bug, realm settings | Realm as code: clients, redirect URIs, passkeys/WebAuthn, Google login, brute-force and session settings; export and diff the realm; rotation guide | High |
| `mod-compat-check` | org | modpack changes, client/server side splits, duplicate entries | Before adding or updating a mod: side, loader and MC version, licence, known incompatibilities, CurseForge vs Modrinth source, RAM impact on the 330-mod pack | High |
| `playtest-kit` | org | manual in-game checks asked of Brian | One command to start server + client on a PR (single mod cheap; full pack one at a time), plus a test guide: what changed, what to look at, what to report | Very high (tech-watch card 01, proposal 3) |
| `mc-preview` | org | client harness spec, loading-screen renders | Headless client screenshots and a contact sheet of every changed screen for the review page | Medium |
| `pr-via-rest` | base | every session (GraphQL blocked) | Commit, push, open, label, draft/ready through REST and the CCR routes | Medium (saves turns everywhere) |
| `trusted-publishing` | base | Nexus_Java, Nexus_Logger, Nexus_Saver | Move a publish workflow to OIDC trusted publishing and write the registry steps for the owner | Medium |
| `stale-pr-salvage` | base | 4 stale PRs at cleanup | Read an obsolete PR, extract the good ideas into a fresh issue, close the PR with a link | Medium |
| `secret-rotation-guide` | base | proxy secret, npm token | Owner-facing step-by-step to rotate a leaked credential, with checks after | Medium |
