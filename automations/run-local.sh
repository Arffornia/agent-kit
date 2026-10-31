#!/usr/bin/env bash
# Run one automation prompt headless with the logged-in `claude` CLI, from cron, launchd or systemd.
# No API key, no GitHub secret: it uses Brian's `claude` login (keychain) and `gh` login.
#
#   automations/run-local.sh [--force] <agent> [repo-dir]
#     --force     run even when nothing changed since the last successful run (manual runs)
#     <agent>     a prompt file in this folder, without .md (harness-feedback, doc-gardener, ...)
#     [repo-dir]  a local clone the run starts in (default: the current directory); the run works in
#                 a fresh detached worktree of its default branch, removed afterwards
#
# Model and turn cap come from the prompt file ("Model: Opus", "Hard cap: ... / 400 turns").
# A "Disallowed tools:" line in the prompt is passed to --disallowedTools (e.g. security-audit
# forbids GitHub writes). The run is stopped at the prompt's hard cap ("2 h", "40 min"; default 3 h).
# Skip gate: when the agent ran successfully before ($STATE/<agent>.last-ok) and activity.sh finds
# no commit, issue or PR since then in the agent's scope (schedule.tsv), the run is skipped before
# the model starts: no tokens spent. A failed check counts as activity.
# Env: ARFFORNIA_PERMISSION_MODE (default auto), ARFFORNIA_AUTOMATION_STATE (logs, lock, last-ok),
#      ARFFORNIA_FORCE=1 (same as --force), ARFFORNIA_PLAYBOOK (agent-playbook checkout, for the
#      skill-candidate scan), CLAUDE_BIN (default claude). Portable: macOS bash 3.2 + BSD tools, Linux.
set -euo pipefail

die() { printf 'run-local: %s\n' "$*" >&2; exit 1; }
force="${ARFFORNIA_FORCE:-0}"
if [ "${1:-}" = "--force" ]; then force=1; shift; fi
agent="${1:-}"; [ -n "$agent" ] || die "usage: run-local.sh [--force] <agent> [repo-dir]"
repo="${2:-$PWD}"
here="$(cd "$(dirname "$0")" && pwd -P)"
prompt="$here/$agent.md"
[ -f "$prompt" ] && [ "$agent" != README ] || die "no prompt $prompt"
claude_bin="${CLAUDE_BIN:-claude}"
command -v "$claude_bin" >/dev/null 2>&1 || die "claude CLI not found (npm i -g @anthropic-ai/claude-code, then claude /login)"
command -v git >/dev/null 2>&1 || die "git not found"

model="$(sed -nE 's/.*Model: (Opus|Sonnet|Haiku|Fable).*/\1/p' "$prompt" | head -n 1 | tr '[:upper:]' '[:lower:]')"
[ -n "$model" ] || model=opus
turns="$(sed -nE 's/.*Hard cap: [^/]*\/ *([0-9]+) turns.*/\1/p' "$prompt" | head -n 1)"
[ -n "$turns" ] || turns=200
# Hard cap: "2 h", "40 min" (the first number + unit after "Hard cap:"); default 3 h.
cap_n="$(sed -nE 's/.*Hard cap: *([0-9]+) *(h|min).*/\1/p' "$prompt" | head -n 1)"
cap_u="$(sed -nE 's/.*Hard cap: *([0-9]+) *(h|min).*/\2/p' "$prompt" | head -n 1)"
case "$cap_u" in h) cap_s=$(( cap_n * 3600 )) ;; min) cap_s=$(( cap_n * 60 )) ;; *) cap_s=10800 ;; esac
disallowed="$(sed -nE 's/^Disallowed tools: *//p' "$prompt" | head -n 1)"

state="${ARFFORNIA_AUTOMATION_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/arffornia-automations}"
mkdir -p "$state"
lock="$state/$agent.lock"
if ! mkdir "$lock" 2>/dev/null; then
  old="$(cat "$lock/pid" 2>/dev/null || true)"
  if [ -n "$old" ] && kill -0 "$old" 2>/dev/null; then
    printf 'run-local: %s is already running (pid %s)\n' "$agent" "$old" >&2; exit 0
  fi
  printf 'run-local: removing a stale lock (pid %s is gone)\n' "${old:-?}" >&2
  rm -rf "$lock"; mkdir "$lock" || die "cannot take the lock $lock"
