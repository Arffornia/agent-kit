#!/usr/bin/env bash
# Static portability check for every shell script and Makefile the kit ships: they must run on
# macOS (bash 3.2, BSD sed/grep/date/stat) and Linux (bash 5, GNU tools). CI also runs the hook
# suite with macOS's own /bin/bash 3.2; this catches the usual traps earlier and offline.
#
#   bash plugins/arffornia/scripts/tests/portability.sh [files...]   (default: every tracked script)
#
# A line that really needs one of these (for example a GNU form with a BSD fallback on the same
# line) ends with the comment `# portable-ok`. A file meant for Linux only (cloud/setup.sh runs in
# the Ubuntu cloud VM) starts a line with that marker (`# portability: linux-only`) in its first 10 lines.
set -uo pipefail
if [ $# -gt 0 ]; then files="$(printf '%s\n' "$@")"
else
  cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 1
  files="$(git ls-files | while IFS= read -r f; do
    case "$f" in
      (*.sh|*/Makefile|Makefile|*.mk|templates/scripts/init) printf '%s\n' "$f" ;;
      (*) [ -f "$f" ] && head -n 1 "$f" 2>/dev/null | grep -qE '^#!.*\b(ba)?sh\b' && printf '%s\n' "$f" ;;
    esac
  done)"
fi

# One rule per line: <extended regex> TAB <why> TAB <fix>. Matched against non-comment lines.
rules_file="$(mktemp "${TMPDIR:-/tmp}/portability.XXXXXX")"; trap 'rm -f "$rules_file"' EXIT
# A heredoc inside $( ) trips bash 3.2 when the text holds parentheses or quotes: write a file.
cat > "$rules_file" <<'RULES'
\bdeclare -A\b	associative arrays need bash 4	use parallel indexed arrays or a temp file
\blocal -A\b	associative arrays need bash 4	use parallel indexed arrays or a temp file
\b(mapfile|readarray)\b	mapfile/readarray need bash 4	while IFS= read -r l; do arr+=("$l"); done <<EOF ... EOF
\$\{[A-Za-z_][A-Za-z0-9_]*(,,|\^\^)	case conversion needs bash 4	tr '[:upper:]' '[:lower:]'
\bwait -n\b	wait -n needs bash 4.3	wait for each pid
&>>	&>> needs bash 4	>>file 2>&1
[^|]\|&([^&]|$)	|& needs bash 4	2>&1 |
\bcoproc\b	coproc needs bash 4	a named pipe or a temp file
\$\{[A-Za-z_][A-Za-z0-9_]*@[QEPAa]\}	${var@Q} needs bash 4.4	printf %q
\bsed -i( |$|[\'"])	in-place sed without a suffix is GNU-only	sed -i.bak '...' file && rm -f file.bak
\bgrep (-[a-zA-Z]*P|--perl)	grep -P is GNU-only	grep -E
\breadlink -f\b	readlink -f is missing before macOS 12.3	cd "$(dirname "$f")" && pwd -P
\brealpath\b	realpath is missing on older macOS	cd "$(dirname "$f")" && pwd -P
\bdate -d\b	date -d is GNU-only	date -u +%s and arithmetic, or python3
\bdate --	GNU long options for date	POSIX date options
\bstat -c\b	stat -c is GNU-only	stat -c ... || stat -f ... on one line, marked # portable-ok
\bsort -V\b	sort -V is missing on older macOS	sort -t. -k1,1n -k2,2n -k3,3n
\bxargs -r\b	xargs -r is GNU-only	guard with [ -n "$list" ]
-printf\b	find -printf is GNU-only	find ... -exec, or a while loop
\bbase64 -w\b	base64 -w is GNU-only	base64 | tr -d '\n'
\bnproc\b	nproc is GNU-only	getconf _NPROCESSORS_ONLN
(^|[;&|[:space:]])tac\b	tac is GNU-only	tail -r (BSD) or awk
\bhead -n -[0-9]	negative head counts are GNU-only	sed '$d' or awk
\bmktemp --	GNU long options for mktemp	mktemp "${TMPDIR:-/tmp}/name.XXXXXX"
(^|[;&|(!{[:space:]])timeout 	coreutils timeout is not on macOS	with_timeout from lib.sh (falls back to gtimeout, then a watcher)
RULES

fail=0; checked=0
while IFS= read -r f; do
  [ -n "$f" ] && [ -f "$f" ] || continue
  head -n 10 "$f" | grep -q '^# portability: linux-only' && continue
  checked=$((checked+1))
  while IFS="$(printf '\t')" read -r pat why fix; do
    [ -n "$pat" ] || continue
    # Lines inside a <<'RULES' heredoc are data (this file's own rule table), not code.
    hits="$(awk '/<<.RULES.$/ {d=1; print ""; next} /^RULES$/ {d=0; print ""; next} {print d ? "" : $0}' "$f" \
      | grep -nE -- "$pat" 2>/dev/null | grep -v 'portable-ok' | grep -vE '^[0-9]+:[[:space:]]*#' || true)"
    [ -n "$hits" ] || continue
    while IFS= read -r h; do
      printf '%s:%s\n  %s. Fix: %s\n' "$f" "$h" "$why" "$fix"
      fail=$((fail+1))
    done <<EOF
$hits
EOF
  done < "$rules_file"
done <<EOF
$files
EOF

printf '\nportability: %d file(s) checked, %d problem(s)\n' "$checked" "$fail"
[ "$fail" = 0 ]
