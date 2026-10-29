---
name: harness-audit
description: "Audit the agent harness (agent-kit skills and subagents, a repo's AGENTS.md, .claude/rules, settings and hooks) for skills that are too long, contradictory, overlapping, unused, stale or unsafe, and propose pruning and fixes. Proposes only. Use when asked to audit, clean up or prune skills or agent docs, on the scheduled harness audit, or when agents keep ignoring a rule."
argument-hint: "[path to agent-kit or a repo] [--days 30]"
context: fork
agent: general-purpose
background: false
---

# Harness audit

Target: `$ARGUMENTS` (default: the current directory). You run in a fresh context and only
read. The output is a proposal: what to cut, merge, fix or escalate, with evidence.
A harness gets worse by accretion; the default recommendation for an unused or overlapping
skill is to delete it.

## 1. Lint (deterministic)

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/skill_lint.py --transcripts ~/.claude/projects --days 30
```
From the target root. It checks front matter (unknown keys are silently ignored by Claude
Code, an unquoted ` #` truncates a description), description length and trigger phrase,
body length, broken links and bundled paths, unreferenced `references/` and `scripts/`
files, side effects without `disable-model-invocation: true`, skills that depend on other
skills, description overlap, `always X` / `never X` contradictions, `AGENTS.md` over 100
lines, and (with transcripts) how often each skill was invoked. Add
`claude plugin validate <plugin-dir>` when the CLI exists.

## 2. Judge what a linter cannot

Read each skill and agent. Criteria with examples: [references/criteria.md](references/criteria.md).
- **Stale**: commands, paths, versions or repos that no longer exist (check them: `ls`,
  `grep`, `gh api`), references to finished migrations.
- **Rigid where judgement is needed / vague where determinism matters**: a 12-step recipe for
  a design task; "check the labels" where an exact command exists.
- **Ignored rules**: a rule agents broke twice (evals, reverted PRs, review findings) should
  become a sensor: a hook, a lint, a CI check. Propose which.
- **Map, not manual**: `AGENTS.md` as a table of contents; detail belongs in
  `.claude/rules/*.md` with `paths`, `docs/agents/`, or skill `references/`.
- **Safety**: trifecta in automations; tools of read-only agents really read-only.

## 3. Propose

```
Harness audit: <target> · <N> skills, <M> agents · lint <e> errors, <w> warnings
Prune (delete or merge)
- <skill> - <evidence: 0 invocations in 30 days, overlaps <other> 0.6>; proposal: delete | merge into <x>
Fix
- <file:line> - <problem>; proposal: <exact change>
Escalate to a sensor
- <rule> - broken in <links>; proposal: <hook / lint / CI check>
Keep (healthy): <list>
```
Each proposal is small enough to be one PR. Do not edit files. Links follow
[references/reporting.md](references/reporting.md).
