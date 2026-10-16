#!/bin/bash
# Prints a one-item Sparkle appcast for a release. Usage:
#   scripts/make-appcast.sh <app> <zip> <download-url> <notes-file> > appcast.xml
# The version comes from the app's Info.plist; the notes file is one change per line.
# Signs with the EdDSA key in SPARKLE_KEY_FILE, or the "ShortcutCoach" key in the keychain when unset.
set -euo pipefail
APP=$1 ZIP=$2 URL=$3 NOTES=$4

plist() { /usr/libexec/PlistBuddy -c "Print $1" "$APP/Contents/Info.plist"; }
escape() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

SIGN_UPDATE="$(dirname "$0")/../.build/artifacts/sparkle/Sparkle/bin/sign_update"
if [ -n "${SPARKLE_KEY_FILE:-}" ]; then
  SIGNATURE=$("$SIGN_UPDATE" --ed-key-file "$SPARKLE_KEY_FILE" "$ZIP")
else
  SIGNATURE=$("$SIGN_UPDATE" --account ShortcutCoach "$ZIP")
fi

cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Shortcut Coach</title>
    <item>
      <title>$(plist CFBundleShortVersionString)</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$(plist CFBundleVersion)</sparkle:version>
      <sparkle:shortVersionString>$(plist CFBundleShortVersionString)</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$(plist LSMinimumSystemVersion)</sparkle:minimumSystemVersion>
      <description><![CDATA[<ul>
$(escape < "$NOTES" | sed -e 's/^- //' -e 's|.*|<li>&</li>|')
</ul>]]></description>
      <enclosure url="$URL" type="application/octet-stream" $SIGNATURE />
    </item>
  </channel>
</rss>
EOF
