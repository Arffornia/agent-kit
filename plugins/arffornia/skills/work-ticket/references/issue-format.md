# Issue format and labels

```
Title: <Imperative verb> <specific outcome>          (under ~80 chars, no "As a ...")

**Context**
<1-3 sentences: the problem and what triggered it.>

**Evidence**
- `path/to/file.ext:42` <what it shows>   (a blob link with a full SHA when it is on GitHub)

**Acceptance criteria**
- [ ] <observable outcome a non-author can check>

**Notes**
<risks, out of scope, links. Delete if empty.>
```

Labels come from the existing taxonomy (`gh api repos/Arffornia/<repo>/labels --jq '.[].name'`),
never new ones. Spelled with a space after the colon.

| Axis | Pick exactly one |
|---|---|
| `type: ` | `bug`, `security`, `feature`, `deps`, `test`, `docs`, `ci`, `refactor` |
| `area: ` | `website`, `launcher`, `mod`, `proxy`, `provisioning`, `libs`, `infra`, `ai` |
| `priority: ` | `P0` now (security, data loss), `P1` next, `P2` planned, `P3` nice to have |
| `effort: ` | `S` under half a day, `M` 1-3 days, `L` more |
| readiness | `agent-ready` **only** with acceptance criteria and no open design question; otherwise `needs-decision`. An idea is `proposal`. |

Milestones: `M1 · Foundation & security`, `M2 · Tests & CI`, `M3 · Gameplay foundations`
(`gh api repos/Arffornia/<repo>/milestones --jq '.[] | [.number,.title]'` for the number).

Dependencies: write `Blocked by #N` / `Depends on #N` in Notes; the prio skill reads them.

Create, only after the user approved the text (REST; GraphQL may be unavailable):
```bash
gh api repos/Arffornia/<repo>/issues -f title='...' -f body="$(cat body.md)" \
  -F milestone=<number> \
  -f 'labels[]=type: bug' -f 'labels[]=area: proxy' -f 'labels[]=priority: P1' \
  -f 'labels[]=effort: S' -f 'labels[]=agent-ready' --jq .html_url
```
Report the returned URL with a one-line summary.
