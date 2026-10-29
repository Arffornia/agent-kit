---
name: cadrage
description: "Frame a new project or feature by interviewing Brian, then draft PROJECT.md or a spec in the Arffornia format (summary, goals, non-goals, player experience, design, open questions, milestones). Use when starting something new, when an idea is still vague, when asked to scope, frame, cadrer or write a spec or project brief, or before an exec plan exists."
argument-hint: "<idea or topic> [project|spec]"
---

# Cadrage: interview, then draft

Topic: `$ARGUMENTS`. The goal is a short document Brian can approve or correct in five
minutes, built from his answers, not from guesses. Output is a **draft**; decisions stay his.

## 1. Read what exists

Before asking anything: the docs repo `docs/specs/` and `docs/decisions/` (ADRs), the related
issues (`gh api repos/Arffornia/<repo>/issues?state=all&per_page=100` and grep titles), the
code area it touches, and `docs/roadmap.md`. Do not ask what the repo already answers; cite it.

## 2. Interview

Ask in rounds of **at most 3 questions**, each answerable in a line, most decisive first,
with your proposed default so he can just say "yes". Stop as soon as the draft can be written;
unknowns become Open questions. The question bank (problem, players, scope, constraints,
success, risks) is in [references/interview.md](references/interview.md).

Interview rules: one topic per question; offer options when there are real alternatives
(A / B / C, with your recommendation); never ask for something you can look up; reflect back
what you understood in one sentence before the next round.

## 3. Draft

- A whole new project or repo: `PROJECT.md` at the repo root.
- A feature or system inside the ecosystem: `docs/specs/NNN-<slug>.md` in the docs repo, next
  number, added to `docs/specs/index.md`.

Use [references/spec-template.md](references/spec-template.md) (the format of specs 001-006).
Every section filled or explicitly "none"; facts from code cited with `path:line`; options
with trade-offs where Brian must choose (D1, D2, … in "Decisions needed").

## 4. Hand it over

Show the draft path, the decisions needed (each with options and your recommendation) and
what you assumed. Do not open issues or an exec plan until the draft is approved. Report per
[references/reporting.md](references/reporting.md).
