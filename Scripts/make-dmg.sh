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


  ============================================================
   macOS WILL BLOCK THE FIRST LAUNCH. THIS IS EXPECTED.
  ============================================================

  This app is not notarized by Apple, because notarization
  requires a paid Apple Developer account. macOS therefore
  says it "could not verify DeskPins is free of malware" and
  offers only "Done" and "Move to Bin".

  To allow it:

    1. Press "Done".  Never press "Move to Bin".
    2. Open System Settings > Privacy & Security.
    3. Scroll down to the Security section. A line says
       DeskPins was blocked, with an "Open Anyway" button.
    4. Press it, authenticate, confirm.

  Required only once.

  On macOS 15 and newer the old right-click > Open trick no
  longer works for unnotarized apps.

  From the terminal, this does the same thing:
    xattr -d com.apple.quarantine /Applications/DeskPins.app

  Building from source avoids the warning entirely: nothing is
  downloaded, so nothing is quarantined.
  ============================================================


Installing

1. Drag DeskPins.app onto the Applications folder in this window.
   The app is a universal binary: it runs natively on Apple
   silicon and on Intel, with no Rosetta involved.
2. Open it from Applications, allowing it past Gatekeeper as
   described above. It lives in the menu bar; there is no Dock icon.
3. macOS will ask for two permissions the first time you pin a window:

   - Accessibility    — to follow the pinned window's position and size
   - Screen Recording — to draw the pinned window above the others

   Grant both in System Settings > Privacy & Security.

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
