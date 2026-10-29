#!/usr/bin/env bash
# PostToolUse after Edit/Write: format, then lint, only the edited file.
# Order of preference: the repo's `make fmt FILE=` / `make lint FILE=` (when the recipe uses
# $(FILE)), then a per-stack fallback that runs only if the tool is already installed locally.
# Findings go back to Claude as additionalContext (concise, capped). Never blocks.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
read_input

f="$(json_get .tool_input.file_path)"
[ -n "$f" ] || f="$(json_get .tool_input.notebook_path)"
[ -n "$f" ] && [ -f "$f" ] || exit 0
have git || exit 0
root="$(repo_root)" || exit 0
root="$(cd "$root" && pwd -P)"; f="$(phys_path "$f")"
case "$f" in "$root"/*) ;; *) exit 0 ;; esac
cd "$root"
rel="${f#"$root"/}"
case "$rel" in vendor/*|node_modules/*|build/*|out/*|dist/*|site/*|.git/*) exit 0 ;; esac

T="${ARFFORNIA_POST_EDIT_TIMEOUT:-40}"
ext="${rel##*.}"
notes=""
before="$(hash_stdin < "$f")"

bin() { # project-local binary first, then PATH
  if [ -x "node_modules/.bin/$1" ]; then printf '%s' "node_modules/.bin/$1"
  elif [ -x "vendor/bin/$1" ]; then printf '%s' "vendor/bin/$1"
  elif have "$1"; then command -v "$1"
  else return 1; fi
}
has_prettier_config() { ls .prettierrc* prettier.config.* >/dev/null 2>&1 || grep -q '"prettier"' package.json 2>/dev/null; }
has_eslint_config() { ls eslint.config.* .eslintrc* >/dev/null 2>&1; }

# ---------- format ----------
fmt_out=""; fmt_rc=0
if has_make_target fmt && make_target_takes_file fmt; then
  fmt_out="$(with_timeout "$T" make -s fmt FILE="$rel" 2>&1)" || fmt_rc=$?
else
  case "$ext" in
    php) if b="$(bin pint)"; then fmt_out="$(with_timeout "$T" "$b" -q "$rel" 2>&1)" || fmt_rc=$?; fi ;;
    js|mjs|cjs|ts|tsx|jsx|vue|css|scss|json|html)
      if has_prettier_config && b="$(bin prettier)"; then fmt_out="$(with_timeout "$T" "$b" --write --log-level warn "$rel" 2>&1)" || fmt_rc=$?; fi ;;
    tf) if b="$(bin terraform)"; then fmt_out="$(with_timeout "$T" "$b" fmt "$rel" 2>&1)" || fmt_rc=$?; fi ;;
    sh|bash) if b="$(bin shfmt)" && [ -f .editorconfig ]; then fmt_out="$(with_timeout "$T" "$b" -w "$rel" 2>&1)" || fmt_rc=$?; fi ;;
  esac
fi
if [ "$fmt_rc" -ne 0 ]; then
  notes="Formatter failed on $rel (exit $fmt_rc):
$(printf '%s' "$fmt_out" | tail -n 8)"
elif [ -f "$f" ] && [ "$(hash_stdin < "$f")" != "$before" ]; then
  notes="Formatted $rel (file changed on disk: re-read it before the next Edit)."
fi

# ---------- lint ----------
lint_out=""; lint_rc=0
if has_make_target lint && make_target_takes_file lint; then
  lint_out="$(with_timeout "$T" make -s lint FILE="$rel" 2>&1)" || lint_rc=$?
else
  case "$ext" in
    php) if have php; then lint_out="$(with_timeout 10 php -l "$rel" 2>&1)" || lint_rc=$?; fi ;;
    js|mjs|cjs|ts|tsx|jsx|vue)
      if has_eslint_config && b="$(bin eslint)"; then lint_out="$(with_timeout "$T" "$b" --no-warn-ignored --format unix "$rel" 2>&1)" || lint_rc=$?; fi ;;
    sh|bash) if b="$(bin shellcheck)"; then lint_out="$(with_timeout 10 "$b" -f gcc "$rel" 2>&1)" || lint_rc=$?; fi ;;
    json) if have jq; then lint_out="$(jq empty "$rel" 2>&1)" || lint_rc=$?; fi ;;
    yml|yaml)
      if b="$(bin yamllint)"; then lint_out="$(with_timeout 10 "$b" -f parsable "$rel" 2>&1)" || lint_rc=$?
      elif have yq; then lint_out="$(yq eval-all 'true' "$rel" 2>&1 >/dev/null)" || lint_rc=$?; fi ;;
  esac
fi
if [ "$lint_rc" -ne 0 ] && [ -n "$lint_out" ]; then
  n="$(printf '%s\n' "$lint_out" | wc -l | tr -d ' ')"
  notes="${notes:+$notes
}Lint findings in $rel ($n lines, first 25). Fix them now, while the change is fresh:
$(printf '%s\n' "$lint_out" | head -n 25)"
fi

[ -n "$notes" ] || exit 0
emit_context PostToolUse "$notes"
