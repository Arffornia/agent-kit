#!/usr/bin/env bash
# Install the scheduled automations on this machine, from schedule.tsv.
#   automations/install-local.sh [--all] [--dry-run] [--uninstall]
# Linux (incl. NixOS): systemd user timers ~/.config/systemd/user/arffornia-<agent>.timer, with
#   Persistent=true so a run missed while the machine was off happens at the next boot.
#   On a machine without a logged-in session, run `loginctl enable-linger $USER` once.
# macOS: launchd agents ~/Library/LaunchAgents/io.arffornia.<agent>.plist (missed runs happen at wake).
# Only agents marked enabled=yes, unless --all. Uses the logged-in claude and gh: no API key.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"
kit="$(cd "$here/.." && pwd -P)"
all=0; dry=0; un=0
for a in "$@"; do
  case "$a" in --all) all=1 ;; --dry-run) dry=1 ;; --uninstall) un=1 ;; *) echo "unknown option $a" >&2; exit 2 ;; esac
done
os="${ARFFORNIA_OS:-$(uname -s)}"
say() { printf '%s\n' "$*"; }
write() { # path content
  if [ "$dry" = 1 ]; then printf -- '--- %s\n%s\n' "$1" "$2"; else mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" > "$1"; fi
}
run() { if [ "$dry" = 1 ]; then say "+ $*"; else "$@"; fi; }

if [ "$os" = Linux ]; then
  udir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  if [ "$un" = 0 ]; then
    write "$udir/arffornia-automation@.service" "$(sed "s#@KIT@#$kit#g" "$here/systemd/arffornia-automation@.service")"
  fi
fi
while IFS="$(printf '\t')" read -r agent cadence cal ld _scope enabled; do
  case "$agent" in ''|'#'*) continue ;; esac
  if [ "$enabled" != yes ] && [ "$all" != 1 ]; then continue; fi
  if [ "$os" = Linux ]; then
    t="$udir/arffornia-$agent.timer"
    if [ "$un" = 1 ]; then
      run systemctl --user disable --now "arffornia-$agent.timer" || true
      run rm -f "$t"; continue
    fi
    write "$t" "[Unit]
Description=Arffornia automation $agent ($cadence, Europe/Paris)

[Timer]
OnCalendar=$cal Europe/Paris
Persistent=true
RandomizedDelaySec=300
Unit=arffornia-automation@$agent.service

[Install]
WantedBy=timers.target"
    run systemctl --user daemon-reload
    run systemctl --user enable --now "arffornia-$agent.timer"
  elif [ "$os" = Darwin ]; then
    p="$HOME/Library/LaunchAgents/io.arffornia.$agent.plist"
    if [ "$un" = 1 ]; then run launchctl unload "$p" 2>/dev/null || true; run rm -f "$p"; continue; fi
    # shellcheck disable=SC2086
    set -- $ld
    cal_xml=""
    [ "$1" != - ] && cal_xml="$cal_xml<key>Day</key><integer>$1</integer>"
    [ "$2" != - ] && cal_xml="$cal_xml<key>Weekday</key><integer>$2</integer>"
    cal_xml="$cal_xml<key>Hour</key><integer>$3</integer><key>Minute</key><integer>$4</integer>"
    write "$p" "$(sed -e "s#/Users/USER/src/agent-kit#$kit#g" -e "s#/Users/USER#$HOME#g" -e "s#AGENT#$agent#g" \
      -e "s#<key>Weekday</key><integer>1</integer>##" "$here/launchd/io.arffornia.automation.plist" \
      | awk -v c="$cal_xml" '/<key>StartCalendarInterval<\/key>/{print; getline; print "  <dict>" c "</dict>"; skip=1; next} skip && /<\/dict>/{skip=0; next} !skip{print}')"
    run launchctl unload "$p" 2>/dev/null || true
    run launchctl load "$p"
  else
    echo "unsupported OS $os: use cloud scheduled tasks (automations/README.md)" >&2; exit 1
  fi
  say "installed $agent ($cadence)"
done < "$here/schedule.tsv"
