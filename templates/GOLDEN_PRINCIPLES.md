# Golden principles

Mechanical, opinionated rules for every change in Arffornia. They are not style advice: each one
is checkable, and each one that agents break twice gets a sensor (lint rule, guard hook, CI check)
so it cannot be broken a third time. Add a rule here when it is about to become a sensor.

| # | Rule | Why | Sensor (now or planned) |
|---|---|---|---|
| 1 | **Validate at the boundary.** Every input that crosses a trust boundary (HTTP request, IPC message, C2S packet, file from the network, index.json entry) is validated for type, range and allowed values before use. Paths are resolved and must stay under their base dir. | Inputs are the attack surface; downstream code assumes clean data. | FormRequests / IPC schemas; tests with hostile input |
| 2 | **Every network call has a timeout** (connect and total), checks the status, and retries only a bounded number of times with backoff. | One slow dependency must not hang a server thread, a launcher, or an init container. | Review checklist; grep CI guard for `newHttpClient()` / `axios(` without timeout |
| 3 | **Downloads go temp file → verify hash → rename.** A partial or unverified file is never used and never reused. | Corrupt installs that never self-heal; supply-chain integrity. | Unit tests per downloader |
| 4 | **No user-visible literal strings.** Player and user text goes through i18n with `en` and `fr` keys. | French and English players; consistency. | `/arffornia:i18n-sync`; lint rules where the stack has one |
| 5 | **Owner's libraries are improved, never replaced.** Nexus_Java, Nexus_Logger, Nexus_Saver, Nexus_Mods and launcher modules get fixes upstream. | They are the product's foundation and the maintainer's design. | Review; dependency diff in the in-session review |
| 6 | **No secrets in git, logs or prompts.** Placeholders (`${CFG_*}`, `.env.example`) only; tokens are redacted before logging. | Public repos; logs get pasted into Discord. | gitleaks in CI, guard hook, deny rules |
| 7 | **The default branch changes only through a reviewed PR.** No force-push, no direct push, no merge by an agent. | One maintainer reviews everything; history is the audit trail. | Guard hook, deny rules, branch protection |
| 8 | **Generated files are generated.** Lockfiles, datagen output, diagram exports and indexes are rebuilt by their command, never edited by hand. | Hand edits drift and get overwritten. | Guard hook |
| 9 | **Verify, don't claim.** "Done" means `make check` passed on the final tree and the PR shows the output; a behaviour change has a test that fails without it. A non-trivial change has an independent in-session review with no open blocking finding. | Self-reported success is the most common agent failure; the author cannot grade its own work. | Stop hook: `make check` gate, then the review gate (`/arffornia:review`, stamp per tree); CI `make check` |
| 10 | **Pin what you run.** Images, charts, actions, remote config and dependencies are pinned to a version or digest, not `latest`, `main` or `-SNAPSHOT`. | Reproducible builds; a push elsewhere must not change production. | Dependabot; CI guard on manifests |
| 11 | **Never block a game, proxy or UI thread on I/O.** | A slow API must not freeze the server tick or the launcher window. | GameTests; review |
| 12 | **One concern per PR, linked to its issue, with What / Why / How tested / Risk & revert.** | Small PRs get reviewed; reverts stay clean. | PR template; in-session review |
| 13 | **Decisions belong to the maintainer.** Irreversible or unsettled design choices become a `needs-decision` question, not an implementation. | Solo maintainer, long-lived design. | work-ticket skill; review |
| 14 | **Reporting: links, not claims.** Every PR, issue, commit, artifact or page mentioned to a human is a full clickable URL with a one-line summary, grouped and ordered by what the human should do (review/merge, decide, FYI). Never "I opened the PR" without the link. | The maintainer acts from the report; a missing link is a search. | Reviewer and report templates; evals |
| 15 | **State lives in the repo.** Unfinished work leaves PROGRESS.md (and an exec plan for multi-session work) current. | The next session, human or agent, starts from the file, not from memory. | PreCompact/SessionEnd hooks, Stop reminder |
| 16 | **Every friction is a harness issue.** A user correction, a guard that fires twice, a misfiring skill or a better way found becomes an `harness-feedback` issue in agent-kit with evidence and a proposed patch; the same lesson is never re-learned by hand. | The harness, not the model, makes the quality; it only improves if its failures are written down. | `prompt-signals.sh` and the guard's repeated-block hint; weekly `harness-feedback` automation turns issues into a PR |
