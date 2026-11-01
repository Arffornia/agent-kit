# Workflow between Brian and the agents

Source of truth for how work flows in Arffornia (adopted 2026-10-31). The generic version is
`runbook/WORKFLOW.md` in https://github.com/TheGostsniperfr/agent-playbook ; this page adds the
Arffornia specifics.

| # | Step | Who | Where |
|---|---|---|---|
| 1 | Propose chantiers | Agents | Card on the review stack; chantier issue in Arffornia/docs |
| 2 | Spec + decisions with defaults (each with a plain `why`) | Agents; Brian validates or challenges | Spec page linked from the card |
| 3 | Implement, open the PRs | Agents (`publish` skill, after `make check` and the review gate) | GitHub |
| 4 | End-of-task review | Agents (`/arffornia:review`, Stop-hook gate) | In the session; result in the PR body |
| 5 | Human checks only where needed | Brian | Review stack: decisions, high-risk points, manual tests with a guide |
| 6 | Validate the chantier | Brian | "Approve" on the review stack (mirrored as label `chantier: approved`) |
| 7 | Merge and deploy | Orchestrator agent | `chantiers.py --merge-plan <n> --execute` in Arffornia/docs, in order |

Rules:
- **Merge authority.** Agents merge only PRs listed in an approved chantier, in its order, via
  the merge plan (it refuses without the approval label). `gh pr merge` by hand stays blocked
  by the guard.
- **Lockfile-only security bumps** are the one exception (Brian, 2026-11-01). An agent may
  merge one without a card when all of these hold:
  - the PR fixes a published security advisory;
  - it changes only lockfiles (`package-lock.json`, `composer.lock`, `gradle.lockfile`, ...);
  - every CI check on the head commit is green.

  It merges with a merge commit, pinned to the head SHA. List it in the next weekly brief.
  A bump that also touches a manifest, code or config still needs a card.
- **Specs before code** for new chantiers. Implement directly only what Brian asked for
  explicitly or what is clear-cut; the rest is "needs decision".
- **Reports are high level**: done, problems, axes taken, what needs Brian. Evidence stays in
  the PR. Every link is a full URL with a one-line summary.
- **Free only**: no paid service; free tiers, open source, self-hosted. A domain name is fine.
- **No hard WIP cap**: Brian reviews in evening and weekend batches; the stack shows a soft
  review load. Proposals never expire; dormant ones resurface in the weekly brief.
- **State**: `Arffornia/ops` `STATE.md` (private) is the entry point for a new chat; agents
  update it with the `handoff` skill at the end of a session.

## Git, in plain words
- Each agent works on its own branch in its own worktree and opens a PR. Pushing to `main`,
  plain `--force`, tags and branch deletion are blocked by the guard and deny rules.
- `--force-with-lease` is allowed on the agent's own feature branch only, after a rebase
  (replaying its commits on top of the newest main). It means "overwrite my branch only if
  nobody else pushed to it since I last fetched", so it cannot erase someone else's work. When
  in doubt, merge main into the branch instead: no force needed.
- PRs merge with merge commits (history keeps each PR's commits).
