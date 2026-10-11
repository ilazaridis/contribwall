#!/bin/sh
# contribwall uninstaller -- removes everything except your settings.
set -eu

DATA="${XDG_DATA_HOME:-$HOME/.local/share}/contribwall"
BIN="$HOME/.local/bin/contribwall"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/contribwall"
AGENTS="$HOME/Library/LaunchAgents"
PATH_MARKER="# added by contribwall"
uid=$(id -u)

printf '\n  Removing contribwall...\n\n'

for agent in com.github.contribwall.window com.github.contribwall.server com.github.contribwall.awake; do
    launchctl bootout "gui/$uid/$agent" 2>/dev/null || true
    rm -f "$AGENTS/$agent.plist"
done

# pkill matches a regex, so quote the path before using it as one.
if command -v python3 >/dev/null 2>&1; then
    pattern=$(python3 -c 'import sys
print("".join("\\" + c if c in ".[]()*+?{}|^$\\" else c for c in sys.argv[1]))' \
        "user-data-dir=$DATA/browser-profile")
    pkill -f "$pattern" 2>/dev/null || true
fi

rm -rf "$DATA"
rm -f "$BIN"

# Take back the PATH line the installer added, leaving the rest of the file be.
for rc in "$HOME/.zshrc" "$HOME/.bash_profile"; do
    [ -f "$rc" ] || continue
    grep -qs "$PATH_MARKER" "$rc" || continue
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import sys
path, marker = sys.argv[1], sys.argv[2]
with open(path) as fh:
    lines = fh.readlines()
out, skip = [], 0
for line in lines:
    if skip:
        skip -= 1
        continue
    if line.strip() == marker:
        skip = 1          # also drop the export line that follows
        if out and out[-1].strip() == "":
            out.pop()
        continue
    out.append(line)
with open(path, "w") as fh:
    fh.writelines(out)' "$rc" "$PATH_MARKER"
        printf '  Removed the PATH line from %s\n' "$rc"
    fi
done

printf '\n  Gone.\n\n'
printf '  Your settings are still at %s\n' "$CONFIG_DIR/config.json"
if command -v python3 >/dev/null 2>&1; then
    printf '  Remove them with: rm -rf %s\n\n' "$(python3 -c 'import shlex,sys; print(shlex.quote(sys.argv[1]))' "$CONFIG_DIR")"
else
    printf '  Remove that folder to finish the job.\n\n'
fi
