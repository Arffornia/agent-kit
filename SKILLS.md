# Skills and subagents catalog

Plugin `arffornia` (marketplace `agent-kit`). Skills are invoked as `/arffornia:<name>`;
**auto** means Claude also loads the skill on its own when the task matches its description,
**manual** means only a human can start it (`disable-model-invocation: true`). **fork** skills
run in a fresh subagent and return one result. No skill depends on another; each folder is
self-contained (`SKILL.md`, `references/`, `scripts/`). Shared text lives once in
`plugins/arffornia/skills/_shared/` and is copied into each skill by `_shared/sync.sh`.

Every skill that reports work follows `references/reporting.md`: each PR, issue, commit, run
or page as a full URL with a one-line summary, grouped Decide / Review / Act / FYI / Not done.

## Skills

| Skill | When to use | Invocation | Side effects |
|---|---|---|---|
| `work-ticket` | Work an issue to a verified, committed branch; draft issues with the label taxonomy | auto | branch, commits (local); creates an issue only when the user approves the text; stops before push |
| `publish` | Run by agents at the end of a task (or by Brian): checks branch, secrets, `make check`, the end-of-task review stamp and evidence, then pushes and opens the PR. Never merges: only approved chantiers merge, through the merge plan | auto (side effect approved by Brian, 2026-10-31) | `git push` of the feature branch, opens the PR, adds labels |
| `review` | End-of-task review in the session (the Stop hook asks for it) or review of a PR, branch or diff: risk-routed `review-finder` subagents, `review-verifier` per candidate, confirmed findings only, stamp per tree, max 3 rounds | auto | in-session: writes the stamp and log under `.git/claude-harness/`; PR mode: none (comments only when asked) |
| `mc-gametest` | Write, run and debug NeoForge GameTests in Arffornia_Mods | auto (paths: gametest, network, block entities) | test files; runs Gradle (`scripts/run_gametests.sh`) |
| `modpack-change` | Add, upgrade or remove a mod in Arffornia_Provisioning | auto (paths: `config/*/modList.json`) | edits modList, `make indexes`; `scripts/modpack.py` is read-only |
| `i18n-sync` | Check and fix en/fr parity (launcher, website, mod) after text changes | auto | edits lang files; `scripts/i18n_parity.py` is read-only |
| `handoff` | Stop mid-task: update `PROGRESS.md` and the active exec plan | auto | edits and commits `PROGRESS.md` / plan (no push) |
| `exec-plan` | Multi-session work: write, update or close `docs/exec-plans/active/<slug>.md` + `tasks.json` | auto | edits and commits plan files |
| `debug` | Something breaks: prove the root cause, then fix with a regression test | auto | code and test edits after the cause is proven |
| `verify` | Prove behaviour on the real app: Playwright, Playwright-Electron, `runGameTestServer` | auto | build outputs and evidence under `build/verify/` |
| `explain` | How does X work: explainer with a mermaid/Noodle diagram and sources | auto, **fork** (Explore) | none |
| `challenge` | Critique a plan, spec, PR or decision: against, for, alternatives, pre-mortem, jury | auto | none |
| `cadrage` | Frame a vague idea by interview into `PROJECT.md` or a spec draft | auto | writes a draft file |
| `prio` | What to do next: impact x urgency / effort + unblock bonus across repos | auto, **fork** | none (never moves cards or labels) |
| `threat-model` | STRIDE on a new surface: packets, IPC, endpoints, downloads, workflows, agents | auto | none |
| `postmortem` | Blameless incident draft from git, PRs, CI runs and provided logs | auto, **fork** | writes `docs/postmortems/<date>-<slug>.md` draft |
| `release-notes` | Player-facing EN + FR notes from merged PRs since the last release | auto, **fork** | writes a draft under `build/release-notes/`; never tags or releases |
| `upgrade-deps` | Upgrade dependencies, one PR per dependency, changelog read, risk note | **manual** | branches, commits, `git push`, draft PRs |
| `onboard` | Guided tour for a newcomer: ecosystem, one player flow, get green, first issue | auto | none |
| `harness-audit` | Find skills/agents that are too long, contradictory, unused, stale or unsafe | auto, **fork** | none (proposes pruning) |
| `mc-machine` | Add a machine: spec 002 framework when it exists, else a checklist on today's code | auto (paths: machine, block entities, screens) | mod code, assets, lang, GameTests |
| `mc-ui-check` | Check mod screens EN/FR at GUI scales: raw keys, overflow risk, literals | auto (paths: screens, lang, gui textures) | none; `--pseudo` writes `build/ui-check/en_xx.json` |
| `harness-feedback` | The user corrected how the agent works, a guard fired twice, a skill misfired, friction or a better way: search, then append to or open a `harness-feedback` issue in agent-kit with evidence and a patch | auto (also hinted by hooks) | creates an issue or a comment in Arffornia/agent-kit; never edits the kit |
| `learning-card` | Something genuinely state of the art Brian would want to learn: a short tech-watch card | auto | writes one card where `~/agent-playbook/veille/README.md` says (else `veille/inbox/`); never commits |
| `noodle-arffornia` | Update `architecture/arffornia` in the docs repo: discover, drift, lint, headless export | auto (paths: `architecture/**`) | edits model/views/layouts, renders `docs/assets/diagrams/` |

