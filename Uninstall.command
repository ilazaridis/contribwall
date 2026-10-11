#!/bin/sh
# Double-click this in Finder to remove contribwall.
cd "$(dirname "$0")" || exit 1
sh ./uninstall.sh
status=$?
printf '  Press return to close this window.\n'
read -r _ || true
exit "$status"
