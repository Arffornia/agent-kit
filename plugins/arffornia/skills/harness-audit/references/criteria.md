# Audit criteria

| Smell | Evidence to collect | Usual fix |
|---|---|---|
| Too long | body > 200 lines, or details an agent needs only sometimes | move to `references/<topic>.md`, link it with "read when ..." |
| Description does not trigger | eval trigger cases fail; description starts with background instead of the use case | first sentence = what + when, with the words users say |
| Over-triggers | the skill loads on unrelated tasks (transcripts), descriptions overlap | narrow the description; add `paths:`; merge overlapping skills |
| Unused | 0 invocations over 30-60 days, no eval mentions it | delete (git keeps it); or merge into a sibling |
| Contradiction | "always X" here, "never X" there; skill vs AGENTS.md vs REVIEW.md | one source of truth, the others point to it |
| Stale | a command fails, a path is gone, a version is old (`ls`, `--help`, `gh api`) | update or delete the line |
| Rigid recipe | numbered steps for a judgement task, no "why" | state the goal and the checks; keep exact commands only where determinism matters |
| Missing determinism | "verify the ids" with no command | add a script under `scripts/` with a test |
| Side effect without gate | push/PR/release/delete in a model-invocable skill | `disable-model-invocation: true`, or move the command to the manual skill |
| Hidden dependency | "use the X skill" inside a skill | inline the essentials or share a reference copy (`_shared/`) |
| Rule ignored twice | eval or review finding repeating | escalate: hook (PreToolUse/Stop), lint with a how-to-fix message, CI check |
| Agent tool leak | a "read-only" agent with Edit/Write, or Bash where Grep suffices | restrict `tools` / `disallowedTools`, say the limit in the body |
| Trifecta | private data + untrusted input + external output in one agent | split the agent or drop one leg |

Measure before and after: trigger eval pass rate (`evals/run.py triggers`), reviewer eval
pass rate, lines of always-loaded context (AGENTS.md + descriptions).
