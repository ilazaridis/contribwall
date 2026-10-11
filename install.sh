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
PATH_MARKER="# added by contribwall"

scratch=""
cleanup() { [ -n "$scratch" ] && rm -rf "$scratch"; return 0; }
trap cleanup EXIT
# Interrupted means stop, not carry on half-installed.
trap 'cleanup; exit 130' HUP INT TERM

say()  { printf '  %s\n' "$1"; }
fail() { printf '\n  %s\n\n' "$1" >&2; exit 1; }

# Set CONTRIBWALL_NONINTERACTIVE=1 to take every default and never prompt.
can_ask() {
    [ -z "${CONTRIBWALL_NONINTERACTIVE:-}" ] && [ -r /dev/tty ]
}

printf '\n  contribwall\n\n'

# --- checks -----------------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || fail "contribwall is macOS only."

command -v python3 >/dev/null 2>&1 || fail "Needs python3. Run: xcode-select --install"
PYTHON=$(command -v python3)
"$PYTHON" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 7) else 1)' 2>/dev/null \
    || fail "Needs python3 3.7 or newer. Run: xcode-select --install"

command -v gh >/dev/null 2>&1 || fail "Needs the GitHub CLI. Run: brew install gh"

browser=""
for name in "Google Chrome" "Brave Browser" "Microsoft Edge" "Chromium"; do
    if [ -d "/Applications/$name.app" ]; then
        browser="$name"
        break
    fi
done
[ -n "$browser" ] || fail "Needs Chrome, Brave, Edge or Chromium in /Applications."

if ! gh auth status >/dev/null 2>&1; then
    # Piped from curl, stdin is the script itself, so sign-in needs the terminal.
    if can_ask; then
        say "GitHub CLI is not signed in. Starting sign-in..."
        printf '\n'
        gh auth login < /dev/tty || fail "Sign-in did not finish. Run 'gh auth login', then try again."
    else
        fail "GitHub CLI is not signed in. Run 'gh auth login', then try again."
    fi
fi

say "python3, gh and $browser found."

# Private contributions only show up when the token carries read:user.
if ! gh auth status 2>&1 | grep -q "read:user"; then
    if can_ask; then
        say "Asking GitHub for read:user, so private contributions count..."
        gh auth refresh -h github.com -s read:user < /dev/tty \
            || say "Skipped. Private contributions will not be counted."
    else
        say "Note: run 'gh auth refresh -h github.com -s read:user' to count private work."
    fi
fi

