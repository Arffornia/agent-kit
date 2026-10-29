#!/usr/bin/env bash
# Copy the shared references into every skill that uses them, or check they are in sync.
#   plugins/arffornia/skills/_shared/sync.sh          # write copies
#   plugins/arffornia/skills/_shared/sync.sh --check  # exit 1 when a copy differs (CI / evals)
# Skills stay self-contained (each folder works alone under the open SKILL.md standard and the
# Codex sync), while the text has one source of truth here.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
SKILLS=$(dirname "$HERE")
# shared file -> skills that report work and therefore carry it
declare -A USERS=(
  [reporting.md]="cadrage challenge debug exec-plan handoff harness-audit i18n-sync mc-gametest mc-machine mc-ui-check modpack-change noodle-arffornia onboard postmortem prio publish release-notes review threat-model upgrade-deps verify work-ticket"
)
rc=0
for f in "${!USERS[@]}"; do
  for s in ${USERS[$f]}; do
    dst="$SKILLS/$s/references/$f"
    [ -d "$SKILLS/$s" ] || { echo "missing skill $s" >&2; rc=1; continue; }
    if [ "${1:-}" = "--check" ]; then
      cmp -s "$HERE/$f" "$dst" || { echo "out of sync: $dst (run _shared/sync.sh)" >&2; rc=1; }
    else
      mkdir -p "$(dirname "$dst")"; cp "$HERE/$f" "$dst"
    fi
  done
done
[ "${1:-}" = "--check" ] && [ $rc -eq 0 ] && echo "shared references in sync"
exit $rc
