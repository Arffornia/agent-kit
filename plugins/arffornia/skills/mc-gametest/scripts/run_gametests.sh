#!/usr/bin/env bash
# Run the Arffornia_Mods GameTest server with the small-machine caps and print a short verdict.
#   run_gametests.sh            # all arffornia tests
#   run_gametests.sh -k crafter # also list the failing/passing lines that mention "crafter"
# Exit code: the Gradle exit code. The full log stays in build/gametest-run.log.
set -uo pipefail
[ -f build.gradle ] || { echo "run_gametests.sh: run from the Arffornia_Mods root" >&2; exit 2; }
if pgrep -f 'GradleDaemon|gradlew' >/dev/null 2>&1; then
  echo "run_gametests.sh: another Gradle build is running; one at a time on this machine" >&2; exit 2
fi
FILTER=""; [ "${1:-}" = "-k" ] && FILTER=${2:-}
mkdir -p build
LOG=build/gametest-run.log
./gradlew runGameTestServer --no-daemon -Dorg.gradle.jvmargs=-Xmx2g >"$LOG" 2>&1
rc=$?
echo "exit: $rc   log: $PWD/$LOG"
# Verdict lines from vanilla GameTest + Gradle
grep -E "required tests (passed|failed)|All [0-9]+ required tests passed|tests failed:|BUILD (SUCCESSFUL|FAILED)" "$LOG" | tail -5
# Each failure: test name, message and position
grep -nE "::|failed! |GameTestAssert|Timed out|Exception" "$LOG" | grep -vE "minecraftservices|Failed to parse recipe|Couldn't load recipe" | head -30
[ -n "$FILTER" ] && grep -i -- "$FILTER" "$LOG" | head -20
# Known harmless noise is filtered above: absent optional mods' recipes, Mojang API offline.
exit $rc
