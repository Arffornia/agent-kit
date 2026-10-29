---
name: challenge
description: "Stress-test a plan, design, spec, PR or decision before Brian commits to it. Modes: against (strongest case against), for (steelman), alternatives (2-3 real options compared), pre-mortem (it failed in 6 months: why), jury (oral-exam questions). Always raises at least one serious objection. Use when asked to challenge, critique, poke holes, play devil's advocate, compare options or sanity-check a decision."
argument-hint: "[against|for|alternatives|pre-mortem|jury] <plan, spec path, PR or decision>"
---

# Challenge

`$ARGUMENTS`: the first word is the mode (default `against`), the rest is the target. Read
the target fully first (the spec, the PR diff, the issue thread, the ADRs it touches). A
challenge from a summary is worthless.

Agreement is not the job. Every run ends with **at least one serious objection**: something
that, if true, would change the decision or the design. If after honest effort you find none,
say which assumption you tested hardest and why it held; then name the weakest remaining
point anyway. Objections cite evidence (code `path:line`, a spec line, a number, a source
URL); a hunch is labelled as a hunch.

## Modes

| Mode | Output |
|---|---|
| `against` | The strongest case against: 3-5 objections ranked by impact, each with evidence, the consequence if ignored, and what would settle it (a test, a spike, a number). |
| `for` | Steelman: the best honest case for it, the conditions under which it is the right call, and the one objection that still stands. |
| `alternatives` | 2-3 real alternatives (including "do nothing" or "smaller version") in a table: cost, risk, reversibility, fit with the Arffornia constraints, what each makes impossible later. A recommendation with its main risk. |
| `pre-mortem` | "It is six months later and this failed." 5 plausible failure stories (technical, player-facing, operational, solo-maintainer load, security), each with an early warning sign and a cheap prevention now. |
| `jury` | 8-10 questions an expert jury would ask (oral exam style), hardest first, each with what a strong answer must contain and where the current material is weak. |

Arffornia constraints to test against, and the question bank per mode:
[references/modes.md](references/modes.md).

## Output

```
Challenge (<mode>): <target title + link>
Serious objection: <the one that matters most, one sentence>

<the mode's body>

What would change my mind: <evidence or experiment>
Decision belongs to: Brian
```

Never decide for Brian or edit the target. Links follow
[references/reporting.md](references/reporting.md).
