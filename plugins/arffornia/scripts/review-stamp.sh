#!/usr/bin/env bash
# Review state for the in-session review gate (stop.sh) and the arffornia:review skill.
# State lives in .git/claude-harness/ of the current worktree; nothing is committed.
#
#   review-stamp.sh status                  what to review: full diff vs base, or delta since the last review
#   review-stamp.sh diff [--stat]           print that diff (untracked files included)
#   review-stamp.sh record --level L --counts "Findings: ..." [--blocking N] [--findings FILE.json]
#                                           stamp the current tree as reviewed (one round)
#   review-stamp.sh label [--round N] <id> <fixed|wrong|intended|noise> [note]   (default: latest round)
#                                           what happened to a finding (feeds evals via the PR body)
#   review-stamp.sh summary                 Markdown block for the PR body, with a machine-readable marker
#
# FILE.json for --findings: [{"id":"F1","severity":"blocking|major|minor|pre-existing",
#   "lens":"correctness|security|rules-tests|...","path":"src/x.ts:42","title":"one line"}]
# Needs git and jq (macOS 15+ ships jq; else `brew install jq` or nix).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

die() { printf 'review-stamp: %s\n' "$*" >&2; exit 1; }
have git || die "git is required"
root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git work tree"
cd "$root"
git rev-parse --verify --quiet HEAD >/dev/null || die "the repository has no commit yet"
sd="$(state_dir)" || die "cannot create .git/claude-harness"
ST="$sd/review-stamp"
LOG="$sd/reviews.jsonl"
need_jq() { have jq || die "jq is required (macOS: built in since 15, or \`brew install jq\`; nix: \`nix shell nixpkgs#jq\`)"; }

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo detached)"
base="$(base_rev)"
same_branch() { [ "$(kv_get "$ST" branch)" = "$branch" ]; }
cur_round() { local r=0; same_branch && r="$(kv_get "$ST" round)"; case "$r" in ''|*[!0-9]*) r=0 ;; esac; printf '%s' "$r"; }
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

cmd="${1:-status}"; [ $# -gt 0 ] && shift
case "$cmd" in
  status)
    tree="$(snapshot_tree)" || die "cannot snapshot the work tree"
    round="$(cur_round)"
    # Same rule as the Stop gate: the stamped tree, or one that differs only in docs/lockfiles.
    reviewed=no; stamped="$(kv_get "$ST" tree)"
    if [ -n "$stamped" ] && { [ "$stamped" = "$tree" ] || [ "$(code_lines_between "$stamped" "$tree" 2>/dev/null)" = 0 ]; }; then
      reviewed=yes
    fi
    lines="$(code_lines_changed "$base")"
    printf 'branch=%s\nbase=%s\ntree=%s\nreviewed=%s\nround=%s\nmax_rounds=%s\ncode_lines_changed=%s\n' \
      "$branch" "$base" "$tree" "$reviewed" "$round" "${ARFFORNIA_REVIEW_MAX_ROUNDS:-3}" "$lines"
    if [ "$round" -gt 0 ]; then
      printf 'mode=delta\nlast_snapshot=%s\nlast_counts=%s\n' "$(kv_get "$ST" commit)" "$(kv_get "$ST" counts)"
    else
      printf 'mode=full\n'
    fi
    ;;
  diff)
    stat=""; [ "${1:-}" = "--stat" ] && stat="--stat"
    cur="$(snapshot_commit)" || die "cannot snapshot the work tree"
    from="$base"
    if [ "$(cur_round)" -gt 0 ] && last="$(kv_get "$ST" commit)" && [ -n "$last" ] && git cat-file -e "$last" 2>/dev/null; then
      from="$last"
    fi
    # Secret-like files (same rule as the guard: is_secret_path) never reach the transcript,
    # even when untracked and not ignored; .example/.sample files are reviewed normally.
    set -- -- .
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if is_secret_path "$f"; then
        set -- "$@" ":(exclude,literal)$f"
        printf 'review-stamp: not shown (secret-like path): %s\n' "$f" >&2
      fi
    done <<EOF_NAMES
