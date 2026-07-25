#!/bin/bash
# Builds DeskPins.app — a menu-bar-only bundle, ad-hoc signed with a stable identifier
# so macOS keeps the Accessibility grant across rebuilds.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/DeskPins.app"
BUNDLE_ID="com.deskpins.mac"
VERSION="0.9.0"
STAGE="alpha"
APP_NAME="DeskPins for Mac"

# SwiftPM's llbuild database fails with "disk I/O error" under ~/Documents on this setup,
# so the build tree lives in the user cache. Stable path keeps builds incremental.
SCRATCH="${DESKPINS_SCRATCH:-$HOME/Library/Caches/DeskPins-build}"

cd "$ROOT"
mkdir -p "$SCRATCH"

# Universal binary when the toolchain can cross-compile, otherwise host-only.
# `${arr[@]+...}` keeps bash 3.2 (the system bash) from tripping over an empty array under `set -u`.
ARCH_FLAGS=(--arch arm64 --arch x86_64)
if ! swift build -c release --scratch-path "$SCRATCH" "${ARCH_FLAGS[@]}" 2>/dev/null; then
    echo "Universal build unavailable, building for the host architecture only."
    ARCH_FLAGS=()
    swift build -c release --scratch-path "$SCRATCH"
fi

BIN_DIR="$(swift build -c release --scratch-path "$SCRATCH" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path 2>/dev/null || true)"
BINARY="$BIN_DIR/DeskPins"

# A universal build goes through xcbuild, whose product layout `--show-bin-path` does not
# report — it fails outright there. Fall back to locating the executable in the scratch tree.
if [ ! -x "$BINARY" ]; then
    BINARY="$(find "$SCRATCH" -type f -perm -111 -name DeskPins -path '*Release*' 2>/dev/null | head -1)"
fi
test -x "${BINARY:-}" || { echo "Build produced no binary under $SCRATCH" >&2; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/DeskPins"

# The icon is generated from the same drawing the pin marker uses, so it never drifts.
# Rendering goes through AppKit, which needs a window server: on a headless CI runner it
# cannot work, and an icon is not worth failing a build check over.
if ! swift "$ROOT/Scripts/make-icon.swift" "$APP/Contents/Resources/AppIcon.icns" >/dev/null 2>&1; then
    echo "warning: could not render the app icon (no window server?); bundle has no icon."
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>DeskPins</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>DPReleaseStage</key><string>$STAGE</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticTermination</key><false/>
    <key>NSSupportsSuddenTermination</key><false/>
</dict>
</plist>
PLIST

# Sign with the local certificate when it exists. That is what keeps the Accessibility and
# Screen Recording grants alive across rebuilds: a certificate-based designated requirement
# names the signer, while an ad-hoc one can only name the binary's hash, which changes on
# every build. Run Scripts/create-signing-cert.sh once to set it up.
CERT_NAME="DeskPins Local Signing"
CERT_SHA="$(security find-certificate -c "$CERT_NAME" -Z 2>/dev/null | awk '/SHA-1 hash/{print $3}')"

if [ -n "$CERT_SHA" ]; then
    # --options runtime turns on the hardened runtime, which enables library validation.
    # Without it any local process can inject a dylib into DeskPins and inherit its
    # Accessibility and Screen Recording grants — the app holds two of the most powerful
    # TCC permissions, so this matters more here than for an ordinary app.
    codesign --force --options runtime --sign "$CERT_SHA" --identifier "$BUNDLE_ID" "$APP"
else
    echo "warning: no local signing certificate — falling back to an ad-hoc signature."
    echo "         macOS will then forget the granted permissions on every rebuild."
    echo "         Fix once with: ./Scripts/create-signing-cert.sh"
    codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
fi

echo "Built:  $APP  ($(lipo -archs "$APP/Contents/MacOS/DeskPins"))"

# `--install` puts the bundle in /Applications, replacing any running copy.
if [ "${1:-}" = "--install" ]; then
    DEST="${DESKPINS_DEST:-/Applications}/DeskPins.app"
    pkill -x DeskPins 2>/dev/null || true
    sleep 1
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    echo "Installed: $DEST"
    echo "Run:       open \"$DEST\""
else
    echo "Run:    open \"$APP\""
fi
