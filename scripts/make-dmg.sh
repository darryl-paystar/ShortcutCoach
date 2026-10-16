#!/bin/bash
# Packs the app into a drag-to-Applications disk image: the app beside an Applications shortcut. Usage:
#   scripts/make-dmg.sh "build/Shortcut Coach.app" ShortcutCoach.dmg
set -euo pipefail
APP=$1 OUT=$2

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/$(basename "$APP")"
ln -s /Applications "$STAGE/Applications"

# hdiutil now and then fails with "Resource busy" on CI runners; a retry clears it.
for attempt in 1 2 3; do
  if hdiutil create -volname "Shortcut Coach" -srcfolder "$STAGE" -format UDZO -ov "$OUT" > /dev/null; then
    exit 0
  fi
  echo "hdiutil failed (attempt $attempt), retrying…" >&2
  sleep 5
done
exit 1
