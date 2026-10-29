#!/usr/bin/env bash
# PreCompact and SessionEnd: append an automatic handoff entry to PROGRESS.md so the next
# session (or the post-compaction context) knows where things stand. Never commits.
# Writes only when the branch has work (dirty tree or commits ahead of the default branch),
# skips duplicates, and keeps the last 5 automatic entries. Must stay well under 1.5 s.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
read_input

have git || exit 0
root="$(repo_root)" || exit 0
cd "$root"
git rev-parse --verify --quiet HEAD >/dev/null || exit 0   # no commit yet
sd="$(state_dir)" || exit 0

event="$(json_get .hook_event_name)"
why="$(json_get .trigger)"; [ -n "$why" ] || why="$(json_get .reason)"
base="$(base_rev)"
head="$(git rev-parse HEAD 2>/dev/null || echo none)"
porcelain="$(git status --porcelain 2>/dev/null | grep -v ' PROGRESS\.md$' || true)"
[ -z "$porcelain" ] && [ "$base" = "$head" ] && exit 0

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo detached)"
db="$(default_branch)"
ahead="$(git rev-list --count "$base..HEAD" 2>/dev/null || echo 0)"

# TODO/FIXME lines added on this branch (committed or not), as file:line text.
todos="$(git diff -U0 "$base" 2>/dev/null | awk '
  /^\+\+\+ b\// { f = substr($0, 7); next }
  /^@@/ { split($3, a, ","); n = substr(a[1], 2) + 0; next }
  /^\+/ { if ($0 ~ /(TODO|FIXME|XXX|HACK)/) { t = substr($0, 2); gsub(/^[ \t]+/, "", t); printf "%s:%d %s\n", f, n, substr(t, 1, 100) } n++ }
' | grep -v '^PROGRESS\.md:' | head -n 5 || true)"

key="$( { printf '%s|%s|%s|' "$head" "$porcelain" "$todos"; git diff HEAD -- . ':(exclude)PROGRESS.md' 2>/dev/null | hash_stdin; } | hash_stdin)"
[ "$(cat "$sd/handoff-key" 2>/dev/null || true)" = "$key" ] && exit 0

now="$(date -u '+%Y-%m-%d %H:%M UTC')"
n_dirty="$(printf '%s\n' "$porcelain" | grep -c . || true)"
files="$(printf '%s\n' "$porcelain" | awk 'NF { print $NF }' | head -n 10 | paste -sd ',' - | sed 's/,/, /g')"
[ "$n_dirty" -gt 10 ] && files="$files, … (+$((n_dirty - 10)))"
commits="$(git log --oneline --no-decorate -3 "$base..HEAD" 2>/dev/null | sed 's/^/  - /' || true)"

entry="
### Auto handoff $now ($event${why:+: $why}) <!-- auto-handoff -->
- Branch \`$branch\`, $ahead commit(s) ahead of \`$db\`, HEAD \`$(git rev-parse --short HEAD)\`."
[ -n "$commits" ] && entry="$entry
- Branch commits (latest first):
$commits"
if [ "$n_dirty" -gt 0 ]; then
  entry="$entry
- Uncommitted ($n_dirty): $files"
else
  entry="$entry
- Working tree clean."
fi
[ -n "$todos" ] && entry="$entry
- TODOs added on this branch:
$(printf '%s\n' "$todos" | sed 's/^/  - /')"
entry="$entry
- Written automatically by the arffornia plugin; replace it with a real summary (done / next / blockers / verify) when you resume."

if [ ! -f PROGRESS.md ]; then
  printf '# Progress\n\nHandoff notes between sessions. Top: current state (human or agent written). Bottom: automatic entries.\n\n## Now\n\n- (fill in: goal, next step, blockers, how to verify)\n\n## Log\n' > PROGRESS.md
fi

tmp="PROGRESS.md.tmp.$$"
{ cat PROGRESS.md; printf '%s\n' "$entry"; } > "$tmp"
# Keep only the last 5 automatic entries (an entry runs from its heading to the next heading or EOF).
total="$(grep -c '<!-- auto-handoff -->' "$tmp" || true)"
if [ "$total" -gt 5 ]; then
  drop=$((total - 5))
  awk -v drop="$drop" '
    /<!-- auto-handoff -->/ { seen++; skipping = (seen <= drop); if (skipping) next }
    /^#/ && !/<!-- auto-handoff -->/ { skipping = 0 }
    !skipping' "$tmp" > "$tmp.2" && mv "$tmp.2" "$tmp"
fi
mv "$tmp" PROGRESS.md
printf '%s\n' "$key" > "$sd/handoff-key"
exit 0
