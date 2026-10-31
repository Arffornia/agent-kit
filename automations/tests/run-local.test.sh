#!/usr/bin/env bash
# Offline tests for automations/run-local.sh with a fake `claude` (no model, no network).
#   bash automations/tests/run-local.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null
pass=0; fail=0
ok() { pass=$((pass+1)); printf 'PASS %s\n' "$1"; }
ko() { fail=$((fail+1)); printf 'FAIL %s\n     %s\n' "$1" "${2:-}"; }

mkdir -p "$T/bin"
cat > "$T/bin/claude" <<'FAKE'
#!/bin/sh
echo "BG=$CLAUDE_CODE_DISABLE_BACKGROUND_TASKS KEY=${ANTHROPIC_API_KEY:-unset}"
for a in "$@"; do case "$a" in -p) ;; *) printf '[%s]\n' "$(printf '%s' "$a" | head -c 60)" ;; esac; done
FAKE
chmod +x "$T/bin/claude"
git init -q --bare "$T/remote.git"; git init -q -b main "$T/clone"
(cd "$T/clone" && git -c user.email=a@b -c user.name=a commit -q --allow-empty -m init \
  && git remote add origin "$T/remote.git" && git push -q origin main 2>/dev/null && git fetch -q origin \
  && git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main)
cat > "$T/bin/gh" <<'FAKE'
#!/bin/sh
# fake gh: GH_MODE=quiet -> no activity, busy -> one commit, fail -> error
case "${GH_MODE:-quiet}" in quiet) echo 0 ;; busy) echo 1 ;; *) exit 1 ;; esac
FAKE
chmod +x "$T/bin/gh"
export GH_BIN="$T/bin/gh"
run() { ANTHROPIC_API_KEY=leak ARFFORNIA_AUTOMATION_STATE="$T/state" CLAUDE_BIN="$T/bin/claude" bash "$HERE/run-local.sh" "$@" "$T/clone" >"$T/out" 2>&1; RC=$?; }

run weekly-brief
[ "$RC" = 0 ] && ok "weekly-brief run exits 0" || ko "weekly-brief rc" "$RC $(cat "$T/out")"
grep -q 'model sonnet · max 120 turns / 2400 s' "$T/out" && ok "model, turns and a 40 min cap parsed" || ko "parse" "$(head -3 "$T/out")"
grep -q 'BG=1 KEY=unset' "$T/out" && ok "foreground subagents, API key dropped" || ko "env" "$(cat "$T/out")"
[ ! -d "$T/state/weekly-brief.lock" ] && ok "lock released" || ko "lock left"
[ "$(git -C "$T/clone" worktree list | wc -l | tr -d ' ')" = 1 ] && ok "worktree removed" || ko "worktree left"
mkdir -p "$T/state/security-audit.lock"; echo 999999 > "$T/state/security-audit.lock/pid"
run security-audit
grep -q 'removing a stale lock' "$T/out" && grep -q '^\[--disallowedTools\]$' "$T/out" && grep -q '^\[Bash(gh issue \*)' "$T/out" \
  && ok "stale lock recovered; Disallowed tools passed through" || ko "stale/disallowed" "$(cat "$T/out")"
mkdir -p "$T/state/doc-gardener.lock"; echo $$ > "$T/state/doc-gardener.lock/pid"
run doc-gardener
[ "$RC" = 0 ] && grep -q 'already running' "$T/out" && ok "a live lock skips the run" || ko "live lock" "$(cat "$T/out")"
rm -rf "$T/state/doc-gardener.lock"
run nope
[ "$RC" != 0 ] && ok "unknown agent fails" || ko "unknown agent"

# Skip gate: last-ok exists and nothing changed -> no model run
echo 2026-10-01T00:00:00Z > "$T/state/weekly-brief.last-ok"
GH_MODE=quiet run weekly-brief
[ "$RC" = 0 ] && grep -q 'skipped: no activity since 2026-10-01' "$T/out" && ! grep -q 'BG=1' "$T/out" \
  && ok "quiet scope skips the run before the model" || ko "skip gate" "$(cat "$T/out")"
GH_MODE=busy run weekly-brief
grep -q 'BG=1' "$T/out" && ok "activity runs the model" || ko "busy gate" "$(cat "$T/out")"
[ "$(head -c 4 "$T/state/weekly-brief.last-ok")" = "$(date -u +%Y)" ] && ok "last-ok updated after a good run" || ko "last-ok" "$(cat "$T/state/weekly-brief.last-ok")"
echo 2026-10-01T00:00:00Z > "$T/state/weekly-brief.last-ok"
GH_MODE=fail run weekly-brief
grep -q 'BG=1' "$T/out" && ok "an unreadable scope counts as activity" || ko "fail gate" "$(cat "$T/out")"
echo 2026-10-01T00:00:00Z > "$T/state/weekly-brief.last-ok"
ANTHROPIC_API_KEY=leak GH_MODE=quiet ARFFORNIA_AUTOMATION_STATE="$T/state" CLAUDE_BIN="$T/bin/claude" bash "$HERE/run-local.sh" --force weekly-brief "$T/clone" >"$T/out" 2>&1
grep -q 'BG=1' "$T/out" && ok "--force ignores the gate" || ko "force" "$(cat "$T/out")"

# Installers: systemd timers on Linux, launchd on macOS (dry run)
ARFFORNIA_OS=Linux HOME="$T/home" bash "$HERE/install-local.sh" --dry-run >"$T/out" 2>&1
grep -q 'OnCalendar=Fri \*-\*-\* 18:40:00 Europe/Paris' "$T/out" && grep -q 'Persistent=true' "$T/out" && ! grep -q 'deps-upgrade' "$T/out" \
  && ok "systemd timers for enabled agents only" || ko "systemd" "$(head -40 "$T/out")"
ARFFORNIA_OS=Darwin HOME="$T/home" bash "$HERE/install-local.sh" --dry-run --all >"$T/out" 2>&1
grep -q '<key>Day</key><integer>10</integer><key>Hour</key><integer>5</integer><key>Minute</key><integer>35</integer>' "$T/out" \
  && ok "launchd plists with day-of-month schedules" || ko "launchd" "$(grep -n StartCal -A1 "$T/out" | head)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
