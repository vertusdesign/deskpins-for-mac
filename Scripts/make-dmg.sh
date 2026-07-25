#!/bin/bash
# Builds the drag-to-Applications disk image.
#
#     ./Scripts/make-dmg.sh
#
# Produces dist/DeskPins-for-Mac-<version>-<stage>.dmg containing the app and a symlink to
# /Applications, which is the whole installer: drag one onto the other.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/DeskPins.app"
DIST="$ROOT/dist"

"$ROOT/Scripts/build-app.sh" >/dev/null
test -d "$APP" || { echo "No app bundle at $APP" >&2; exit 1; }

PLIST="$APP/Contents/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PLIST")"
STAGE="$(/usr/libexec/PlistBuddy -c 'Print DPReleaseStage' "$PLIST" 2>/dev/null || echo '')"
VOLUME="DeskPins for Mac"
NAME="DeskPins-for-Mac-$VERSION${STAGE:+-$STAGE}"
DMG="$DIST/$NAME.dmg"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

cp -R "$APP" "$STAGING/DeskPins.app"
ln -s /Applications "$STAGING/Applications"

# A short README on the image itself, for the permissions the app cannot grant for you.
cat > "$STAGING/READ ME FIRST.txt" <<'TXT'
DeskPins for Mac — installation

1. Drag DeskPins.app onto the Applications folder in this window.
2. Open it from Applications. It lives in the menu bar; there is no Dock icon.
3. macOS will ask for two permissions the first time you pin a window:

   - Accessibility   — to follow the pinned window's position and size
   - Screen Recording — to draw the pinned window above the others

   Grant both in System Settings > Privacy & Security, then restart the app.
   macOS does not apply new permissions to an already running process.

The app is not notarized by Apple, so macOS blocks the first launch with
"Apple could not verify DeskPins is free of malware".

To allow it:
  1. Press "Done" in that dialog. Never press "Move to Bin".
  2. Open System Settings > Privacy & Security and scroll to Security.
     A line says DeskPins was blocked, with an "Open Anyway" button.
  3. Press it, authenticate, confirm.

Required only once. On macOS 15 and newer the old right-click > Open
shortcut no longer works for unnotarized apps.

Source, licence and terms: https://github.com/vertusdesign/deskpins-for-mac
TXT

mkdir -p "$DIST"
rm -f "$DMG"
hdiutil create \
    -volname "$VOLUME" \
    -srcfolder "$STAGING" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    -quiet \
    "$DMG"

echo "Disk image: $DMG  ($(du -h "$DMG" | cut -f1))"
shasum -a 256 "$DMG" | tee "$DMG.sha256"
