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

# Paths through a symlinked directory (macOS: /var and /tmp are symlinks to /private/...).
ln -s "$T/repo" "$T/link"
gl() { g "$1" "$2" "$(jq -nc --arg p "$T/link/$3" '{file_path:$p}')"; }
gl block Write src/generated/resources/data/y.json
gl block Edit vendor/x/z.php
gl allow Edit src/a.txt
mkdir -p "$T/dotfiles/ssh"; ln -s "$T/dotfiles/ssh" "$T/repo/.ssh"
f block Write .ssh/authorized_keys            # secret dir behind a symlink (stow, home-manager)
rm -f "$T/repo/.ssh"

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
printf 'via link   \n' > src/e.txt
hook post-edit.sh "$(jq -nc --arg p "$T/link/src/e.txt" '{tool_name:"Edit",tool_input:{file_path:$p}}')"
[ "$(head -1 src/e.txt)" = "via link" ] && ok "post-edit works through a symlinked path" || ko "post-edit via symlink" "$OUT"
rm -f src/e.txt
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

# ---------- review gate (stop.sh) + review-stamp.sh ----------
RS() { CLAUDE_PROJECT_DIR="$T/repo" bash "$S/review-stamp.sh" "$@"; }
HS="$(git rev-parse --absolute-git-dir)/claude-harness"
sst() { hook stop.sh "{\"cwd\":\"$T/repo\",\"stop_hook_active\":${2:-false},\"session_id\":\"$1\"}"; }
ss() { hook session-start.sh "{\"cwd\":\"$T/repo\",\"source\":\"${2:-startup}\",\"session_id\":\"$1\"}"; }
asked() { printf '%s' "$OUT" | grep -q 'arffornia:review'; }
git add -A >/dev/null; git commit -qm "wip: b" >/dev/null
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do echo "line $i" >> src/code.txt; done
# A session that only reads is never asked for a review, even on a branch with unreviewed code.
ss s-ro; sst s-ro; ! asked && ok "review gate: read-only session is not asked" || ko "read-only session" "$OUT"
# The start tree is kept across compaction: change the tree, then a compact SessionStart must not reset it.
echo "line 13" >> src/code.txt; ss s-ro compact; sst s-ro
asked && ok "review gate: asks once the session changed code (compact keeps the start tree)" || ko "session changed" "$OUT"
# A session whose only change is docs (e.g. the PROGRESS.md handoff) is not asked either.
ss s-doc; echo "handoff note" >> PROGRESS.md; rm -f "$HS/review-asked"; sst s-doc
! asked && ok "review gate: docs-only session change is not asked" || ko "docs-only session" "$OUT"
rm -f "$HS/review-asked"
st; printf '%s' "$OUT" | jq -e '.decision=="block"' >/dev/null && asked && ok "review gate blocks a non-trivial unreviewed tree" || ko "review gate blocks" "$OUT"
st true; ! asked && ok "review gate asks only once per tree" || ko "review gate once" "$OUT"
grep -q '^mode=full$' <<<"$(RS status)" && ok "review-stamp status: full mode before any review" || ko "status full" "$(RS status)"
grep -q '^+line 12$' <<<"$(RS diff)" && ok "review-stamp diff includes untracked files" || ko "diff untracked" "$(RS diff | head)"
printf 'API_KEY=very-secret-value\n' > src/.env.local
d="$(RS diff 2>&1)"; ! printf '%s' "$d" | grep -q 'very-secret-value' && printf '%s' "$d" | grep -q 'not shown (secret-like path): src/.env.local' \
  && ok "review-stamp diff never prints secret-like files" || ko "diff secret" "$d"
rm -f src/.env.local
printf '[{"id":"F1","severity":"major","lens":"correctness","path":"src/code.txt:3","title":"off by one --> **x**"}]' > "$T/f.json"
RS record --level medium --counts "Findings: 1 (blocking 0, major 1, minor 0, pre-existing 0) · risk: medium" --findings "$T/f.json" >/dev/null \
  && ok "review-stamp record" || ko "record"
