#!/bin/sh
# Double-click this in Finder to remove contribwall.
cd "$(dirname "$0")" || exit 1
./uninstall.sh
printf '  Press return to close this window.\n'
read -r _
