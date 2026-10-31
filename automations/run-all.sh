#!/usr/bin/env bash
# Manual "run everything now": every enabled automation, one after the other, locally.
#   automations/run-all.sh [--if-changed] [--all] [repo-dir]
#     default        force every agent marked enabled=yes in schedule.tsv (ignores the skip gate)
#     --if-changed   keep the skip gate (only agents whose scope changed run)
#     --all          include agents marked after-two-good-runs
# For cloud scheduled tasks, the same is "Run now" on each task at claude.ai/code/routines.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"
force=--force; all=0; repo="$PWD"
for a in "$@"; do
  case "$a" in
    --if-changed) force="" ;;
    --all) all=1 ;;
    -*) echo "unknown option $a" >&2; exit 2 ;;
    *) repo="$a" ;;
  esac
done
rc=0
while IFS="$(printf '\t')" read -r agent _cad _cal _ld _scope enabled; do
  case "$agent" in ''|'#'*) continue ;; esac
  if [ "$enabled" != yes ] && [ "$all" != 1 ]; then continue; fi
  printf '== %s\n' "$agent"
  # shellcheck disable=SC2086
  bash "$here/run-local.sh" $force "$agent" "$repo" || { rc=1; printf 'run-all: %s failed\n' "$agent" >&2; }
done < "$here/schedule.tsv"
exit "$rc"
