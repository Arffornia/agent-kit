---
name: learning-card
description: "Draft a short tech-watch card for Brian when the work produced or found something genuinely state of the art (a technique, a design, a benchmark result, a tool or practice few people know yet) that he would want to learn from. Writes it where the tech-watch agent's veille/README.md says, else to the playbook inbox. Use when you notice such a thing, or when asked to note, explain or keep a learning, a tip or a state-of-the-art finding."
argument-hint: "[topic]"
---

# Draft a learning card

Brian wants the agents to work without him **and** to keep learning from what they build. A
card captures one thing worth remembering: what it is, why it matters, how it works, and how
it applies to Arffornia. Topic: `$ARGUMENTS` (or what just happened).

## 1. Is it card-worthy?

Only when all three hold (the tech-watch README's rule); otherwise skip silently:
- **We built or used it**: it starts from real work in our repos, not a news item.
- **It is genuinely high value to learn**: state of the art, surprising, or reusable elsewhere.
  A routine fix, a library upgrade or a config tweak is not a card.
- **There is something to propose**: at least one concrete next step for our setup.

## 2. Where it goes and in what shape

```bash
P="${AGENT_PLAYBOOK_DIR:-$HOME/agent-playbook}"
test -f "$P/veille/README.md" && cat "$P/veille/README.md" "$P/veille/inbox/README.md" 2>/dev/null
```
The tech-watch README owns the format and destination and wins over this skill. Today it says:
- unsure, or no time: a **proposal** in `$P/veille/inbox/<yyyy-mm-dd>-<slug>.md`, 10 lines max:
  ```markdown
  # <Proposed card title>
  - Why it matters: <one line>
  - What we built: <repo, PR or commit links>
  - Best-in-class references: <2-3 URLs>
  - Proposed by: <agent / session>, <date>
  ```
- a full card (`veille/cards/`, sections and front-matter per the README, plus an `INDEX.md`
  line): at most one per run, only after the main task is done.

No README: write the proposal format above to `$P/veille/inbox/` (`mkdir -p`). Never commit or
push the playbook repo from here. No writable playbook (cloud session, another machine): put
the proposal in your final report under "Learning card" so a human can file it.

English, plain sentences, every number with a source, no secrets or personal data.

## Report

`Learning card: <absolute path> - <title>` in your final report, per
[references/reporting.md](references/reporting.md).
