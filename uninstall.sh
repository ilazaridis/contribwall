#!/bin/sh
# contribwall uninstaller -- removes everything except your settings.
set -eu

DATA="${XDG_DATA_HOME:-$HOME/.local/share}/contribwall"
BIN="$HOME/.local/bin/contribwall"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/contribwall"
AGENTS="$HOME/Library/LaunchAgents"
uid=$(id -u)

printf '\n  Removing contribwall...\n\n'

for agent in com.github.contribwall.window com.github.contribwall.server com.github.contribwall.awake; do
    launchctl bootout "gui/$uid/$agent" 2>/dev/null || true
    rm -f "$AGENTS/$agent.plist"
done

pkill -f "user-data-dir=$DATA/browser-profile" 2>/dev/null || true
rm -rf "$DATA"
rm -f "$BIN"

printf '  Gone.\n\n'
printf '  Your settings are still at %s\n' "$CONFIG_DIR/config.json"
printf '  Remove them with: rm -rf %s\n\n' "$CONFIG_DIR"
