# Spec template (same sections as docs/specs/001-003)

```markdown
# NNN · <Title>

| | |
|---|---|
| **Status** | Draft: needs decisions |
| **Milestone** | M3 · Gameplay foundations |
| **Repos** | Arffornia_Mods, Arffornia_Website |
| **Related** | [ADR-00XX](../decisions/00XX-....md) · issues Mods [#N](https://github.com/Arffornia/Arffornia_Mods/issues/N) · [00Y](00Y-....md) |

## Summary
One paragraph: what changes for players and for the code, and why now.

## Goals
- Observable outcomes, each checkable.

## Non-goals
- What this deliberately does not do (and where it goes instead).

## Player experience
What a player sees and does, step by step, in both languages where text matters.

## Design
Components, data, protocol, with tables (class · role), code sketches and a mermaid
diagram where a flow is involved. Server-authoritative by default; trust boundaries named.

## Migration from the current system
What exists today (with `path:line`), how players and data move over, how to roll back.

## Testing
GameTests / Feature tests / Playwright journeys that prove each goal; the UI checks for screens.

## Work breakdown
| # | Ticket | Repo | Effort | Depends on |
|---|---|---|---|---|

## Decisions needed
| # | Question | Options | Recommendation |
|---|---|---|---|
| D1 | ... | a) ... b) ... | a, because ... |
```

`PROJECT.md` (a new repo or product) uses: Purpose · Users · Scope and non-goals · Constraints
(stack, hosting, budget, maintainer time) · Architecture sketch · Milestones · Success measures
· Risks · Decisions needed. Under ~120 lines.
