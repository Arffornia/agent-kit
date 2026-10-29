# Sources

The pipeline follows these, checked on 2026-10-29:

- Claude Code Review docs, "How reviews work": find (several agents in parallel on the diff
  and surrounding code), verify (checks candidates against the code, filters false
  positives), rank (dedupe, severity), post. Severity markers Important / Nit /
  Pre-existing; REVIEW.md read from the base branch, never from the PR.
  https://code.claude.com/docs/en/code-review
  https://code.claude.com/docs/en/code-review-pull-requests
  https://code.claude.com/docs/en/code-review-customize
- Anthropic, "Bringing Code Review to Claude Code": "The agents look for bugs in parallel,
  verify bugs to filter out false positives, and rank bugs by severity"; "Large or complex
  changes get more agents and a deeper read; trivial ones get a lightweight pass"; built for
  depth, not speed (about 20 minutes per review); never approves a PR. Internal numbers:
  substantive comments on 54% of PRs (from 16%), under 1% of findings marked incorrect.
  https://claude.com/blog/code-review
- `/code-review` locally: re-reviews focus on what changed since the last review and post
  fewer nits; `low` effort reports only the most confident findings.
  https://code.claude.com/docs/en/code-review-local
- The open-source `code-review` plugin (anthropics/claude-plugins-official): parallel
  CLAUDE.md-compliance and bug agents, one validation subagent per issue, unvalidated issues
  dropped, a false-positive list, links with a full SHA and line range.
  https://github.com/anthropics/claude-plugins-official/tree/main/plugins/code-review

What we add for Arffornia: routing by `risk.yml`, two verifiers at high risk, a `major` tier,
the "max 3 style remarks" cap, and evals of real audit findings in `evals/reviewer/`.
