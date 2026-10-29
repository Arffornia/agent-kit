---
name: publish
description: Publish the current branch as a draft pull request on an Arffornia repo after verifying the branch and running make check. Human-invoked only.
disable-model-invocation: true
argument-hint: "[issue-number]"
---

# Publish the branch as a draft PR

Brian runs this himself (`/arffornia:publish [issue]`). Claude never starts it on its own, because
pushing makes work public. Stop at the first failed step and report it; do not work around it.

1. **Branch.** `git branch --show-current` must not be `main`/`master`/the default branch and must
   follow `<type>/<n>-slug` (or `chore/…`, `docs/…` without a number). Otherwise stop.
2. **Clean tree.** `git status --porcelain` is empty. Uncommitted work: ask what to do.
3. **Up to date.** `git fetch origin` and report how many commits the branch is behind its base.
   Do not rebase without asking.
4. **Secrets.** `git diff origin/<base>...HEAD` contains no tokens, keys, `.env` content or
   personal paths. If in doubt, stop and show the line.
5. **Check.** Run `make check` and keep the last lines of output for the PR. Red: stop.
6. **Body.** Fill `.github/pull_request_template.md`:
   - **What**: the change as behaviour, 1-5 bullets.
   - **Why**: the problem, then `Closes #<n>` (from `$ARGUMENTS` or the branch name).
   - **How it was tested**: the commands you ran and their real output (the `make check` tail).
   - **Risk & revert**: what could break, who notices, how to undo.
   - **Checklist**: tick only what is true.
   - End with the PR footer the repo or session requires.
7. **Push and open as draft.** This is the only push, and Claude Code will ask before it:
   ```bash
   git push -u origin HEAD
   gh api repos/Arffornia/<repo>/pulls -f title='<conventional title>' -f head=<branch> \
     -f base=<base> -f body="$(cat pr.md)" -F draft=true
   gh api repos/Arffornia/<repo>/issues/<pr>/labels -f 'labels[]=type: …' -f 'labels[]=area: …'
   ```
8. Report the PR URL and anything a reviewer should look at first. Never merge.
