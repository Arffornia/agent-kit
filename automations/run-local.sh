#!/usr/bin/env bash
# Run one automation prompt headless with the logged-in `claude` CLI, from cron, launchd or systemd.
# No API key, no GitHub secret: it uses Brian's `claude` login (keychain) and `gh` login.
#
#   automations/run-local.sh <agent> [repo-dir]
#     <agent>     a prompt file in this folder, without .md (harness-feedback, doc-gardener, ...)
#     [repo-dir]  a local clone the run starts in (default: the current directory); the run works in
#                 a fresh detached worktree of its default branch, removed afterwards
#
# Model and turn cap come from the prompt file ("Model: Opus", "Hard cap: ... / 400 turns").
# Env: ARFFORNIA_PERMISSION_MODE (default auto), ARFFORNIA_AUTOMATION_STATE (logs, lock),
#      CLAUDE_BIN (default claude). Portable: macOS bash 3.2 + BSD tools, Linux.
set -euo pipefail

die() { printf 'run-local: %s\n' "$*" >&2; exit 1; }
agent="${1:-}"; [ -n "$agent" ] || die "usage: run-local.sh <agent> [repo-dir]"
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

state="${ARFFORNIA_AUTOMATION_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/arffornia-automations}"
mkdir -p "$state"
lock="$state/$agent.lock"
mkdir "$lock" 2>/dev/null || { printf 'run-local: %s is already running (%s)\n' "$agent" "$lock" >&2; exit 0; }
wt=""
cleanup() {
  if [ -n "$wt" ] && [ -d "$wt" ]; then git -C "$repo" worktree remove --force "$wt" >/dev/null 2>&1 || true; fi
  rmdir "$lock" 2>/dev/null || true
}
trap cleanup EXIT

# The subscription login, never an API key: an exported key would take precedence and bill the API.
if [ -n "${ANTHROPIC_API_KEY:-}" ] || [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
  printf 'run-local: ignoring ANTHROPIC_API_KEY/ANTHROPIC_AUTH_TOKEN for this run (uses the claude login)\n' >&2
  unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
fi

git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || die "$repo is not a git clone"
git -C "$repo" fetch -q origin 2>/dev/null || printf 'run-local: fetch failed, using the local refs\n' >&2
def="$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
wt="$state/wt-$agent-$stamp"
git -C "$repo" worktree add -q --detach "$wt" "$def" || die "cannot create a worktree from $def"

log="$state/$agent-$stamp.log"
printf 'run-local: %s · model %s · max %s turns · %s @ %s · log %s\n' "$agent" "$model" "$turns" "$repo" "$def" "$log" >&2
rc=0
(cd "$wt" && "$claude_bin" -p "$(cat "$prompt")" --model "$model" --max-turns "$turns" \
  --permission-mode "${ARFFORNIA_PERMISSION_MODE:-auto}" --output-format text) >"$log" 2>&1 || rc=$?
tail -n 20 "$log"
exit "$rc"
