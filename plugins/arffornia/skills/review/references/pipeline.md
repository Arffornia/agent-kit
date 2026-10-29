# Finder and verifier briefs

Finders run as `arffornia:review-finder` subagents (Opus, high effort), verifiers as
`arffornia:review-verifier` subagents (Sonnet, high effort; at high risk add a second one with
`model: opus`). Model choices and their evidence: agent-kit `docs/MODELS.md`.

Give each subagent its brief verbatim, plus: PR title and body (in-session: the task as the
issue states it), the issue's acceptance criteria, the diff command (in-session:
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/review-stamp.sh" diff`), the paths of `REVIEW.md` /
`AGENTS.md` / `CLAUDE.md` that apply, and the risk line from `risk.py`. Never pass your own
explanation of why the code is right. Tell every subagent: "Tools work; do not probe them.
Report only; never edit, push or comment."

## Finder: correctness

Find bugs the change introduces: wrong logic, unhandled error paths, null/empty/zero, off by
one, wrong units, races between threads or ticks (Minecraft server thread vs async futures,
Electron main vs renderer, queued Laravel jobs), resources not closed, retries without bound,
missing timeouts on network calls, state not reset on failure. Read the callers of every
changed function. Flag only issues you can tie to a changed line and that would misbehave for
a real input. For each: `path:line · claim · trigger input or sequence · how to confirm`.

## Finder: security

Untrusted input is: packets from clients (the mod), IPC from the renderer (the launcher),
HTTP requests and webhooks (the website), downloaded files and manifests (launcher, mods,
Provisioning `main` is live), PR content in CI. For each entry point the change touches:
is it validated server side (type, range, ownership, the player has the menu open, distance,
unlocked stage), authenticated, authorised, rate limited where it mints tokens or rewards?
Secrets never in code, logs, error pages, artifacts or `APP_DEBUG` output. Paths confined
(no `..`, no absolute paths from input), downloads checked (hash or signature) and written
atomically, URLs opened only from an allow-list. Workflows: `permissions:` minimal,
`pull_request_target` never checks out PR code with secrets. Report with the attacker's
step, not a generic "validate input".

## Finder: rules and tests

Check the change against the quoted rule files and the Arffornia hard rules: English in code
and docs; player text through i18n with `en` and `fr`; Nexus libraries improved, never
replaced; no merge/tag/release steps; behaviour changes have a ticket. Missing `make check`
output or test evidence in the PR body is a `major` process finding, not `blocking`.
Check the acceptance criteria one by one: met, partly met, not met. Check tests: a test
exercises the changed behaviour and would fail without the change (look for the
"break it, see it fail" note); negative paths tested for packets and endpoints. Quote the
exact rule broken; a rule silenced explicitly in code (lint ignore with a reason) is not a
finding.

## Verifier

You receive one claim. You did not write it; assume it may be wrong. Open the code at the
cited line on the PR head, follow the callers and the data, and decide:

- `confirmed` - you can show it: quote the lines, name the input that triggers it, or run a
  command that demonstrates it (paste the output). Say the severity you would give.
- `refuted` - the code handles it (quote where), the line is not in the change, or the
  premise is false.
- `unsure` - you could not settle it; say what would.

One verdict, evidence first, under 15 lines. Do not look for other issues.

## Merge step (you, the orchestrator)

1. Drop `refuted`; at high risk drop anything not confirmed by both verifiers.
2. Merge candidates with the same root cause.
3. Assign severity (severity.md); move findings on unchanged lines to PRE-EXISTING.
4. Cap style remarks at 3; drop the rest.
5. Count, then write the report.
