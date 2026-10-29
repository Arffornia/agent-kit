# harness-feedback issue body

```markdown
**Signal**: user correction | guard/hook fired repeatedly | skill misfire | review finding wrong/noise | friction | better way
**Where**: <repo> · <branch or PR URL> · <date> · agent: <Claude Code version / Codex / OpenCode>

## Evidence
- <what happened, quoted: the user's words, the block message, the command and its output>
- <the harness line responsible: `plugins/arffornia/<path>:<line>` or a full URL>

## Proposed patch
```diff
--- a/plugins/arffornia/skills/<name>/SKILL.md
+++ b/plugins/arffornia/skills/<name>/SKILL.md
@@
-<old line>
+<new line>
```
(or: the exact new rule text and where it goes)

## How to verify
- <the test case to add: `plugins/arffornia/scripts/tests/run.sh`, `evals/triggers/cases.json`, `evals/reviewer/<case>/`>
- <the command that shows it fixed>

## Impact
<how often, how costly: "every Laravel session", "once, but it cost a review round">
```

Keep it on one screen. The weekly automation reads **Proposed patch** and **How to verify**
first; an issue without them gets a question instead of a fix.
