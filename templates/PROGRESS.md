# Progress

Handoff between sessions. The SessionStart hook shows the top of this file to every new
session, so keep "Now" short and current. The PreCompact and SessionEnd hooks append
automatic entries under "Log" (never committed automatically). Multi-session work with
decisions belongs in `docs/exec-plans/active/<slug>.md`; link it here.

## Now

- Goal: <one line, with the issue URL>
- Done: <what is finished and verified (command + result)>
- Next step: <the very next action, concrete enough to start without asking>
- Blockers / decisions needed: <none, or the question and who decides>
- Verify with: `make check` <plus any targeted command>

## Log

<!-- Newest automatic entries are appended below. Replace them with a real summary when you resume. -->
