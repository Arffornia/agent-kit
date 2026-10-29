#!/usr/bin/env bash
# Stop: verify, don't claim.
#  1. Gate: when the branch has changes, `make check` must pass. A pass is cached per tree state
#     (HEAD + diff + untracked content), so an unchanged tree is never rebuilt.
#  2. Docs reminder: source changed on the branch but AGENTS.md / README.md / docs/ did not.
#  3. Handoff reminder: work looks unfinished (uncommitted changes or open exec-plan items) and
#     PROGRESS.md was not updated.
# Reminders fire once per change set. Loop safety: with stop_hook_active=true the reminders are
# skipped and the gate only re-runs if the tree changed since the last failure.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
read_input

[ "${ARFFORNIA_SKIP_CHECK:-}" = "1" ] && exit 0
have git || exit 0
root="$(repo_root)" || exit 0
cd "$root"
git rev-parse --verify --quiet HEAD >/dev/null || exit 0   # no commit yet
sd="$(state_dir)" || exit 0

active="$(json_get .stop_hook_active)"
base="$(base_rev)"
head="$(git rev-parse HEAD 2>/dev/null || echo none)"
porcelain="$(git status --porcelain 2>/dev/null || true)"

# Nothing on this branch: nothing to verify or remind.
[ -z "$porcelain" ] && [ "$base" = "$head" ] && exit 0

block_with() { # <reason>
  if have jq; then jq -nc --arg r "$1" '{decision:"block", reason:$r}'; exit 0
  else printf '%s\n' "$1" >&2; exit 2; fi
}
feedback() { # <text> : non-error feedback, the conversation continues once
  if have jq; then jq -nc --arg t "$1" '{hookSpecificOutput:{hookEventName:"Stop", additionalContext:$t}}'; exit 0
  else printf '%s\n' "$1" >&2; exit 2; fi
}

tree_key() {
  {
    git rev-parse HEAD
    git diff HEAD
    git ls-files -o --exclude-standard | while IFS= read -r u; do
      [ -f "$u" ] && { printf '%s ' "$u"; hash_stdin < "$u"; }
    done
  } 2>/dev/null | hash_stdin
}

# ---------- 1. make check gate ----------
if has_make_target check && have make; then
  key="$(tree_key)"
  if [ "$(cat "$sd/check-ok" 2>/dev/null || true)" != "$key" ]; then
    if [ "$active" = "true" ] && [ "$(cat "$sd/check-failed" 2>/dev/null || true)" = "$key" ]; then
      : # Claude stopped again without changing anything since the failure: let it stop (it must report red).
    else
      log="$sd/check.log"
      if make check >"$log" 2>&1; then
        printf '%s\n' "$key" > "$sd/check-ok"; rm -f "$sd/check-failed"
      else
        printf '%s\n' "$key" > "$sd/check-failed"
        block_with "make check fails, so the work is not done. Fix it and stop again, or, if it cannot be fixed here, tell the user it is red and why (full log: $log). Last 40 lines:
$(tail -n 40 "$log")"
      fi
    fi
  fi
fi

# Reminders never chain on a hook-driven continuation.
[ "$active" = "true" ] && exit 0

changed="$( { git diff --name-only "$base" 2>/dev/null; git ls-files -o --exclude-standard 2>/dev/null; } | sort -u)"
msgs=""

# ---------- 2. docs reminder ----------
if printf '%s\n' "$changed" | grep -qE '^(src|app|routes|resources|lib|database|charts|k8s|scripts)/|^Makefile$'; then
  if ! printf '%s\n' "$changed" | grep -qE '(^|/)(AGENTS|README)\.md$|^docs/|^\.claude/rules/'; then
    k="$(printf '%s' "$changed" | hash_stdin)"
    if [ "$(cat "$sd/docs-reminded" 2>/dev/null || true)" != "$k" ]; then
      printf '%s\n' "$k" > "$sd/docs-reminded"
      msgs="- Source files changed but AGENTS.md, README.md, docs/ and .claude/rules/ did not. If commands, layout, behaviour or a gotcha changed, update them; otherwise say \"docs unchanged: <reason>\"."
    fi
  fi
fi

# ---------- 3. handoff reminder ----------
unfinished=""
[ -n "$porcelain" ] && unfinished="uncommitted changes"
plan="$(ls -t docs/exec-plans/active/*.md 2>/dev/null | head -1 || true)"
if [ -n "$plan" ] && grep -qE '^- \[ \]' "$plan" 2>/dev/null; then
  unfinished="${unfinished:+$unfinished, }open items in $plan"
fi
if [ -n "$unfinished" ] && ! printf '%s\n' "$changed" | grep -qE '^PROGRESS\.md$'; then
  k="$(printf '%s|%s' "$unfinished" "$(printf '%s' "$porcelain" | hash_stdin)" | hash_stdin)"
  if [ "$(cat "$sd/progress-reminded" 2>/dev/null || true)" != "$k" ]; then
    printf '%s\n' "$k" > "$sd/progress-reminded"
    msgs="${msgs:+$msgs
}- Work looks unfinished ($unfinished) and PROGRESS.md was not updated. Add a short handoff at the top of PROGRESS.md: done, next step, blockers, how to verify. Keep it uncommitted if the user has not asked for a commit."
  fi
fi

[ -n "$msgs" ] && feedback "Before you finish:
$msgs"
exit 0