fi
printf '%s\n' "$$" > "$lock/pid"
wt=""; watchdog=""
cleanup() {
  if [ -n "$wt" ] && [ -d "$wt" ]; then git -C "$repo" worktree remove --force "$wt" >/dev/null 2>&1 || true; fi
  if [ -n "${watchdog:-}" ]; then kill "$watchdog" 2>/dev/null || true; fi
  rm -rf "$lock" 2>/dev/null || true
}
trap cleanup EXIT

# The subscription login, never an API key: an exported key would take precedence and bill the API.
if [ -n "${ANTHROPIC_API_KEY:-}" ] || [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
  printf 'run-local: ignoring ANTHROPIC_API_KEY/ANTHROPIC_AUTH_TOKEN for this run (uses the claude login)\n' >&2
  unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
fi

git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || die "$repo is not a git clone"

# Skip gate (no model, no tokens): nothing changed in the agent's scope since its last good run.
started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
lastok="$state/$agent.last-ok"
scope="$(awk -F '\t' -v a="$agent" '$1==a {print $5}' "$here/schedule.tsv" 2>/dev/null | head -n 1)"
if [ "$force" != 1 ] && [ -s "$lastok" ] && [ "$scope" != self ]; then
  since="$(head -n 1 "$lastok")"
  if [ "$scope" = org ]; then set --; else set -- "${scope:-agent-kit}"; fi
  act=0; "$here/activity.sh" "$since" "$@" >"$state/$agent.activity" 2>&1 || act=$?
  if [ "$act" = 3 ]; then
    printf 'run-local: %s skipped: no activity since %s (use --force to run anyway)\n' "$agent" "$since" >&2
    exit 0
  fi
fi
git -C "$repo" fetch -q origin 2>/dev/null || printf 'run-local: fetch failed, using the local refs\n' >&2
def="$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
wt="$state/wt-$agent-$stamp"
git -C "$repo" worktree add -q --detach "$wt" "$def" || die "cannot create a worktree from $def"

# Deterministic transcript scan for "done twice -> skill" (harness-feedback reads the result).
if [ "$agent" = harness-feedback ]; then
  scan=""
  for d in "${ARFFORNIA_PLAYBOOK:-}" "$HOME/.local/share/agent-playbook"; do
    if [ -n "$d" ] && [ -f "$d/skills/propose-skill/scripts/repeat_scan.py" ]; then scan="$d/skills/propose-skill/scripts/repeat_scan.py"; break; fi
  done
  if [ -n "$scan" ] && command -v python3 >/dev/null 2>&1; then
    sargs=""; [ -s "$lastok" ] && sargs="--since $(head -c 10 "$lastok")"
    # shellcheck disable=SC2086
    python3 -I "$scan" $sargs >"$wt/.skill-candidates.md" 2>/dev/null || rm -f "$wt/.skill-candidates.md"
  fi
fi

log="$state/$agent-$stamp.log"
printf 'run-local: %s · model %s · max %s turns / %s s · %s @ %s · log %s\n' "$agent" "$model" "$turns" "$cap_s" "$repo" "$def" "$log" >&2
set -- -p "$(cat "$prompt")" --model "$model" --max-turns "$turns" \
  --permission-mode "${ARFFORNIA_PERMISSION_MODE:-auto}" --output-format text
[ -n "$disallowed" ] && set -- "$@" --disallowedTools "$disallowed"
rc=0
# Foreground subagents: a background one can let a headless run end before it reports.
(cd "$wt" && CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 exec "$claude_bin" "$@") >"$log" 2>&1 &
pid=$!
# Watchdog with its own stdio, so it never holds the caller's stdout (cron mail, pipes) open.
( sleep "$cap_s"; kill "$pid" 2>/dev/null && printf 'run-local: hard cap of %s s reached, run stopped\n' "$cap_s" >>"$log" ) </dev/null >/dev/null 2>&1 &
watchdog=$!
wait "$pid" || rc=$?
tail -n 20 "$log"
if [ "$rc" = 0 ]; then printf '%s\n' "$started" > "$lastok"; fi
exit "$rc"