## Subagents

| Agent | Model · effort | When to use | Tools | Notes |
|---|---|---|---|---|
| `arffornia:review-finder` | Opus · high | One finder lens of `/arffornia:review` (spawned by the skill) | Read, Glob, Grep, Bash; no Edit/Write/Agent | returns candidates tied to changed lines, with how to confirm |
| `arffornia:review-verifier` | Sonnet · high (a second one on Opus at high risk) | Proves or refutes one candidate (spawned by the skill) | Read, Glob, Grep, Bash; no Edit/Write/Agent | confirmed / refuted / unsure with evidence |
| `arffornia:reviewer` | Opus · high | Independent review of a PR on request | Read, Glob, Grep, Bash, Agent; no Edit/Write | preloads `arffornia:review`; spawns finders and verifiers |
| `arffornia:security-reviewer` | Opus · max | High-risk diffs, new surfaces, security review | Read, Glob, Grep, Bash; no Edit/Write/Agent | preloads `arffornia:threat-model`; trifecta check |
| `arffornia:test-writer` | Opus · high | Tests from acceptance criteria, independent of the implementation | Read, Glob, Grep, Bash, Write, Edit | `isolation: worktree` on the default branch: cannot see the implementation; writes only test paths |
| `arffornia:verifier` | Sonnet · high | Run the real thing and return PASS/FAIL/NOT RUN with evidence | Read, Glob, Grep, Bash; no Edit/Write/Agent | preloads `arffornia:verify`; must not change tracked files |
| `arffornia:doc-gardener` | Sonnet · high | Docs that no longer match code; scheduled gardening | Read, Glob, Grep, Bash; no Edit/Write/Agent | proposes exact replacement text |
| `arffornia:fact-finder` | Sonnet · high | Sourced YAML inventory for a Noodle diagram or a cross-repo explainer | Read, Glob, Grep, Bash; no Edit/Write/Agent | Noodle `v1alpha1` vocabulary, `src` + `how` on every fact |

Why each model: agent-kit [docs/MODELS.md](docs/MODELS.md) (benchmarks, prices, cost per review).

Plugin agents ignore `hooks`, `mcpServers` and `permissionMode`; Bash cannot be narrowed per
command in an agent file, so "read-only" agents state their Bash limits in the prompt and rely
on the repo's `permissions.deny` for hard blocks. Preload skills by their scoped name
(`arffornia:review`): Claude Code bundles `/review` and `/verify`, and a bare name resolves to
the bundled one.

## Checks

```bash
claude plugin validate .  &&  claude plugin validate plugins/arffornia
python3 plugins/arffornia/skills/harness-audit/scripts/skill_lint.py      # skill/agent lint, 0 errors
plugins/arffornia/skills/_shared/sync.sh --check                         # shared references in sync
python3 evals/run.py check                                               # + helper script tests
python3 evals/run.py triggers && python3 evals/run.py reviewer           # model evals (claude CLI)
```

## Adding a skill

Done twice by hand → a skill. Description = what + when, the trigger words users say first,
quoted if it contains ` #`. Body under ~150 lines, detail in `references/`, deterministic steps
in `scripts/` with a test in `evals/test_helpers.py`. Side effects → `disable-model-invocation:
true`, unless Brian approved that exact side effect (then a `<!-- side-effect-approved: ... -->`
line says who, when and what, as in `publish`). Heavy read-only research → `context: fork`. Add trigger cases (including a near-miss
negative) to `evals/triggers/cases.json` and a row here.
