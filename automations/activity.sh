#!/usr/bin/env bash
# Was there any activity since a date? Used to skip scheduled runs when nothing changed.
#   automations/activity.sh <since-ISO> [repo ...]     (default repos: automations/repos.txt)
# Exit 0: activity found (or a call failed: unreadable is not empty). Exit 3: nothing changed.
# Prints one line per repo with activity. Needs gh (REST only). Owner: $ARFFORNIA_OWNER or Arffornia.
set -uo pipefail
since="${1:-}"; [ -n "$since" ] || { echo "usage: activity.sh <since-ISO> [repo ...]" >&2; exit 2; }
shift
here="$(cd "$(dirname "$0")" && pwd -P)"
owner="${ARFFORNIA_OWNER:-Arffornia}"
gh_bin="${GH_BIN:-gh}"
if [ "$#" -eq 0 ]; then
  set --
  while IFS= read -r line; do
    line="${line%%#*}"; line="$(printf '%s' "$line" | tr -d '[:space:]')"
    [ -n "$line" ] && set -- "$@" "$line"
  done < "$here/repos.txt"
fi
found=0
for r in "$@"; do
  c="$("$gh_bin" api "repos/$owner/$r/commits?since=$since&per_page=1" --jq length 2>/dev/null)" || c=err
  i="$("$gh_bin" api "repos/$owner/$r/issues?since=$since&state=all&per_page=1" --jq length 2>/dev/null)" || i=err
  if [ "$c" = err ] || [ "$i" = err ]; then
    printf '%s: could not read (counted as activity)\n' "$r"; found=1
  elif [ "${c:-0}" != 0 ] || [ "${i:-0}" != 0 ]; then
    printf '%s: commits %s, issues/PRs %s\n' "$r" "$c" "$i"; found=1
  fi
done
[ "$found" = 1 ] && exit 0
exit 3
