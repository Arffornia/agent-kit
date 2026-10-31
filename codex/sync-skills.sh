#!/usr/bin/env bash
# Expose the arffornia plugin skills to Codex and other SKILL.md-aware agents through
# `.agents/skills/<name>/` in a repo (Codex scans .agents/skills from the working directory
# up to the repo root, and follows symlinks).
#
# Usage: codex/sync-skills.sh [--copy|--link|--check|--clean] [--from <skills dir>] [<repo dir>]
#   --copy   (default) copy each skill folder; commit the result so Codex cloud tasks get it.
#   --link   symlink each skill to this kit checkout; for local use only, do not commit.
#   --check  exit 1 if the copies differ from the kit (use in CI or a scheduled audit).
#   --clean  remove the skills this script manages (listed in .agents/skills/.agent-kit).
#   --from   skills source (default: plugins/arffornia/skills next to this script).
# Only folders listed in .agents/skills/.agent-kit are ever replaced or removed: skills the
# repo wrote itself are left alone. Portable bash, needs only coreutils + diff.
set -euo pipefail

mode=copy; src=""; repo=""
while [ $# -gt 0 ]; do
  case "$1" in
    --copy|--link|--check|--clean) mode="${1#--}" ;;
    --from) src="$2"; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) repo="$1" ;;
  esac
  shift
done
kit="$(cd "$(dirname "$0")/.." && pwd)"
[ -n "$src" ] || src="$kit/plugins/arffornia/skills"
[ -d "$src" ] || { echo "error: no skills dir at $src" >&2; exit 1; }
src="$(cd "$src" && pwd)"
[ -n "$repo" ] || repo="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
dest="$repo/.agents/skills"
marker="$dest/.agent-kit"
rev="$(git -C "$kit" rev-parse --short HEAD 2>/dev/null || echo unknown)"

managed() { [ -f "$marker" ] && grep -vE '^(#|$)' "$marker" || true; }
skills() { for d in "$src"/*/; do [ -f "$d/SKILL.md" ] && basename "$d"; done; }

case "$mode" in
  clean)
    for n in $(managed); do rm -rf "${dest:?}/$n"; echo "removed .agents/skills/$n"; done
    rm -f "$marker"; rmdir "$dest" 2>/dev/null || true
    exit 0 ;;
  check)
    rc=0
    for n in $(skills); do
      if [ -L "$dest/$n" ]; then continue; fi
      if [ ! -d "$dest/$n" ]; then echo "missing: .agents/skills/$n"; rc=1; continue; fi
      diff -rq "$src/$n" "$dest/$n" >/dev/null || { echo "drift: .agents/skills/$n differs from agent-kit"; rc=1; }
    done
    for n in $(managed); do [ -d "$src/$n" ] || { echo "stale: .agents/skills/$n is no longer in agent-kit"; rc=1; }; done
    [ "$rc" = 0 ] && echo "agent-kit skills in sync"
    [ "$rc" = 0 ] || echo "fix: codex/sync-skills.sh --copy $repo"
    exit "$rc" ;;
esac

mkdir -p "$dest"
old="$(managed)"
# Refuse to overwrite a skill the repo owns.
for n in $(skills); do
  if [ -e "$dest/$n" ] && ! printf '%s\n' "$old" | grep -qx "$n"; then
    echo "skip: .agents/skills/$n exists and is not managed by agent-kit (rename one of them)" >&2
  fi
done
# Drop skills that left the kit.
for n in $old; do [ -d "$src/$n" ] || { rm -rf "${dest:?}/$n"; echo "removed stale .agents/skills/$n"; }; done

todo=""
for n in $(skills); do
  if [ -e "$dest/$n" ] && ! printf '%s\n' "$old" | grep -qx "$n"; then continue; fi
  todo="$todo $n"
done
# Write the marker first, so an interrupted run can still be cleaned or re-run.
{
  echo "# Managed by Arffornia/agent-kit codex/sync-skills.sh ($mode, kit $rev). Do not edit these folders here:"
  echo "# change the skill in Arffornia/agent-kit and re-run the script."
  for n in $todo; do echo "$n"; done
} > "$marker.tmp" && mv "$marker.tmp" "$marker"
for n in $todo; do
  rm -rf "${dest:?}/$n"
  if [ "$mode" = link ]; then ln -s "$src/$n" "$dest/$n"; else cp -R "$src/$n" "$dest/$n"; fi
  echo "$mode: .agents/skills/$n"
done
[ "$mode" = link ] && echo "note: symlinks point into $src; do not commit them (add .agents/skills/ to .git/info/exclude)."
exit 0