$(git diff --name-only "$from" "$cur" 2>/dev/null)
EOF_NAMES
    # shellcheck disable=SC2086
    git --no-pager diff $stat "$from" "$cur" "$@"
    ;;
  record)
    level="" counts="" blocking="" findings=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --level) level="${2:-}"; shift 2 ;;
        --counts) counts="${2:-}"; shift 2 ;;
        --blocking) blocking="${2:-}"; shift 2 ;;
        --findings) findings="${2:-}"; shift 2 ;;
        *) die "unknown option $1" ;;
      esac
    done
    [ -n "$counts" ] || die "--counts \"Findings: ...\" is required"
    need_jq
    if [ -z "$blocking" ]; then
      blocking="$(printf '%s' "$counts" | sed -n 's/.*blocking \([0-9][0-9]*\).*/\1/p' | head -n 1)"
    fi
    case "$blocking" in ''|*[!0-9]*) blocking=0 ;; esac
    fjson="[]"
    if [ -n "$findings" ]; then
      [ -f "$findings" ] || die "no such file: $findings"
      fjson="$(jq -c 'if type=="array" then . else error("findings must be a JSON array") end' "$findings")" || die "invalid findings JSON"
    fi
    tree="$(snapshot_tree)" || die "cannot snapshot the work tree"
    commit="$(snapshot_commit "$tree")" || die "cannot create the snapshot commit"
    round=$(( $(cur_round) + 1 ))
    {
      printf 'tree=%s\ncommit=%s\nbranch=%s\nbase=%s\nround=%s\nlevel=%s\nblocking=%s\ncounts=%s\ndate=%s\n' \
        "$tree" "$commit" "$branch" "$base" "$round" "$level" "$blocking" "$counts" "$(now)"
    } > "$ST.tmp" && mv "$ST.tmp" "$ST"
    jq -nc --arg d "$(now)" --arg b "$branch" --arg base "$base" --arg t "$tree" --arg c "$commit" \
      --argjson r "$round" --arg l "$level" --arg counts "$counts" --argjson blk "$blocking" --argjson f "$fjson" \
      '{type:"review", date:$d, branch:$b, base:$base, tree:$t, snapshot:$c, round:$r, level:$l, counts:$counts, blocking:$blk, findings:($f | map(. + {round:$r}))}' >> "$LOG"
    printf 'Recorded review round %s for %s (tree %s): %s\n' "$round" "$branch" "${tree:0:12}" "$counts"
    ;;
  label)
    lr=""; [ "${1:-}" = "--round" ] && { lr="${2:-}"; shift 2; }
    [ $# -ge 2 ] || die "usage: label [--round N] <finding-id> <fixed|wrong|intended|noise> [note]"
    case "$2" in fixed|wrong|intended|noise) ;; *) die "label must be fixed, wrong, intended or noise" ;; esac
    need_jq
    r="$(cur_round)"
    [ "$r" -gt 0 ] || die "no review recorded on this branch yet"
    if [ -n "$lr" ]; then
      case "$lr" in ''|*[!0-9]*) die "--round needs a number" ;; esac
      [ "$lr" -ge 1 ] && [ "$lr" -le "$r" ] || die "no round $lr on this branch (latest is $r)"
      r="$lr"
    fi
    # A label applies to that id in the latest round (each round numbers its findings from F1).
    jq -nc --arg d "$(now)" --arg b "$branch" --arg id "$1" --arg l "$2" --arg n "${3:-}" --argjson r "$r" \
      '{type:"label", date:$d, branch:$b, round:$r, id:$id, label:$l, note:$n}' >> "$LOG"
    printf 'Labelled %s (round %s) as %s\n' "$1" "$r" "$2"
    ;;
  summary)
    need_jq
    [ -f "$LOG" ] || { printf 'No in-session review recorded on this branch.\n'; exit 0; }
    jq -rs --arg b "$branch" '
      [ .[] | select(.branch == $b) ] as $all
      | [ $all[] | select(.type == "review") ] as $rev
      | ( [ $all[] | select(.type == "label") ] | map({("\(.round // 0)/\(.id)"): .label}) | add // {} ) as $lab
      | ( [ $rev[].findings[]? ] | map(. + {label: ($lab["\(.round // 0)/\(.id)"] // "unlabelled")})
          | unique_by("\(.round // 0)/\(.id)") ) as $f
      | if ($rev | length) == 0 then "No in-session review recorded on this branch."
        else
          "### In-session review\n"
          + "Rounds: \($rev | length) · last: \($rev[-1].counts) · risk: \($rev[-1].level)\n"
          + ( if ($f | length) == 0 then "No confirmed findings.\n"
              else ($f | map("- R\(.round // 0).\(.id) · \(.severity) · \(.lens) · `\((.path // "") | tostring | gsub("[`<>]"; ""))` · \((.title // "") | tostring | gsub("[<>]"; "")) → **\(.label)**") | join("\n")) + "\n" end )
          + "\n<!-- arffornia-review v1 " + ({rounds: ($rev | length), level: $rev[-1].level, counts: $rev[-1].counts,
               findings: ($f | map({round, id, severity, lens, path, title, label}))} | tojson | gsub("--"; "-\\u002d")) + " -->"
        end' "$LOG"
    ;;
  *) die "unknown command $cmd (status | diff | record | label | summary)" ;;
esac
