#!/usr/bin/env bash
# UserPromptSubmit: notice when the user corrects how the agent works ("no, I said...",
# "stop doing X", "non, pas comme ça", "je t'ai dit") and remind the agent, once per prompt, to
# record a durable lesson with the arffornia:harness-feedback skill. Cheap heuristic: a false
# positive costs one line of context; the skill itself decides whether there is a harness lesson.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
read_input

[ "${ARFFORNIA_NO_FEEDBACK_HINTS:-}" = "1" ] && exit 0
prompt="$(json_get .prompt)"
[ -n "$prompt" ] || exit 0

# Lowercase without bash 4 (${var,,}); keep it to the first 600 characters.
p="$(printf '%s' "$prompt" | cut -c1-600 | tr '[:upper:]' '[:lower:]')"

re_en="(^|[^a-z])(no[,.!]|nope|that'?s (wrong|not what)|not what i (asked|meant|said)|i (said|told you|asked you)|you (should|shouldn'?t) have|stop doing|don'?t do that|why did you|again\\?|you forgot|you ignored|wrong (file|branch|repo|approach))"
re_fr="(^|[^a-z])(non[,.!]|pas (ça|ca|comme ça|comme ca)|je (t'?ai|vous ai) (dit|demandé|demande)|tu (aurais dû|aurais du|as oublié|as oublie|n'?as pas)|arrête de|arrete de|pourquoi (tu as|as-tu)|c'?est faux|ce n'?est pas ce que)"

if printf '%s' "$p" | grep -qE "$re_en|$re_fr"; then
  emit_context UserPromptSubmit "Harness note: this prompt may correct how you work. Address it first. Then, if the correction reveals something the harness should have prevented or taught (a missing rule, a misleading skill, a guard that fired wrongly, a better way), record it with the arffornia:harness-feedback skill: search existing issues first, append if one matches, include the evidence and a proposed patch. Skip it when the correction is only about this task's content."
fi
exit 0
