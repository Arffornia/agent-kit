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
| `publish` | Push the branch and open a draft PR after secrets scan, `make check`, review and evidence | **manual** | `git push`, opens a draft PR, adds labels |
| `review` | Review a PR, branch or diff: risk-routed finders, a verifier per finding, confirmed findings only | auto | none (comments only when asked) |
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
| `noodle-arffornia` | Update `architecture/arffornia` in the docs repo: discover, drift, lint, headless export | auto (paths: `architecture/**`) | edits model/views/layouts, renders `docs/assets/diagrams/` |

## Subagents

| Agent | When to use | Tools | Notes |
|---|---|---|---|
| `arffornia:reviewer` | Independent review before publish or on a PR | Read, Glob, Grep, Bash, Agent; no Edit/Write | Opus; preloads `arffornia:review`; spawns finders and verifiers |
| `arffornia:security-reviewer` | High-risk diffs, new surfaces, security review | Read, Glob, Grep, Bash; no Edit/Write/Agent | Opus; preloads `arffornia:threat-model`; trifecta check |
| `arffornia:test-writer` | Tests from acceptance criteria, independent of the implementation | Read, Glob, Grep, Bash, Write, Edit | `isolation: worktree` on the default branch: cannot see the implementation; writes only test paths |
| `arffornia:verifier` | Run the real thing and return PASS/FAIL/NOT RUN with evidence | Read, Glob, Grep, Bash; no Edit/Write/Agent | Sonnet; preloads `arffornia:verify`; must not change tracked files |
| `arffornia:doc-gardener` | Docs that no longer match code; scheduled gardening | Read, Glob, Grep, Bash; no Edit/Write/Agent | proposes exact replacement text |
| `arffornia:fact-finder` | Sourced YAML inventory for a Noodle diagram or a cross-repo explainer | Read, Glob, Grep, Bash; no Edit/Write/Agent | Noodle `v1alpha1` vocabulary, `src` + `how` on every fact |

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
true`. Heavy read-only research → `context: fork`. Add trigger cases (including a near-miss
negative) to `evals/triggers/cases.json` and a row here.
