#!/usr/bin/env bash
# Stop: verify, don't claim.
#  1. Gate: when the branch has changes, `make check` must pass. A pass is cached per tree state
#     (HEAD + diff + untracked content), so an unchanged tree is never rebuilt.
#  2. Docs reminder: source changed on the branch but AGENTS.md / README.md / docs/ did not.
#  3. Handoff reminder: work looks unfinished (uncommitted changes or open exec-plan items) and
#     PROGRESS.md was not updated.
#  R. Review gate (after the check passes): when this session changed the work tree (vs the tree
#     SessionStart recorded), the branch changes at least ARFFORNIA_REVIEW_MIN_LINES lines of code
#     (default 10; docs, lockfiles and generated files excluded) and the current tree has no review
#     stamp, block ONCE per tree state with "run the
#     arffornia:review skill". The skill reviews with fresh subagents and writes the stamp
#     (scripts/review-stamp.sh). Fixes after a review change the tree, so the next stop asks for a
#     delta review; at most ARFFORNIA_REVIEW_MAX_ROUNDS rounds (default 3) per branch.
# Reminders fire once per change set. Loop safety: with stop_hook_active=true the reminders are
# skipped, the check gate only re-runs if the tree changed since the last failure, and the review
# gate never asks twice for the same tree.
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

# ---------- R. review gate ----------
review_gate() {
  [ "${ARFFORNIA_SKIP_REVIEW:-}" = "1" ] && return 0
  local min="${ARFFORNIA_REVIEW_MIN_LINES:-10}" cap="${ARFFORNIA_REVIEW_MAX_ROUNDS:-3}"
  local lines tree st branch round blocking
  lines="$(code_lines_changed "$base")"
  [ "${lines:-0}" -ge "$min" ] || return 0
  tree="$(snapshot_tree)" || return 0
  # A session that changed nothing (questions, reading, reporting) is never asked to review.
  local sf
  if sf="$(session_tree_file)" && [ -f "$sf" ] && [ "$(cat "$sf")" = "$tree" ]; then return 0; fi
  st="$sd/review-stamp"
  branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo detached)"
  round=0
  [ "$(kv_get "$st" branch)" = "$branch" ] && round="$(kv_get "$st" round)"
  case "$round" in ''|*[!0-9]*) round=0 ;; esac
  if [ "$(kv_get "$st" tree)" = "$tree" ]; then
    blocking="$(kv_get "$st" blocking)"
    if [ "${blocking:-0}" != "0" ] && [ "$(cat "$sd/review-blocking-told" 2>/dev/null || true)" != "$tree" ]; then
      printf '%s\n' "$tree" > "$sd/review-blocking-told"
      feedback "The review of this tree confirmed $blocking blocking finding(s) and the tree has not changed since. Fix them (the next stop asks for a short delta review), or tell the user which ones you left open and why. Label each finding: bash \"\${CLAUDE_PLUGIN_ROOT}/scripts/review-stamp.sh\" label <id> fixed|wrong|intended|noise."
    fi
    return 0
  fi
  [ "$(cat "$sd/review-asked" 2>/dev/null || true)" = "$tree" ] && return 0   # asked once for this tree
  printf '%s\n' "$tree" > "$sd/review-asked"
  if [ "$round" -ge "$cap" ]; then
    feedback "Review round cap reached ($round/$cap on $branch): the changes made after the last review are not independently reviewed. Say so in your report (\"not re-reviewed after round $round\") and suggest splitting the change if it keeps moving."
  fi
  local what="Run the arffornia:review skill now (in-session mode)"
  [ "$round" -gt 0 ] && what="Run the arffornia:review skill now for round $((round+1))/$cap: a delta review of what changed since the last review (the skill reads the range from the stamp)"
  block_with "Before handing back: this session changed code, the branch now differs from its base by $lines lines of code, and the current tree has no independent review. The repository owner's standing rule (AGENTS.md: review before handing back) is that every such change gets one, even when the prompt did not mention it. $what. It sends fresh finder and verifier subagents over the diff (they never saw this conversation), keeps only confirmed findings and writes a review stamp. Then fix the confirmed blocking and major findings, or explain in your report why not. If the user asked for no review, they can set ARFFORNIA_SKIP_REVIEW=1."
}
review_gate

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
