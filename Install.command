#!/bin/sh
# Double-click this in Finder to install contribwall.
cd "$(dirname "$0")" || exit 1
./install.sh
printf '  Press return to close this window.\n'
read -r _
