# agent-kit as the Arffornia org layer

Three layers build the skills an Arffornia agent reads (plain-words version:
agent-playbook `overlay/README.md`):

1. **Personal base**: TheGostsniperfr/agent-playbook `skills/` (generic: review-stack, handoff,
   resume, bootstrap, propose-skill, cross-repo-issue, overlay-apply, artifact-style...).
2. **Org layer**: this repo, `overlay/arffornia.yaml` (patches every Arffornia repo gets) plus the
   Arffornia-only skills in `plugins/arffornia/skills/` (mc-gametest, modpack-change, review...).
3. **Project layer**: each repo's `.agents/overlay.yaml` (extends layer 2, pins, own patches).

The `agentskills` resolver applies them in that order and renders plain files; `agentskills
preview` shows the rendered diff of any change, `agentskills export` the full build.

## Status (2026-10-31)
- Done: `overlay/arffornia.yaml` (org patches for review-stack, handoff, propose-skill,
  cross-repo-issue; pins for resume, bootstrap, overlay-apply, artifact-style). Rendered end to end
  in a scratch project with the base PRs checked out: base text, org patches and a project patch
  all land in `.claude/skills` and `.agents/skills`.
- Waiting: the base skills it selects are in open agent-playbook PRs
  (https://github.com/TheGostsniperfr/agent-playbook/pull/1 to /5). Until they merge, a render
  against `ref: main` fails on the missing skills; that is expected.

## Migration plan (one PR each, in order)
1. **Base PRs merge** (agent-playbook #1-#5). No change here.
2. **Render the generic skills into the plugin.** Add `.agents/overlay.yaml` in this repo that
   extends `overlay/arffornia.yaml` (path `.`) with `paths: {claude: plugins/arffornia/skills}`
   and the Arffornia-only skills listed under `local:`; run `agentskills render --target claude`;
   commit. The managed-folder marker keeps the hand-written skills untouched. Codex output
   replaces `codex/sync-skills.sh` (`--target codex`).
3. **Retire duplicates.** `plugins/arffornia/skills/handoff` (repo PROGRESS.md) becomes the base
   `handoff` plus the org patch above (one name, one level). The `_shared/reporting.md` copy-sync
   becomes an `add_files` patch. Decision with default: yes.
4. **Repos adopt layer 3.** In each repo's harness PR: `.agents/overlay.yaml` extending this
   layer, `agentskills render`, `overlay/ci/skills-preview.yml` from the base in CI (rendered diff
   on every PR, no secret), `agentskills check` in `make check`.
5. **Upstream what is generic.** Org skills that turn out generic (for example `exec-plan`,
   `postmortem`, `threat-model`, `learning-card`) move to the base with an org patch for the
   Arffornia details. `propose-skill` decides the layer for new ones.

## Rules
- A change to layer 1 or 2 changes every repo: paste `agentskills preview` from one or two
  consumer repos in the PR.
- Never edit rendered folders; change the base, this layer or the repo overlay, then render.
