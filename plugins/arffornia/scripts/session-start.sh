#!/usr/bin/env bash
# SessionStart: print a compact repo-state card as additionalContext, so the agent starts
# knowing where it is, what to do next and how to verify it (zero-search start).
# Fast path < 2 s: GitHub data comes from a 10-minute cache refreshed in the background.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
read_input

have git || exit 0
root="$(repo_root)" || exit 0
cd "$root"
git rev-parse --verify --quiet HEAD >/dev/null || exit 0   # no commit yet
record_session_tree   # the review gate only asks when this session changed the tree

GH_TTL="${ARFFORNIA_GH_TTL:-600}"

# --- GitHub data (cached) ---------------------------------------------------------------
slug() { # owner/repo from origin
  git remote get-url origin 2>/dev/null | sed -E 's#^.*github\.com[:/]+##; s#\.git$##; s#/+$##'
}

fetch_gh() { # writes $cache/pr-<branch>.txt and $cache/issues.txt
  local cache="$1" branch="$2" repo owner sha prs pr_line runs
  repo="$(slug)"; owner="${repo%%/*}"
  sha="$(git rev-parse HEAD)"
  prs="$(with_timeout 4 gh api "repos/$repo/pulls?state=open&head=$owner:$branch" 2>/dev/null)" || prs="[]"
  pr_line="$(printf '%s' "$prs" | jq -r '.[0] | if . == null then "none" else "#\(.number) \(.title) \(if .draft then "(draft) " else "" end)\(.html_url)" end' 2>/dev/null || echo none)"
  if [ "$pr_line" != "none" ]; then
    runs="$(with_timeout 4 gh api "repos/$repo/commits/$sha/check-runs?per_page=100" 2>/dev/null)" || runs=""
    if [ -n "$runs" ]; then
      pr_line="$pr_line | CI: $(printf '%s' "$runs" | jq -r '
        [.check_runs[] | (if .status != "completed" then "pending" else (.conclusion // "unknown") end)] as $s
        | if ($s|length)==0 then "no checks"
          else ($s | group_by(.) | map("\(length) \(.[0])") | join(", ")) end' 2>/dev/null)"
      local failed
      failed="$(printf '%s' "$runs" | jq -r '[.check_runs[] | select(.conclusion=="failure") | .name] | join(", ")' 2>/dev/null || true)"
      [ -n "$failed" ] && pr_line="$pr_line (failing: $failed)"
    fi
  fi
  printf '%s\n' "$pr_line" > "$cache/pr-$(printf '%s' "$branch" | tr '/' '_').txt.tmp" \
    && mv "$cache/pr-$(printf '%s' "$branch" | tr '/' '_').txt.tmp" "$cache/pr-$(printf '%s' "$branch" | tr '/' '_').txt"

  local issues
  issues="$(with_timeout 4 gh api "repos/$repo/issues?state=open&labels=agent-ready&per_page=100" 2>/dev/null)" || issues=""
  if [ -n "$issues" ]; then
    printf '%s' "$issues" | jq -r '
      [ .[] | select(.pull_request | not)
        | { n: .number, t: .title, u: .html_url,
            p: ([.labels[].name | select(test("^priority: ?P[0-9]")) | capture("P(?<d>[0-9])").d | tonumber] | min // 9),
            e: ([.labels[].name | select(startswith("effort"))] | first // "") } ]
      | sort_by(.p, .n) | .[:3][]
      | "- #\(.n) [\(if .p == 9 then "P?" else "P\(.p)" end)\(if .e != "" then " " + (.e|sub("effort: ?";"")) else "" end)] \(.t) \(.u)"' \
      > "$cache/issues.txt.tmp" 2>/dev/null && mv "$cache/issues.txt.tmp" "$cache/issues.txt"
  fi
}

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo "(detached at $(git rev-parse --short HEAD 2>/dev/null))")"
pr_info=""; issues_info=""
if gh_ok && have jq && cache="$(cache_dir)"; then
  pr_file="$cache/pr-$(printf '%s' "$branch" | tr '/' '_').txt"
  if [ ! -f "$pr_file" ] || [ ! -f "$cache/issues.txt" ]; then
    with_timeout 6 bash -c "$(declare -f fetch_gh slug with_timeout have); fetch_gh '$cache' '$branch'" >/dev/null 2>&1 || true
  elif [ "$(file_age_s "$pr_file")" -gt "$GH_TTL" ] || [ "$(file_age_s "$cache/issues.txt")" -gt "$GH_TTL" ]; then
    # Stale: use it now, refresh for next time. Output redirected so the hook returns at once.
    nohup bash -c "$(declare -f fetch_gh slug with_timeout have); fetch_gh '$cache' '$branch'" >/dev/null 2>&1 &
  fi
  [ -f "$pr_file" ] && pr_info="$(cat "$pr_file")"
  [ -f "$cache/issues.txt" ] && issues_info="$(cat "$cache/issues.txt")"
fi

# --- Local state ------------------------------------------------------------------------
dirty="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
dirty_list="$(git status --porcelain 2>/dev/null | head -4 | sed 's/^/    /')"
ahead=""
db="$(default_branch)"
if git rev-parse --verify --quiet "origin/$db" >/dev/null; then
  ahead="$(git rev-list --count "origin/$db..HEAD" 2>/dev/null || echo 0) ahead / $(git rev-list --count "HEAD..origin/$db" 2>/dev/null || echo 0) behind origin/$db"
fi
commits="$(git log --oneline -5 --no-decorate 2>/dev/null | sed 's/^/  /')"

# Where the work state lives: active exec plan first, else PROGRESS.md.
state_block=""
plan="$(ls -t docs/exec-plans/active/*.md 2>/dev/null | head -1 || true)"
if [ -n "$plan" ]; then
  state_block="Active exec plan: $plan
$(grep -nE '^- \[ \]' "$plan" 2>/dev/null | head -5 | sed 's/^/  /' || true)"
  [ -f PROGRESS.md ] && state_block="$state_block
PROGRESS.md (first lines):
$(head -n 8 PROGRESS.md | sed 's/^/  /')"
elif [ -f PROGRESS.md ]; then
  # Hand-written part (before the automatic entries), then the latest automatic entry.
  manual="$(awk '/<!-- auto-handoff -->/ { exit } { print }' PROGRESS.md | grep -v '^[[:space:]]*$' | head -n 15 || true)"
  state_block="PROGRESS.md (first 15 lines):
$(printf '%s\n' "$manual" | sed 's/^/  /')"
  last_auto="$(awk '/<!-- auto-handoff -->/ { buf = "" ; on = 1 } on { buf = buf $0 "\n" } END { printf "%s", buf }' PROGRESS.md \
    | grep -v '^- Written automatically' | head -n 7 | sed 's/ <!-- auto-handoff -->//' || true)"
  [ -n "$last_auto" ] && state_block="$state_block
Latest automatic handoff:
$(printf '%s\n' "$last_auto" | sed 's/^/  /')"
fi

# Verify commands, parsed from the Makefile (target + ## comment when present).
verify=""
if [ -f Makefile ]; then
  for t in check test lint fmt build gametest e2e; do
    line="$(grep -E "^$t:" Makefile | head -1 || true)"
    [ -n "$line" ] || continue
    desc="$(printf '%s' "$line" | sed -nE 's/.*## *(.*)$/\1/p')"
    [ -z "$desc" ] && desc="$(grep -B1 -E "^$t:" Makefile | head -1 | sed -nE 's/^## *[a-z-]+: *(.*)$/\1/p; s/^# *(.*)$/\1/p' || true)"
    deps="$(printf '%s' "$line" | sed -E 's/^[^:]+:([^#]*).*/\1/' | xargs 2>/dev/null || true)"
    v="  make $t"
    [ -n "$deps" ] && [ "$t" = check ] && v="$v (= $deps)"
    [ -n "$desc" ] && v="$v — $desc"
    verify="$verify
$v"
  done
fi
[ -x scripts/init ] && verify="$verify
  scripts/init — fresh clone to green"

# --- Card -------------------------------------------------------------------------------
card="Repo state card (arffornia harness, generated at session start)
Repo: $(basename "$root")  Branch: $branch${ahead:+  ($ahead)}
Uncommitted files: $dirty"
[ "$dirty" -gt 0 ] && card="$card
$dirty_list"
card="$card
Last commits:
$commits"
[ -n "$pr_info" ] && card="$card
PR for this branch: $pr_info"
if [ -n "$verify" ]; then
  card="$card
Verify with:$verify"
else
  card="$card
Verify with: no Makefile found; read AGENTS.md for the commands."
fi
[ -n "$issues_info" ] && card="$card
Top agent-ready issues:
$issues_info"
[ -n "$state_block" ] && card="$card
$(printf '%s\n' "$state_block" | head -n 18)"
case "$branch" in
  main|master) card="$card
Note: the current branch is $branch. Work happens on a branch: git switch -c <type>/<n>-<slug>." ;;
esac

# Hard cap at ~40 lines so the card stays a card.
card="$(printf '%s\n' "$card" | head -n 40)"
emit_context SessionStart "$card"
