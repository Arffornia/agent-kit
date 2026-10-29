---
name: postmortem
description: "Draft a blameless postmortem for an Arffornia incident (outage, broken modpack, failed release, data loss, security event) from git history, merged PRs, CI runs, releases and the logs provided: timeline, impact, root cause, what went well, action items as proposed issues. Use after an incident, when asked for a postmortem, incident review, RCA or retrospective of something that broke."
argument-hint: "<what happened> --from <UTC time> --to <UTC time> [repos...]"
context: fork
agent: general-purpose
background: false
---

# Postmortem draft (blameless)

Incident: `$ARGUMENTS`. You run in a fresh context with only this text and read access.
Blameless: describe what the system and the process allowed, never who was careless.
"The release workflow allowed a tag without CI" rather than "X tagged without CI".
The output is a **draft** file; nothing is posted or created.

## 1. Collect facts

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/timeline.py --from <start> --to <end> Arffornia/<repo> [...]
```
It lists commits on default branches, merged PRs, workflow runs with conclusions, releases
and issues opened in the window, each with a URL. Add what the caller gave (pod logs,
Discord reports, screenshots) with its source. Widen the window by a few hours on each side:
causes usually land before the symptom. Unreadable sources are listed as such.

Useful extra reads: the diff of the suspected change (`gh api repos/<r>/commits/<sha>`), the
failing run's log (`gh run view <id> --log-failed`), Argo CD history if access was given.

## 2. Establish

- **Impact**: who was affected (players, admins), what they saw, from when to when (UTC),
  how many if known. Data lost or not.
- **Detection**: how we found out and how long after the start. Could a check have caught it?
- **Root cause**: the chain of causes, proven by the timeline and the code (`path:line`),
  down to the condition that allowed it (missing test, guard, review, alert). Use "5 whys"
  only until the answer is a process or system property.
- **Trigger vs cause**: the change that triggered it is rarely the whole cause.

## 3. Write

Template: [references/template.md](references/template.md). Save to
`docs/postmortems/<YYYY-MM-DD>-<slug>.md` in the affected repo (or the docs repo for
cross-repo incidents) and return the path. Action items are concrete, owned, and phrased as
issue titles with labels (`type:`, `area:`, `priority:`); a security weakness that is still
open gets a neutral title and no details. Do not create the issues.

Return the draft path, then the list per [references/reporting.md](references/reporting.md):
Decide (action items for Brian to accept), FYI (the timeline sources), Not done (sources you
could not read).
