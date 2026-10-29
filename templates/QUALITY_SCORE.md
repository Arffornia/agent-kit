# Quality score — <Repo name>

One row per area. Updated by an agent (harness audit automation) or by hand after a PR that
changes an area's grade. Grades: **A** solid (tested, documented, no known gaps) · **B** fine with
known gaps · **C** works, fragile or untested · **D** broken or risky. Every grade below A lists
its gaps as links to issues, so the score is a to-do list, not an opinion.

Last updated: <YYYY-MM-DD> by <who> at <commit SHA>

| Area | Grade | Tests | Docs | Gaps (issue URLs) |
|---|---|---|---|---|
| <e.g. Auth / login> | <A-D> | <unit/feature/e2e, or none> | <AGENTS.md, ADR, none> | <https://github.com/Arffornia/<repo>/issues/<n> one-line gap> |
| <e.g. API contract> | | | | |
| <e.g. Build & CI> | | | | |
| <e.g. Security hardening> | | | | |
| Harness (AGENTS.md, rules, make check, hooks) | | | | |

## How grades move
- Up: a PR closes the gap issue and adds the test or doc that proves it.
- Down: a revert, an incident, or a reviewer finding in that area adds a gap issue.
- The harness audit automation re-checks each row monthly and opens a PR with the changes.
