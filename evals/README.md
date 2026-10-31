# evals

Measure the harness, not the model. Two suites run against the local plugin with `claude -p`,
plus offline checks. Every wrong review finding, missed finding or reverted PR that a skill
should have prevented becomes a case here.

```bash
python3 evals/run.py check                 # offline: case files, shared references, helper script tests
python3 evals/run.py list                  # show every case
python3 evals/run.py triggers [--only rev-1,gt-1] [--runs 3] [--model <id>]
python3 evals/run.py reviewer [--only app-debug-true]
python3 evals/run.py all
```
Needs the `claude` CLI (Claude Code) logged in. Outputs of reviewer runs go to
`evals/.results/<timestamp>/` (git-ignored).

## Triggers: does the right skill load?

`triggers/cases.json`: `{id, skill, should_trigger, query}`. Each query runs in an empty temp
git repo with only this plugin (`--plugin-dir plugins/arffornia`) and only `Skill`, `Read`,
`Glob`, `Grep` allowed in `dontAsk` mode, so a run cannot change anything. Pass = Claude calls
the Skill tool with exactly `arffornia:<skill>` (or does not, for `should_trigger: false`).
Matching is strict because Claude Code bundles skills with the same short names (`/review`,
`/verify`). Manual skills (`upgrade-deps`) are negative cases: they must never auto-load. `publish` is
agent-run since 2026-10-31 (Brian's workflow), so "push this branch and open the PR" must load it. Near-miss negatives (`rev-n1`, `mp-n1`, `nd-n1`) matter more than easy ones.
`--runs 3` uses the majority vote; triggering is not deterministic.

## Reviewer: does the review find what matters, and only that?

`reviewer/<case>/` = `case.json` + `base/` + `head/`. The runner builds a throwaway git repo
(`base` on `main`, `head` on `feature`), asks the main session to delegate to the
`arffornia:reviewer` subagent (as in real use: `skills:` preloading applies to subagents, not
to an `--agent` main thread), and checks the `Findings:` line and regexes.

| Case | From | Expect |
|---|---|---|
| `launch-without-await` | audit launcher §7 / launcher issue #40: an async auth call used without `await`, so its null check never fires | ≥1 blocking naming the missing await |

**Held cases.** Cases that mirror security findings which are not fixed yet are not committed
(STANDARDS rule 6: no details of unfixed weaknesses in public repos). They live in
`evals/reviewer-held/` (git-ignored) on the machine that has the audit, the runner picks them
up automatically, and each moves to `reviewer/` once its fix is merged. At creation there were
four: three real high-severity audit findings (a serverbound packet, launcher logging, a
production config) and one false-positive guard built from the published fix of the first.

`expect` keys: `min_blocking`, `max_blocking`, `must_match`, `must_not_match` (Python regexes,
case-insensitive for `must_match`).

## Add a case

1. Trigger: append to `triggers/cases.json`; prefer phrasings real users type and near-misses.
2. Reviewer: copy the smallest real excerpt (base and head) from the repo history, write
   `case.json` with `source` pointing to the audit, issue or PR, run it 3 times, and keep it
   only if the expectation is fair (a careful human reviewer would get it from the excerpt).
3. `python3 evals/run.py check`.

## Results at creation (2026-10-29, Claude Code 2.1.312)

- Triggers: 34/34 in one run (strict `arffornia:` matching). `rev-2`, `dbg-1`, `exp-1` failed
  first; after sharpening those descriptions, 7 review/debug/verify/explain cases passed 3/3.
- Reviewer: 5/5 (1 public + 4 held) with nested subagents enabled (finders, then 2 verifiers
  per candidate at high risk). The false-positive guard first failed: "no `make check` output
  in the PR" was ranked blocking; severity now ranks process gaps as major. On that clean fix
  the reviewer also found a real ordering race, kept as major.
- The environment of a nested agent may set `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`; the runner
  sets it to 3 so the reviewer can spawn finders and verifiers. Without that the reviewer
  falls back to sequential passes and says so.

## Results after the in-session rework (2026-10-29, Claude Code 2.1.312)

- Triggers: the 10 review / harness-feedback / learning-card / work-ticket cases (including the
  near-miss negatives) pass **3/3 each (pass^3)** with `--runs 3`.
- Reviewer with the new `review-finder` (Opus) and `review-verifier` (Sonnet) agents: **5/5**
  (1 public + 4 held). Two cases first hit the old 20-minute runner timeout (finders plus a
  verifier per candidate take longer); they pass with a longer budget, now the default (x25).
- Model ablation still to run: `--runs 3` on the reviewer suite with the verifier on Opus vs
  Sonnet, kept only if pass^3 does not drop (agent-kit docs/MODELS.md).
