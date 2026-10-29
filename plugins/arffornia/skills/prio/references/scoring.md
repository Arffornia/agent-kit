# Scoring

`score = impact x urgency / effort + 1.5 x unblocks`, then multipliers.

| Factor | Source | Values | Why |
|---|---|---|---|
| impact | `type:` label | security 5, bug 4, test/ci 3, feature 3, refactor/deps 2, docs 1; unlabelled 2 | security and correctness hurt players first; tests and CI multiply every later change |
| urgency | `priority:` label | P0 4, P1 3, P2 2, P3 1; unlabelled 1.5 | P0 = now; unlabelled issues sink but stay visible |
| effort | `effort:` label | S 1, M 2, L 4; unlabelled 2 | cheap wins first at equal value |
| unblock | "Blocked by #N" / "Depends on #N" / "after #N" in other open issues | +1.5 each | unblocking work multiplies throughput |
| in progress | an open PR body says `Closes #N` | x0.2 | do not start what is already being done; review it instead |
| needs-decision | label | x0.5 | Brian decides first; listed under "Needs Brian" |
| proposal | label | x0.3 | an idea, not a ticket |

Ties: lower effort first, then lower issue number (older).

The script is a starting point. Judgement overrides it with a stated reason; the reason is
what Brian checks. Never change labels yourself; propose the change.
