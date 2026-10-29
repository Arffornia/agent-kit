#!/usr/bin/env bash
# Shared helpers for the arffornia plugin hooks. Sourced, never executed.
# Portable bash (3.2+): no associative arrays, no mapfile, no ${var,,}.
# Rule: a missing tool means "do nothing quietly", never a failed hook.

HOOK_INPUT=""

# Read the hook's JSON input from stdin once.
read_input() {
  if [ -t 0 ]; then HOOK_INPUT="{}"; else HOOK_INPUT="$(cat)"; fi
}

have() { command -v "$1" >/dev/null 2>&1; }

# json_get <jq filter>: read a field from the hook input. Empty when jq is missing.
json_get() {
  if have jq; then
    printf '%s' "$HOOK_INPUT" | jq -r "$1 // empty" 2>/dev/null || true
  elif have python3; then
    # Minimal fallback for simple dotted paths like .tool_input.command
    printf '%s' "$HOOK_INPUT" | python3 -c '
import json, sys
path = sys.argv[1].lstrip(".").split(".")
try:
    v = json.load(sys.stdin)
    for p in path:
        v = v.get(p) if isinstance(v, dict) else None
    if v is None: v = ""
    print(v if isinstance(v, str) else json.dumps(v))
except Exception:
    pass' "$1" 2>/dev/null || true
  fi
}

# with_timeout <seconds> <cmd...>: run with a deadline, even without coreutils timeout.
with_timeout() {
  local t="$1"; shift
  if have timeout; then timeout "$t" "$@"; return $?; fi
  if have gtimeout; then gtimeout "$t" "$@"; return $?; fi
  "$@" &
  local pid=$!
  ( sleep "$t"; kill "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  local watcher=$!
  local rc=0
  wait "$pid" || rc=$?
  kill "$watcher" 2>/dev/null || true
  return "$rc"
}

# sha1 of stdin, portable (sha1sum, shasum, openssl, cksum as last resort).
hash_stdin() {
  if have sha1sum; then sha1sum | cut -c1-40
  elif have shasum; then shasum | cut -c1-40
  elif have openssl; then openssl sha1 | awk '{print $NF}'
  else cksum | awk '{print $1}'
  fi
}

# The directory Claude is working in: input cwd, else CLAUDE_PROJECT_DIR, else $PWD.
work_dir() {
  local d
  d="$(json_get .cwd)"
  [ -n "$d" ] && [ -d "$d" ] || d="${CLAUDE_PROJECT_DIR:-$PWD}"
  printf '%s' "$d"
}

# repo_root: top level of the git work tree, or fail.
repo_root() {
  have git || return 1
  git -C "$(work_dir)" rev-parse --show-toplevel 2>/dev/null
}

# Per-worktree state dir (check cache, reminders) and shared cache dir (gh data).
state_dir() {
  local g
  g="$(git rev-parse --absolute-git-dir 2>/dev/null)" || return 1
  mkdir -p "$g/claude-harness" 2>/dev/null || return 1
  printf '%s' "$g/claude-harness"
}
cache_dir() {
  local g
  g="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || git rev-parse --absolute-git-dir 2>/dev/null)" || return 1
  mkdir -p "$g/claude-harness/cache" 2>/dev/null || return 1
  printf '%s' "$g/claude-harness/cache"
}

# file_age_s <file>: seconds since last modification (large number when missing).
file_age_s() {
  local f="$1" m now
  [ -f "$f" ] || { echo 999999; return; }
  m="$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  echo $(( now - m ))
}

# Default branch name (origin/HEAD), main as a fallback.
default_branch() {
  local b
  b="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" && { printf '%s' "${b#origin/}"; return; }
  for b in main master; do
    git show-ref --verify --quiet "refs/remotes/origin/$b" && { printf '%s' "$b"; return; }
  done
  printf 'main'
}

# merge base with the default branch, or HEAD when unknown.
base_rev() {
  local d
  d="$(default_branch)"
  git merge-base HEAD "origin/$d" 2>/dev/null || git rev-parse HEAD 2>/dev/null
}

# Is there gh, and is this repo on GitHub?
gh_ok() {
  have gh || return 1
  git remote get-url origin 2>/dev/null | grep -q 'github\.com' || return 1
  [ "${ARFFORNIA_NO_GH:-}" = "1" ] && return 1
  return 0
}

# Print one JSON object with hookSpecificOutput.additionalContext for <event>.
# Falls back to plain stdout (read as context on SessionStart/UserPromptSubmit).
emit_context() {
  local event="$1" text="$2"
  if have jq; then
    jq -nc --arg e "$event" --arg t "$text" '{hookSpecificOutput:{hookEventName:$e, additionalContext:$t}}'
  else
    case "$event" in
      SessionStart|UserPromptSubmit) printf '%s\n' "$text" ;;   # plain stdout is context here
      *) printf '%s\n' "$text" >&2; exit 2 ;;                   # elsewhere stderr+2 reaches Claude
    esac
  fi
}

# Makefile helpers.
has_make_target() {
  [ -f Makefile ] || return 1
  grep -qE "^$1:" Makefile
}
# Does target <t> use $(FILE) / ${FILE} in its recipe?
make_target_takes_file() {
  [ -f Makefile ] || return 1
  awk -v t="$1" '
    $0 ~ "^"t":" { in_t=1; next }
    in_t && /^[^\t#]/ { in_t=0 }
    in_t && /\$[({]FILE[)}]/ { found=1 }
    END { exit found ? 0 : 1 }' Makefile
}
