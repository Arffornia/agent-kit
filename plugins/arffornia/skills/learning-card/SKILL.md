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

Write a card only if at least one is true; otherwise skip silently:
- it is ahead of common practice (a recent technique, a new tool or model capability, a
  design from a strong source such as an Anthropic, OpenAI or Meta engineering post, a paper,
  a benchmark) and you applied or evaluated it;
- it changed a measurable result here (time to green, review false positives, cost, a bug
  class that disappeared);
- it explains a mechanism Brian asked about or would need to judge a decision.

Not a card: routine fixes, things already in the playbook, opinions without a source.

## 2. Where it goes

```bash
P="${AGENT_PLAYBOOK_DIR:-$HOME/agent-playbook}"
test -f "$P/veille/README.md" && sed -n '1,120p' "$P/veille/README.md"
```
- The README exists: follow its format, file name and destination exactly (it is owned by the
  tech-watch agent and wins over this skill).
- It does not: write `$P/veille/inbox/<YYYY-MM-DD>-<slug>.md` in the format below
  (`mkdir -p` the folder). Never commit or push the playbook repo from here.
- No writable playbook (cloud session, another machine): put the card in your final report
  under "Learning card" so the human can file it.

## 3. Default format (when there is no README)

```markdown
---
title: <what it is, in a few words>
date: <YYYY-MM-DD>
source: <repo / PR / session URL where it came up>
tags: [<area>, <technique>]
status: inbox
---

**In one sentence**: <the idea>.

**Why it matters**: <the problem it solves, with a number if there is one>.

**How it works**: <3-6 lines or a small diagram: the mechanism, not marketing>.

**How we use it / could use it in Arffornia**: <where, with links>.

**Go further**: <what would push it further: the next experiment>.

**Sources**: <title - URL (date)>, at least one primary source.
```

Keep it under 40 lines, in English, with full links. No secrets or personal data.

## Report

`Learning card: <absolute path> - <title>` in your final report, per
[references/reporting.md](references/reporting.md).
