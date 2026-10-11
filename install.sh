#!/bin/sh
# contribwall installer -- safe to re-run; it upgrades in place.
set -eu

REPO="${CONTRIBWALL_REPO:-ilazaridis/contribwall}"
BRANCH="${CONTRIBWALL_BRANCH:-main}"

DATA="${XDG_DATA_HOME:-$HOME/.local/share}/contribwall"
BIN="$HOME/.local/bin"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/contribwall"
CONFIG="$CONFIG_DIR/config.json"
AGENTS="$HOME/Library/LaunchAgents"
SERVER_AGENT="com.github.contribwall.server"
WINDOW_AGENT="com.github.contribwall.window"

say()  { printf '  %s\n' "$1"; }
fail() { printf '\n  %s\n\n' "$1" >&2; exit 1; }

printf '\n  contribwall\n\n'

# --- checks -----------------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || fail "contribwall is macOS only."

command -v python3 >/dev/null 2>&1 || fail "Needs python3. Run: xcode-select --install"
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 7) else 1)' 2>/dev/null \
    || fail "Needs python3 3.7+. Run: xcode-select --install"

command -v gh >/dev/null 2>&1 || fail "Needs the GitHub CLI. Run: brew install gh"

browser=""
for name in "Google Chrome" "Brave Browser" "Microsoft Edge" "Chromium"; do
    if [ -d "/Applications/$name.app" ]; then
        browser="$name"
        break
    fi
done
[ -n "$browser" ] || fail "Needs Chrome, Brave, Edge or Chromium."

if ! gh auth status >/dev/null 2>&1; then
    # Piped from curl, stdin is the script itself, so sign-in needs the terminal.
    if [ -r /dev/tty ]; then
        say "GitHub CLI is not signed in. Starting sign-in..."
        printf '\n'
        gh auth login < /dev/tty || fail "Sign-in did not finish. Run 'gh auth login', then try again."
    else
        fail "GitHub CLI is not signed in. Run 'gh auth login', then try again."
    fi
fi

say "python3, gh and $browser found."

# --- source -----------------------------------------------------------------
here=""
case "$0" in
    */*) here=$(cd "$(dirname "$0")" && pwd) ;;
esac

cleanup=""
if [ -n "$here" ] && [ -f "$here/lib/server.py" ]; then
    src="$here"
else
    say "Downloading contribwall..."
    cleanup=$(mktemp -d)
    curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/$BRANCH" \
        | tar xz -C "$cleanup" || fail "Download failed."
    src=$(find "$cleanup" -maxdepth 1 -type d -name 'contribwall-*' | head -1)
    [ -n "$src" ] || fail "Download looked wrong."
fi

# --- install ----------------------------------------------------------------
mkdir -p "$DATA" "$BIN" "$CONFIG_DIR" "$AGENTS"
cp "$src/lib/server.py" "$src/lib/index.html" "$src/lib/pick-display.js" "$DATA/"
cp "$src/bin/contribwall" "$BIN/contribwall"
cp "$src/uninstall.sh" "$DATA/uninstall.sh"
chmod +x "$BIN/contribwall" "$DATA/uninstall.sh"
if [ -n "$cleanup" ]; then
    rm -rf "$cleanup"
fi

if [ ! -f "$CONFIG" ]; then
    cat > "$CONFIG" <<'JSON'
{
  "days": 14,
  "display": "",
  "port": 8723,
  "refreshSeconds": 60,
  "ramp": "darker"
}
JSON
    say "Wrote $CONFIG"
else
    say "Kept your existing settings."
fi

gh_dir=$(dirname "$(command -v gh)")

cat > "$AGENTS/$SERVER_AGENT.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$SERVER_AGENT</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/env</string>
        <string>python3</string>
        <string>$DATA/server.py</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict><key>PATH</key><string>$gh_dir:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>$DATA/server.log</string>
    <key>StandardErrorPath</key><string>$DATA/server.log</string>
</dict>
</plist>
PLIST

cat > "$AGENTS/$WINDOW_AGENT.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$WINDOW_AGENT</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>sleep 8; exec "$BIN/contribwall"</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict><key>PATH</key><string>$gh_dir:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>
    <key>RunAtLoad</key><true/>
    <key>StandardOutPath</key><string>$DATA/window.log</string>
    <key>StandardErrorPath</key><string>$DATA/window.log</string>
</dict>
</plist>
PLIST

# --- start ------------------------------------------------------------------
uid=$(id -u)
for agent in "$SERVER_AGENT" "$WINDOW_AGENT"; do
    launchctl bootout "gui/$uid/$agent" 2>/dev/null || true
done
# A just-killed server can still hold the port for a moment.
sleep 2
launchctl bootstrap "gui/$uid" "$AGENTS/$SERVER_AGENT.plist"
launchctl bootstrap "gui/$uid" "$AGENTS/$WINDOW_AGENT.plist"

case ":$PATH:" in
    *":$BIN:"*) ;;
    *)
        for rc in "$HOME/.zshrc" "$HOME/.bash_profile"; do
            [ -f "$rc" ] || continue
            grep -qs '\.local/bin' "$rc" && continue
            printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
            say "Added ~/.local/bin to PATH in $(basename "$rc")."
        done
        ;;
esac

printf '\n  Done. Your wall is coming up.\n\n'
say "contribwall              put it on screen"
say "contribwall range month  week | 14 | month"
say "contribwall display Dell pick a screen by name"
say "contribwall off          take it off"
printf '\n'

# The window agent already opened it; this just reports where it landed.
"$BIN/contribwall" >/dev/null 2>&1 || true
