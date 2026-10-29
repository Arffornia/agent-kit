---
name: threat-model
description: "STRIDE threat model of a new or changed attack surface in Arffornia: serverbound packets, Electron IPC, HTTP endpoints and webhooks, downloads and manifests, CI workflows, scheduled agents (lethal trifecta check). Produces threats, mitigations and the tests that prove them. Use before building or reviewing anything that accepts input from players, clients, the network or PR content."
argument-hint: "<surface: packet, IPC channel, endpoint, download, workflow, agent>"
---

# Threat model a surface

Surface: `$ARGUMENTS`. Do it before the code is written when possible, and again in review.
Repos are public: write the model in the PR or a private note, and for an exploitable
weakness that is not fixed yet use a neutral issue title with no reproduction steps.

## 1. Describe the surface

- **Entry point**: the exact handler (`path:line`): packet record + `handle`, `ipcMain.handle`
  channel, route + controller, downloader, workflow trigger, agent prompt.
- **Caller and trust**: who can reach it (any client on the server, the renderer with any
  page loaded, the internet, a PR from a fork, a scheduled job) and with which identity.
- **Assets**: what an attacker wants (progression, rewards, shop balance, the MS refresh
  token, the service-account secret, files on the player's PC, the release pipeline).
- **Data flow**: input → validation → effect, as a 4-8 step list or a mermaid sequence.

## 2. STRIDE, per step

For each step ask the six questions and keep only threats that apply, each with likelihood
(low/medium/high) and impact. Arffornia-specific prompts per surface type:
[references/surfaces.md](references/surfaces.md).

| | Ask |
|---|---|
| **S**poofing | Can the caller pretend to be another player, the server, the website, the launcher? |
| **T**ampering | Can it change ids, positions, amounts, paths, URLs, manifests, hashes in flight or at rest? |
| **R**epudiation | Will we know who did it (server log with player UUID, audit table) without logging secrets? |
| **I**nformation disclosure | Can it read tokens, env, other players' data, stack traces, file contents? |
| **D**enial of service | Can it flood (packets per tick, token minting, retries), block the server thread, fill disk? |
| **E**levation of privilege | Can it reach admin actions, run code (IPC → shell, path traversal → write, workflow → secrets)? |

## 3. Lethal trifecta (agents and automations)

If the surface is an agent or automation: does one agent combine **private data** (tokens,
private repos, player data) **+ untrusted content** (issues, PR bodies, web pages, mod
changelogs) **+ an external output channel** (comments, pushes, HTTP)? All three = redesign:
split the agent or remove one leg. Write the card: data / untrusted input / outputs / verdict.

## 4. Mitigations and proof

Each kept threat gets a mitigation in the code (server-side validation, allow-list, auth,
rate limit, `safeStorage`, hash check, atomic write, minimal `permissions:`) and a **test that
proves it** (a GameTest reject path, a Playwright-Electron hostile IPC call, a Feature test
for 401/403/429, a workflow lint). Unmitigated threats are listed with the reason and an issue.

Output shape: [references/output.md](references/output.md). Report per
[references/reporting.md](references/reporting.md).
