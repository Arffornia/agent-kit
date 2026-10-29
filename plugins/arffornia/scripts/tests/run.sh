#!/usr/bin/env bash
# Offline test suite for the plugin hook scripts. Builds a throwaway git repo (with a local
# bare "origin") under a temp dir and feeds each hook the JSON Claude Code would send.
# Usage: bash plugins/arffornia/scripts/tests/run.sh      (needs bash, git, jq, make)
set -uo pipefail
S="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export ARFFORNIA_NO_GH=1 GIT_CONFIG_GLOBAL=/dev/null
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'PASS %s\n' "$1"; }
ko()  { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '     %s\n' "$2"; }

# ---------- fixture ----------
git init -q --bare "$T/remote.git"
git init -q -b main "$T/repo"; cd "$T/repo" || exit 1
git config user.email t@example.invalid; git config user.name test; git config commit.gpgsign false
git remote add origin "$T/remote.git"
cat > Makefile <<'EOF'
.PHONY: check test lint fmt build
check: lint test ## lint + tests
	@test ! -f FAIL || { echo "boom: FAIL file present"; exit 1; }
	@echo run >> .runs
test: ## unit tests
	@true
lint: ## lint one file
	@if [ -n "$(FILE)" ]; then ! grep -n 'BAD' $(FILE); fi
fmt: ## strip trailing spaces
	@if [ -n "$(FILE)" ]; then sed -i.bak 's/  *$$//' $(FILE) && rm -f $(FILE).bak; fi
build:
	@true
EOF
printf '.runs\n' > .gitignore
mkdir -p src; echo x > src/a.txt; git add -A; git commit -qm init
git push -q origin main 2>/dev/null; git fetch -q origin; git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git switch -qc feat/1-test; echo y >> src/a.txt; git commit -qam "feat: y"