# --- source -----------------------------------------------------------------
here=""
case "$0" in
    */*) here=$(cd "$(dirname "$0")" && pwd) ;;
esac

if [ -n "$here" ] && [ -f "$here/lib/server.py" ]; then
    src="$here"
else
    say "Downloading contribwall..."
    scratch=$(mktemp -d)
    # Pin to one commit so every file comes from the same revision.
    ref=$(gh api "repos/$REPO/commits/$BRANCH" --jq .sha 2>/dev/null || echo "$BRANCH")
    curl -fsSL "https://codeload.github.com/$REPO/tar.gz/$ref" | tar xz -C "$scratch" \
        || fail "Download failed."
    src=$(find "$scratch" -maxdepth 1 -type d -name 'contribwall-*' | head -1)
    [ -n "$src" ] || fail "Download looked wrong."
fi

# --- install ----------------------------------------------------------------
mkdir -p "$DATA" "$BIN" "$CONFIG_DIR" "$AGENTS"
cp "$src/lib/server.py" "$src/lib/index.html" "$src/lib/pick-display.js" "$DATA/"
cp "$src/bin/contribwall" "$BIN/contribwall"
cp "$src/uninstall.sh" "$DATA/uninstall.sh"
chmod +x "$BIN/contribwall" "$DATA/uninstall.sh"

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

# --- launchd agents ---------------------------------------------------------
# Built with plistlib so paths are escaped and never parsed as shell.
gh_dir=$(dirname "$(command -v gh)")
python_dir=$(dirname "$PYTHON")
agent_path="$python_dir:$gh_dir:/usr/bin:/bin:/usr/sbin:/sbin"

"$PYTHON" - "$AGENTS/$SERVER_AGENT.plist" "$SERVER_AGENT" "$PYTHON" "$DATA" "$agent_path" \
          "${XDG_DATA_HOME:-}" "${XDG_CONFIG_HOME:-}" <<'PY'
import os, plistlib, sys

target, label, python, data, path, xdg_data, xdg_config = sys.argv[1:8]
env = {"PATH": path}
if xdg_data:
    env["XDG_DATA_HOME"] = xdg_data
if xdg_config:
    env["XDG_CONFIG_HOME"] = xdg_config

with open(target, "wb") as fh:
    plistlib.dump({
        "Label": label,
        "ProgramArguments": [python, os.path.join(data, "server.py")],
        "EnvironmentVariables": env,
        "RunAtLoad": True,
        "KeepAlive": True,
        "StandardOutPath": os.path.join(data, "server.log"),
        "StandardErrorPath": os.path.join(data, "server.log"),
    }, fh)
PY

"$PYTHON" - "$AGENTS/$WINDOW_AGENT.plist" "$WINDOW_AGENT" "$BIN/contribwall" "$DATA" "$agent_path" \
          "${XDG_DATA_HOME:-}" "${XDG_CONFIG_HOME:-}" <<'PY'
import os, plistlib, sys

target, label, command, data, path, xdg_data, xdg_config = sys.argv[1:8]
env = {"PATH": path}
if xdg_data:
    env["XDG_DATA_HOME"] = xdg_data
if xdg_config:
    env["XDG_CONFIG_HOME"] = xdg_config

with open(target, "wb") as fh:
    plistlib.dump({
        "Label": label,
        # The path is an argument, never spliced into the script text.
        "ProgramArguments": ["/bin/sh", "-c", 'sleep 8; exec "$0"', command],
        "EnvironmentVariables": env,
        "RunAtLoad": True,
        # Retry only when opening the window actually failed.
        "KeepAlive": {"SuccessfulExit": False},
        "StandardOutPath": os.path.join(data, "window.log"),
        "StandardErrorPath": os.path.join(data, "window.log"),
    }, fh)
PY

uid=$(id -u)
for agent in "$WINDOW_AGENT" "$SERVER_AGENT"; do
    launchctl bootout "gui/$uid/$agent" 2>/dev/null || true
done
# A just-killed server can still hold the port for a moment.
sleep 2
launchctl bootstrap "gui/$uid" "$AGENTS/$SERVER_AGENT.plist"

# --- which screen -----------------------------------------------------------
screens=$(osascript -l JavaScript "$DATA/pick-display.js" --list | wc -l | tr -d ' ')
configured=$("$PYTHON" "$DATA/server.py" --get display)
if [ "$screens" -gt 1 ] && [ -z "$configured" ] && can_ask; then
    say "You have $screens screens."
    "$BIN/contribwall" displays || true
    printf '  Which one? [1-%s, or return for the second one] ' "$screens"
    read -r choice < /dev/tty || choice=""
    case "$choice" in
        '') ;;
        *[!0-9]*) say "Not a number; using the second screen." ;;
        *)
            if [ "$choice" -ge 1 ] && [ "$choice" -le "$screens" ]; then
                names=$(osascript -l JavaScript "$DATA/pick-display.js" --list | cut -f2)
                chosen=$(printf '%s\n' "$names" | sed -n "${choice}p")
                total=$(printf '%s\n' "$names" | grep -Fxc -- "$chosen" 2>/dev/null || true)
                if [ "${total:-1}" -gt 1 ]; then
                    # Two monitors share this name; remember which one.
                    nth=$(printf '%s\n' "$names" | sed -n "1,${choice}p" | grep -Fxc -- "$chosen" 2>/dev/null || true)
                    chosen="$chosen#${nth:-1}"
                fi
                "$PYTHON" "$DATA/server.py" --set display "$chosen"
                say "Using $chosen."
            else
                say "Out of range; using the second screen."
            fi
            ;;
    esac
fi

# This opens the window, now and at every login.
launchctl bootstrap "gui/$uid" "$AGENTS/$WINDOW_AGENT.plist"

# --- PATH -------------------------------------------------------------------
case ":$PATH:" in
    *":$BIN:"*) ;;
    *)
        case "$(basename "${SHELL:-/bin/zsh}")" in
            bash) rc="$HOME/.bash_profile" ;;
            *)    rc="$HOME/.zshrc" ;;
        esac
        if ! grep -qs "$PATH_MARKER" "$rc"; then
            printf '\n%s\nexport PATH="$HOME/.local/bin:$PATH"\n' "$PATH_MARKER" >> "$rc"
        fi
        say "Added ~/.local/bin to PATH in $rc"
        say "For this terminal, run: export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
esac

printf '\n  Done. Your wall is coming up.\n\n'
say "contribwall              put it on screen"
say "contribwall range month  week | 14 | month"
say "contribwall display      choose a screen"
say "contribwall off          take it off"
printf '\n'
