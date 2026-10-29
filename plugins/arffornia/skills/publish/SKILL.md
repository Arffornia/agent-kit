---
name: publish
description: "Publish the current branch as a draft pull request on an Arffornia repo after checking the branch, secrets, make check, review and evidence. Human-invoked only: /arffornia:publish [issue]."
disable-model-invocation: true
argument-hint: "[issue-number]"
---

# Publish the branch as a draft PR

Brian runs this himself. Claude never starts it, because pushing makes work public. Stop at
the first failed step and report it; do not work around it.

1. **Branch.** `git branch --show-current` is not the default branch and follows
   `<type>/<n>-slug` (or `chore/…`, `docs/…` without a number). Otherwise stop.
2. **Clean tree.** `git status --porcelain` is empty. Uncommitted work: ask what to do.
3. **Up to date.** `git fetch origin` and report how far behind the base the branch is
   (`git rev-list --count HEAD..origin/<base>`). Do not rebase without asking.
4. **Secrets.** Scan what will be pushed:
   ```bash
   git diff origin/<base>...HEAD | grep -nEi '(api[_-]?key|secret|token|password|passwd|bearer|BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|xox[bp]-|AKIA[0-9A-Z]{16})' || true
   command -v gitleaks >/dev/null && gitleaks git --log-opts="origin/<base>..HEAD" --no-banner
   ```
   Also no `.env` content, personal paths or internal hostnames. A hit you cannot explain as
   a placeholder (`${CFG_*}`, `.env.example`): stop and show the line.
5. **Check.** `make check`; keep the last lines for the PR. Red: stop.
6. **Review and evidence.** The branch needs an independent review in this session or a
   linked one (`arffornia:reviewer` agent) with no open blocking finding, and for behaviour
   changes the verify evidence (test names, screenshots, GameTest summary). Missing: run the
   reviewer now, or ask Brian whether to publish without it and say so in the PR.
7. **Body.** Fill `.github/pull_request_template.md` (details:
   [references/pr-body.md](references/pr-body.md)): What, Why with `Closes #<n>` (from
   `$ARGUMENTS` or the branch name), How it was tested with real output, Risk & revert,
   Checklist (tick only what is true), then the footer the repo or session requires.
8. **Push and open as draft.** The only push; Claude Code asks before it:
   ```bash
   git push -u origin HEAD
   gh api repos/Arffornia/<repo>/pulls -f title='<conventional title>' -f head=<branch> \
     -f base=<base> -f body="$(cat pr.md)" -F draft=true --jq .html_url
   gh api repos/Arffornia/<repo>/issues/<pr>/labels -f 'labels[]=type: …' -f 'labels[]=area: …'
   ```
9. **Report** per [references/reporting.md](references/reporting.md): the PR URL with a
   one-line summary and CI state, what to read first, open questions. Never merge.
