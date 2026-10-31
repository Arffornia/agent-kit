# Reporting work to a human

<!-- Canonical copy: plugins/arffornia/skills/_shared/reporting.md. Each skill carries its own copy
     in references/reporting.md so it stays self-contained (open SKILL.md standard, Codex sync).
     Edit the canonical file, then run plugins/arffornia/skills/_shared/sync.sh. -->

Brian reads reports on a phone between other things. A report is a list of things to open and
decide, not a story of what you did. These rules apply to every final message, PR body, issue,
handoff, exec plan update and page you write.

## Hard rule: every reference is a full link with a one-line summary

Never mention a PR, issue, commit, branch, CI run, artifact, page, file or release without its
full clickable URL and one line saying what it is and what state it is in.

| Instead of | Write |
|---|---|
| "PR #52" | `https://github.com/Arffornia/Arffornia_Mods/pull/52` - add HTTP timeouts and one re-auth on 401; CI green, ready for review |
| "the commit" | `https://github.com/Arffornia/Arffornia_Mods/commit/3f2a9c1` - adds the GameTest that fails before the fix |
| "see the report" | `/home/claude/arffornia/_work/kit-v2-skills.md` - full report (absolute path when there is no URL) |
| "CI failed" | `https://github.com/Arffornia/Arffornia_Website/actions/runs/123456` - `make check` red: phpstan, 2 errors |
| "line 42 of the handler" | `https://github.com/Arffornia/Arffornia_Mods/blob/<full-sha>/src/.../Packet.java#L40-L44` |

- Build URLs from facts, not memory: `gh api repos/<o>/<r>/pulls/<n> --jq .html_url`,
  `git rev-parse HEAD` for the full SHA in blob links, `gh run list --json url`.
- A local file with no URL is an absolute path. A link that is not reachable yet is still
  given, marked "(not pushed yet)" or "(private)".
- Code links use a full commit SHA (`blob/<40-hex>/path#Lx-Ly`), never a branch name: branch
  links move.
- Security: for an unfixed exploitable weakness in a public repo, the link and a neutral
  summary ("Harden IPC input validation"), never the exploit.

## Order by what the human must do

Group the list under these headings, in this order, and drop empty groups:

1. **Decide** - questions only Brian can answer (`needs-decision`, design choices, anything
   blocked on him). One line each: the options and your recommendation.
2. **Review / merge** - PRs ready for him, most important first. Say what to read first.
3. **Act** - things he must do by hand (rotate a secret, approve an environment, buy a cert).
4. **FYI** - done, nothing to do: issues created, drafts, background runs.
5. **Not done** - what you could not do and why (a failed command, missing access), so it is
   never mistaken for "nothing to report".

## Shape

- First line: the outcome in one sentence with counts (`3 PRs opened, 1 decision needed`).
- One item per line: `<URL> - <what it is>; <state>; <what to do>`.
- Evidence (command output, test names) goes in the PR body or the linked file, not the chat
  summary. Quote at most 3 lines inline.
- No narration of steps, no restating what the link already says.

## Example

```
2 PRs opened, 1 decision needed, 1 thing not done.

Decide
- https://github.com/Arffornia/Arffornia_Mods/issues/17 - machine framework direction (spec 002 D1-D6); I recommend D1=a, one MachineType registry

Review / merge
- https://github.com/Arffornia/Arffornia_Mods/pull/52 - HTTP timeouts and a single re-auth on 401 in the API client; CI green; read the client class first
- https://github.com/Arffornia/Arffornia_Launcher_V.5.2/pull/61 - await authentication before launch; CI green

FYI
- https://github.com/Arffornia/Arffornia_Mods/issues/53 - follow-up: cache progression reads (P2)

Not done
- Website e2e: `npx playwright install` blocked by the proxy (403); tests not run
```
