---
name: onboard
description: "Give a newcomer (human or agent) a guided tour of Arffornia or of one repo: what each part does, how a player action flows through the system, how to get a clone green, the rules that matter, and a good first issue. Use when someone is new, asks where to start, how the project fits together, or how to set up a repo."
argument-hint: "[repo | 'ecosystem'] [role: dev|mod|web|infra|translator]"
---

# Onboarding tour

Who and where: `$ARGUMENTS` (default: the current repo, a developer). A tour is a
conversation, not a wall of text: give one stop at a time, check what they want next, and
let them run things themselves. Facts come from the repos and the docs site; when the docs
and the code disagree, say so and show the code.

## The stops

1. **The 2-minute picture.** What Arffornia is (a modded NeoForge 1.21.1 server with its own
   website, launcher and progression system) and the map of repos:
   [references/ecosystem.md](references/ecosystem.md). Link the docs site
   https://arffornia.github.io/docs/ and its architecture diagrams.
2. **One player action, end to end.** Pick the one closest to their role and trace it with
   real file links (a player logs in on the launcher → downloads the modpack → joins via
   Velocity → completes a milestone → the website records it). Paths in the ecosystem file.
3. **This repo.** Read its `AGENTS.md` (the map), `README.md`, `Makefile`; show the 5-8 files
   that matter most and why. Mention `PROGRESS.md` and `docs/exec-plans/active/` if present.
4. **Get it green.** Run the setup in order and stop at the first failure to fix it together:
   the repo's `init` script if it has one, else `make install` / `make check`. Note the small
   machine rule for Gradle (`--no-daemon -Dorg.gradle.jvmargs=-Xmx2g`, one build at a time).
5. **The rules that matter.** English in code and docs; player text through i18n with `en`
   and `fr`; never replace the owner's Nexus_* libraries; agents never merge, tag, release or
   push to the default branch; decisions belong to Brian (`needs-decision`); security issues
   use neutral titles. One line each, with where it is enforced (hook, CI, review).
6. **How work flows.** Issue (labels `type/area/priority/effort`, `agent-ready`) → branch
   `<type>/<n>-slug` → tests → `make check` → review → draft PR → Brian merges.
7. **A first issue.** Find 1-3 open issues labelled `good first issue` or `agent-ready` with
   `effort: S` in this repo (`gh api 'repos/Arffornia/<repo>/issues?state=open&per_page=100'`)
   and explain what each needs.

## Finish

Ask what was unclear. Anything a newcomer had to ask that the repo does not answer is a
docs gap: propose the one-line fix to `AGENTS.md` or the README (do not commit it unasked).
Links follow [references/reporting.md](references/reporting.md).
