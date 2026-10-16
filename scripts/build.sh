#!/bin/bash
# Builds "Shortcut Coach.app" into ./build. Usage: scripts/build.sh [--install]
#   --install  copies the app to ~/Applications and (re)launches it.
# Signs with the "Shortcut Coach Release Signing" identity when it's in the keychain, the one releases use,
# so local builds and releases share one Accessibility grant that survives rebuilds and updates. Then
# "Shortcut Coach Local Signing", then ad-hoc ("-"). Override with SIGN_IDENTITY (looked up in
# SIGN_KEYCHAIN when set).
# ARCHS="arm64 x86_64" builds a universal binary (releases do; the default is arm64 only).
# The version is Info.plist's major.minor plus the commit count (0.1.42), and the count is also
# CFBundleVersion, the number Sparkle compares, so a local build of HEAD matches HEAD's release.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Shortcut Coach.app"
ARCHS="${ARCHS:-arm64}"
BINS=()
for arch in $ARCHS; do
  if ! swift build -c release --arch "$arch"; then
    echo "Build failed. If the project folder moved, delete .build and try again."
    exit 1
  fi
  BINS+=(".build/$arch-apple-macosx/release/ShortcutCoach")
done

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
lipo -create "${BINS[@]}" -output "$APP/Contents/MacOS/ShortcutCoach"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Copied as shipped: Sparkle signs and notarizes its own framework, and nothing loads it with library validation.
ditto .build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework \
  "$APP/Contents/Frameworks/Sparkle.framework"

BUILD=$(git rev-list --count HEAD 2>/dev/null || echo 0)
VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist).$BUILD"
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $VERSION" -c "Set CFBundleVersion $BUILD" "$APP/Contents/Info.plist"

# Neither certificate needs to be trusted: the Accessibility grant pins the certificate's hash, not its trust.
# So no -v here, which would list trusted identities only.
if [ -z "${SIGN_IDENTITY:-}" ]; then
  IDENTITIES=$(security find-identity -p codesigning)
  for id in "Shortcut Coach Release Signing" "Shortcut Coach Local Signing"; do
    if grep -q "\"$id\"" <<< "$IDENTITIES"; then SIGN_IDENTITY=$id; break; fi
  done
fi
codesign --force ${SIGN_KEYCHAIN:+--keychain "$SIGN_KEYCHAIN"} --sign "${SIGN_IDENTITY:--}" --identifier local.shortcutcoach "$APP"
codesign --verify --deep --strict "$APP"
echo "Signed with: ${SIGN_IDENTITY:-ad-hoc}"
echo "Built $APP $VERSION ($ARCHS)"

if [ "${1:-}" = "--install" ]; then
  DEST="$HOME/Applications/Shortcut Coach.app"
  mkdir -p "$HOME/Applications"
  pkill -x ShortcutCoach 2>/dev/null && sleep 0.5 || true
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  open "$DEST"
  echo "Installed and launched $DEST"
fi
