#!/bin/bash
# Installs (or reinstalls) the latest Shortcut Coach release into ~/Applications:
#   curl -fsSL https://raw.githubusercontent.com/darryl-paystar/ShortcutCoach/main/scripts/install.sh | bash
# From then on the app updates itself.
set -euo pipefail
URL="https://github.com/darryl-paystar/ShortcutCoach/releases/latest/download/ShortcutCoach.zip"
APP="$HOME/Applications/Shortcut Coach.app"
# The release signing certificate. Updates must match it too, so the Accessibility grant carries over.
REQUIREMENT='identifier "local.shortcutcoach" and certificate leaf = H"673d5e023dfdf8770274f3a3def58afa47fa6dbe"'

if [ "$(sw_vers -productVersion | cut -d. -f1)" -lt 15 ]; then
  echo "Shortcut Coach needs macOS 15 or later." >&2
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
echo "Downloading Shortcut Coach…"
curl -fsSL "$URL" -o "$TMP/ShortcutCoach.zip"
ditto -x -k "$TMP/ShortcutCoach.zip" "$TMP"
if ! codesign --verify --deep --strict -R="$REQUIREMENT" "$TMP/Shortcut Coach.app" 2>/dev/null; then
  echo "The download isn't signed with the Shortcut Coach release certificate. Not installing." >&2
  exit 1
fi

pkill -x ShortcutCoach 2>/dev/null && sleep 1 || true
mkdir -p "$HOME/Applications"
rm -rf "$APP"
mv "$TMP/Shortcut Coach.app" "$APP"
open "$APP"
echo "Installed $(defaults read "$APP/Contents/Info" CFBundleShortVersionString) to $APP"
echo "Grant Accessibility access when the welcome tour asks. Updates install automatically."
