---
name: harness-feedback
description: "Record a lesson for the Arffornia agent harness as a GitHub issue in Arffornia/agent-kit (label harness-feedback), with evidence and a proposed patch, appending to an existing issue instead of duplicating. Use when the user corrects how the agent works, a guard or hook fires again and again, a skill misfires or gives a wrong step, a review finding was wrong or noise for a recurring reason, or you notice friction or a better way to do something the harness prescribes."
argument-hint: "[short description of the friction]"
---

# Record harness feedback

<!-- side-effect-approved: Brian (2026-10-29 feedback): agents open or comment harness-feedback issues in Arffornia/agent-kit only; no other write -->

The harness (agent-kit: skills, subagents, hooks, rules, templates) only improves if its
failures are written down with a fix. One lesson = one issue; the same lesson seen again = a
comment on that issue. A weekly automation turns open issues into one PR.

Signal: `$ARGUMENTS` (or what just happened). Do the user's task first; record the lesson
before you finish, in under five minutes.

## 1. Is it a harness lesson?

Yes when the next agent, in another session, would hit it again: a rule that is missing or
misleading, a skill step that is wrong, stale or unclear, a guard or hook that blocked a
legitimate action or let a bad one through, a model or effort choice that failed, a command
that does not work on macOS or Linux, a better workflow you found. **No** when the correction
is only about this task's content ("make the button blue"): skip, say nothing.

## 2. Search before you write

```bash
gh api -X GET search/issues -f q='repo:Arffornia/agent-kit is:issue is:open label:harness-feedback <2-4 keywords>' \
  --jq '.items[] | "\(.number) \(.title) \(.html_url)"'
```
Try two keyword sets (the component name, then the symptom). A match is the same root cause,
not just the same file.

## 3a. Match: append

```bash
gh api repos/Arffornia/agent-kit/issues/<n>/comments -f body="$(cat comment.md)" --jq .html_url
```
Comment: `Seen again: <date> in <repo> (<branch or PR URL>)`, the new evidence, and a better
patch if you have one. Do not repeat the original text.

## 3b. No match: open one issue

Title: `<component>: <what goes wrong>`, imperative fix optional, under ~80 chars
(`guard: blocks git checkout -- . on a clean tree`, `review skill: delta round re-reviews the whole diff`).
Body: the template in [references/issue-template.md](references/issue-template.md): Signal,
Evidence, Proposed patch (a unified diff against agent-kit paths, or the exact new text),
How to verify, Impact. Then:

```bash
gh api repos/Arffornia/agent-kit/issues -f title='<title>' -f body="$(cat issue.md)" \
  -f 'labels[]=harness-feedback' -f 'labels[]=area: ai' --jq .html_url
```

## Rules

- Evidence is quoted: the user's words (short), the hook or guard message, the command and
  its output, the skill line (`plugins/arffornia/skills/<name>/SKILL.md:<line>`), with links.
- Public repo: no secrets, tokens, personal data or internal hostnames. A lesson that reveals
  an unfixed security weakness gets a neutral title and no reproduction steps.
- Never edit agent-kit from here, and never push to it: the issue carries the patch, the
  weekly `harness-feedback` automation (or Brian) applies it in a reviewed PR.
- Codex, OpenCode and other agents: same steps; if `gh` is not available, write the issue
  text in your final report under "Harness feedback" so the human can file it.

## Report

One line in your final report: `Harness feedback: <issue URL> - <title> (new | +1)`, per
[references/reporting.md](references/reporting.md).