hook() { # <script> <json> -> sets OUT, ERR, RC
  local e="$T/err"; RC=0
  OUT="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$T/repo" bash "$S/$1" 2>"$e")" || RC=$?
  ERR="$(cat "$e")"
}
ctx() { printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // .reason // empty' 2>/dev/null; }

# ---------- guard ----------
g() { # <expect allow|block> <tool> <tool_input json>
  hook guard.sh "$(jq -nc --arg t "$2" --arg c "$T/repo" --argjson i "$3" '{tool_name:$t,cwd:$c,tool_input:$i}')"
  local got=allow; [ "$RC" = 2 ] && got=block
  if [ "$got" = "$1" ]; then ok "guard $1: $2 $3"; else ko "guard $1: $2 $3" "got $got rc=$RC $ERR"; fi
  if [ "$got" = block ] && ! printf '%s' "$ERR" | grep -q 'Do this instead'; then ko "guard message teaches a fix" "$ERR"; fi
}
b() { g "$1" Bash "$(jq -nc --arg c "$2" '{command:$c}')"; }
f() { g "$1" "$2" "$(jq -nc --arg p "$T/repo/$3" '{file_path:$p}')"; }

b block "git push --force origin feat/1-test"
b block "git push -f"
b block "git push origin +feat/1-test"
b allow "git push --force-with-lease origin feat/1-test"
b block "git push origin main"
b block "git push origin HEAD:main"
b block "cd sub && git push origin feat/1-test:master"
b block "git -C /tmp push origin main"
b allow "git push -u origin HEAD"
b block "git push --tags"
b block "git push origin --delete old"
b block "git push origin :old"
b allow "echo 'git push origin main'"
b allow "git reset --hard HEAD"            # clean tracked tree
echo z >> src/a.txt
b block "git reset --hard HEAD~1"
b allow "git reset --soft HEAD~1"
b block "git checkout -- ."
b allow "git checkout -- src/a.txt"
git checkout -q -- src/a.txt
echo u > src/untracked.txt
b block "git clean -fd"
b allow "git clean -n"
rm -f src/untracked.txt
b block "cat .env"
b block "head -5 config/.env.production"
b allow "cat .env.example"
b allow "cp .env.example .env"
b block "cp .env /tmp/x"
b block "grep KEY ~/.ssh/id_ed25519"
b allow "cat ~/.ssh/id_ed25519.pub"
b block "FOO=1 sudo cat secrets/db.txt"
b block "echo \$(cat key.pem)"
b block "gh pr merge 12 --squash"
b block "gh api -X PUT repos/o/r/pulls/3/merge"
b allow "gh pr view 12"
b block "gh release create v1.0.0"
b allow "npm ci && make check"
git switch -q main; b block "git push"; git switch -q feat/1-test; b allow "git push"
f block Edit package-lock.json
f block Write composer.lock
f allow Edit package.json
f block Write src/generated/resources/data/x.json
f block Edit docs/assets/diagrams/runtime.dark.png
f allow Edit docs/index.md
f allow Edit config/server/index.json          # no storage/ dir: not Provisioning
mkdir -p config/server/storage
f block Edit config/server/index.json
rm -rf config
f block Write .env
f allow Write .env.example
f block Edit vendor/x/y.php
f allow Edit build/icon.png                     # electron-builder resources are source
f block Read .env.local
f block Read infra/prod.tfvars
f allow Read README.md

# ---------- post-edit ----------
printf 'hello   \nBAD line\n' > src/c.txt
hook post-edit.sh "$(jq -nc --arg p "$T/repo/src/c.txt" '{tool_name:"Edit",tool_input:{file_path:$p}}')"
c="$(ctx)"
printf '%s' "$c" | grep -q 'Formatted src/c.txt' && ok "post-edit reports formatting" || ko "post-edit reports formatting" "$c"
printf '%s' "$c" | grep -q '2:BAD line' && ok "post-edit returns lint findings" || ko "post-edit returns lint findings" "$c"
[ "$(head -1 src/c.txt)" = hello ] && ok "post-edit ran make fmt FILE=" || ko "post-edit ran make fmt FILE="
printf 'fine\n' > src/d.txt
hook post-edit.sh "$(jq -nc --arg p "$T/repo/src/d.txt" '{tool_input:{file_path:$p}}')"
[ -z "$OUT" ] && [ "$RC" = 0 ] && ok "post-edit silent on a clean file" || ko "post-edit silent on a clean file" "$OUT"
rm -f src/c.txt src/d.txt

# ---------- stop ----------
echo dirty > src/b.txt
st() { hook stop.sh "{\"cwd\":\"$T/repo\",\"stop_hook_active\":${1:-false}}"; }
runs() { wc -l < .runs 2>/dev/null | tr -d ' ' || echo 0; }
st; c="$(ctx)"
[ "$(runs)" = 1 ] && ok "stop runs make check on a changed tree" || ko "stop runs make check" "runs=$(runs)"
printf '%s' "$c" | grep -q 'AGENTS.md' && ok "stop docs reminder" || ko "stop docs reminder" "$c"
printf '%s' "$c" | grep -q 'PROGRESS.md' && ok "stop PROGRESS.md reminder" || ko "stop PROGRESS.md reminder" "$c"
st; [ -z "$OUT" ] && [ "$(runs)" = 1 ] && ok "stop: cached pass, reminders once" || ko "stop cache/once" "out=$OUT runs=$(runs)"
touch FAIL; st
printf '%s' "$OUT" | jq -e '.decision=="block"' >/dev/null && printf '%s' "$OUT" | grep -q boom && ok "stop blocks on failing check with the log tail" || ko "stop blocks on failure" "$OUT"
st true; [ -z "$OUT" ] && ok "stop_hook_active + unchanged tree: allowed to stop" || ko "stop loop guard" "$OUT"
echo more >> src/b.txt; st true
printf '%s' "$OUT" | jq -e '.decision=="block"' >/dev/null && ok "stop_hook_active + changed tree: re-checked" || ko "stop re-check after change" "$OUT"
rm FAIL; st true; [ -z "$OUT" ] && ok "stop passes once fixed" || ko "stop passes once fixed" "$OUT"
touch FAIL; OUT="$(printf '{}' | ARFFORNIA_SKIP_CHECK=1 CLAUDE_PROJECT_DIR="$T/repo" bash "$S/stop.sh")"; [ -z "$OUT" ] && ok "ARFFORNIA_SKIP_CHECK=1 skips the gate" || ko "skip gate"; rm FAIL

# ---------- handoff ----------
printf '// TODO: handle the empty case\n' >> src/a.txt
hook handoff.sh "{\"cwd\":\"$T/repo\",\"hook_event_name\":\"PreCompact\",\"trigger\":\"auto\"}"
grep -q 'Auto handoff .*PreCompact: auto' PROGRESS.md && ok "handoff writes PROGRESS.md on PreCompact" || ko "handoff PreCompact"
grep -q 'src/a.txt:.* TODO: handle the empty case' PROGRESS.md && ok "handoff lists TODOs added in the diff" || ko "handoff TODOs" "$(cat PROGRESS.md)"
hook handoff.sh "{\"cwd\":\"$T/repo\",\"hook_event_name\":\"SessionEnd\",\"reason\":\"other\"}"
[ "$(grep -c auto-handoff PROGRESS.md)" = 1 ] && ok "handoff skips duplicates" || ko "handoff dedup"
for i in 1 2 3 4 5 6; do echo "$i" >> src/a.txt; hook handoff.sh "{\"cwd\":\"$T/repo\",\"hook_event_name\":\"SessionEnd\",\"reason\":\"clear\"}"; done
[ "$(grep -c auto-handoff PROGRESS.md)" = 5 ] && ok "handoff keeps the last 5 entries" || ko "handoff trim" "$(grep -c auto-handoff PROGRESS.md)"
[ "$(git log -1 --format=%s)" = "feat: y" ] && ok "handoff never commits" || ko "handoff committed"

# ---------- session-start ----------
hook session-start.sh "{\"cwd\":\"$T/repo\",\"source\":\"startup\"}"
c="$(ctx)"
for want in 'Branch: feat/1-test' 'Uncommitted files:' 'feat: y' 'make check (= lint test)' 'Latest automatic handoff'; do
  printf '%s' "$c" | grep -qF "$want" && ok "card has: $want" || ko "card has: $want" "$c"
done
[ "$(printf '%s\n' "$c" | wc -l)" -le 40 ] && ok "card <= 40 lines" || ko "card <= 40 lines"

# ---------- issue-context (no gh: silent) ----------
hook issue-context.sh '{"prompt":"work on #12"}'
[ -z "$OUT" ] && [ "$RC" = 0 ] && ok "issue-context is a quiet no-op without gh" || ko "issue-context no-op" "$OUT"

# ---------- outside a repo ----------
for s in session-start guard post-edit stop handoff issue-context; do
  RC=0; printf '{"cwd":"/","tool_name":"Bash","tool_input":{"command":"ls"}}' | CLAUDE_PROJECT_DIR=/ bash "$S/$s.sh" >/dev/null 2>&1 || RC=$?
  [ "$RC" = 0 ] && ok "$s no-op outside a git repo" || ko "$s outside repo rc=$RC"
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
