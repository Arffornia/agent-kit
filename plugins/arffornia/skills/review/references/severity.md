# Severity

| Level | Means | Arffornia examples |
|---|---|---|
| blocking | Wrong behaviour, security hole, data loss, broken build or CI, or a hard rule broken **in the code** (secret committed, player text not translated, a Nexus_* library replaced, a release/merge step added). Fix before merge. | A serverbound packet trusted without menu/distance/stage checks; a token written to a log file; debug mode in a production config; a modList entry for the wrong loader on live `main` |
| major | A reviewer would stop on it: a real bug on an uncommon path, a missing test for the risky path, an acceptance criterion not met, missing evidence in the PR (no `make check` output, no test names). | 401 retry without bound; a migration without a down path on a populated table; French missing for new player text |
| minor | Worth fixing, not blocking. Style only if it hurts reading; at most 3 per review. | Misleading name on a public method; an error message that hides the cause |
| pre-existing | A real bug the change did not introduce. Listed apart, never blocks; propose an issue. | An unvalidated packet next to the one being fixed |

Process gaps (PR body, evidence, labels) are never blocking on their own: the code decides.

`REVIEW.md` on the base branch may redefine blocking for its repo (e.g. docs repo: only broken
links and wrong facts block). Follow it and say so.

Maps to the Claude Code Review markers: blocking = Important (red), minor = Nit (yellow),
pre-existing = Pre-existing (purple). Major has no marker there; we keep it because Brian
merges alone and needs a "stop and think" tier between the two.