grep -q '^reviewed=yes$' <<<"$(RS status)" && ok "status: reviewed after record" || ko "reviewed=yes" "$(RS status)"
rm -f "$HS/review-asked"    # so the next case can only pass through the stamp check
st; ! asked && ok "review gate passes a stamped tree" || ko "stamped passes" "$OUT"
echo "more notes" >> PROGRESS.md; rm -f "$HS/review-asked"
st; ! asked && ok "review gate: docs-only change after a review keeps the stamp" || ko "docs after stamp" "$OUT"
echo "fix" >> src/code.txt
grep -q '^mode=delta$' <<<"$(RS status)" && ok "status: delta mode after a change" || ko "delta mode" "$(RS status)"
d="$(RS diff)"; printf '%s' "$d" | grep -q '^+fix$' && ! printf '%s' "$d" | grep -q '^+line 1$' && ok "delta diff only shows the change since the review" || ko "delta diff" "$d"
st; printf '%s' "$OUT" | grep -q 'round 2/3' && ok "review gate asks for a delta review (round 2/3)" || ko "round 2" "$OUT"
RS label F1 fixed "added bound check" >/dev/null && ok "review-stamp label" || ko "label"
RS label F1 maybe >/dev/null 2>&1 && ko "label rejects unknown values" || ok "label rejects unknown values"
printf '[{"id":"F1","severity":"blocking","lens":"security","path":"src/code.txt:9","title":"injection"}]' > "$T/f2.json"
RS record --level medium --counts "Findings: 1 (blocking 1, major 0, minor 0, pre-existing 0) · risk: medium" --findings "$T/f2.json" >/dev/null
rm -f "$HS/review-asked" "$HS/docs-reminded"
st; printf '%s' "$OUT" | grep -q '1 blocking finding' && ok "stamped tree with blocking findings: reminder" || ko "blocking reminder" "$OUT"
printf '%s' "$OUT" | grep -q 'AGENTS.md' && ok "review note does not swallow the docs/PROGRESS reminders" || ko "notes + reminders" "$OUT"
sm="$(RS summary)"
grep -q '<!-- arffornia-review v1 ' <<<"$sm" && grep -q 'R1.F1 · major · correctness .* \*\*fixed\*\*' <<<"$sm" && grep -q 'R2.F1 · blocking · security .* \*\*unlabelled\*\*' <<<"$sm" \
  && ok "summary keeps both rounds' F1 with their own labels" || ko "summary rounds" "$sm"
mk="$(printf '%s\n' "$sm" | sed -n 's/^<!-- arffornia-review v1 \(.*\) -->$/\1/p')"
[ -n "$mk" ] && printf '%s' "$mk" | jq -e '.findings | length == 2' >/dev/null && ! printf '%s' "$mk" | grep -q -- '-->' \
  && ok "summary marker is one parseable line, '-->' escaped" || ko "marker" "$sm"
echo "fix 2" >> src/code.txt; RS record --level medium --counts "Findings: 0 · risk: medium" >/dev/null
echo "fix 3" >> src/code.txt
st; printf '%s' "$OUT" | grep -q 'round cap reached' && ! printf '%s' "$OUT" | jq -e '.decision=="block"' >/dev/null \
  && ok "review round cap: tells, does not block" || ko "round cap" "$OUT"
echo "fix 4" >> src/code.txt; rm -f "$HS/review-stamp" "$HS/review-asked"
OUT="$(printf '{}' | ARFFORNIA_SKIP_REVIEW=1 CLAUDE_PROJECT_DIR="$T/repo" bash "$S/stop.sh")"; ! asked && ok "ARFFORNIA_SKIP_REVIEW=1 skips the review gate" || ko "skip review" "$OUT"
rm -f "$HS/review-asked"; st; asked && ok "...and without it the same tree is asked (control)" || ko "skip control" "$OUT"
rm -f src/code.txt PROGRESS.md; git checkout -q -- . 2>/dev/null; for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do echo "doc $i" >> docs-note.md; done
rm -f "$HS/review-stamp" "$HS/review-asked"
st; ! asked && ok "docs-only changes need no review" || ko "docs exempt" "$OUT"
rm -f docs-note.md; git reset -q --soft HEAD~1

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

# ---------- friction signal (guard) ----------
fr() { hook guard.sh "$(jq -nc --arg c "$T/repo" '{session_id:"s-1",tool_name:"Bash",cwd:$c,tool_input:{command:"git push --force origin feat/1-test"}}')"; }
fr; ! printf '%s' "$ERR" | grep -q 'harness-feedback' && ok "guard: first block has no feedback hint" || ko "friction first" "$ERR"
fr; printf '%s' "$ERR" | grep -q 'arffornia:harness-feedback' && ok "guard: repeated block suggests harness-feedback" || ko "friction repeat" "$ERR"

# ---------- prompt-signals ----------
ps() { hook prompt-signals.sh "$(jq -nc --arg p "$1" '{prompt:$p}')"; }
ps "No, I said use make check, not npm test"; ctx | grep -q 'harness-feedback' && ok "prompt-signals: English correction" || ko "signals en" "$OUT"
ps "Non, je t'ai dit de ne pas toucher au lockfile"; ctx | grep -q 'harness-feedback' && ok "prompt-signals: French correction" || ko "signals fr" "$OUT"
ps "Add a settings button to the launcher"; [ -z "$OUT" ] && ok "prompt-signals: silent on a normal prompt" || ko "signals silent" "$OUT"
ps "Fix the #nonce handling"; [ -z "$OUT" ] && ok "prompt-signals: no false hit inside words" || ko "signals word" "$OUT"

# ---------- outside a repo ----------
for s in session-start guard post-edit stop handoff issue-context prompt-signals; do
  RC=0; printf '{"cwd":"/","tool_name":"Bash","tool_input":{"command":"ls"}}' | CLAUDE_PROJECT_DIR=/ bash "$S/$s.sh" >/dev/null 2>&1 || RC=$?
  [ "$RC" = 0 ] && ok "$s no-op outside a git repo" || ko "$s outside repo rc=$RC"
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
