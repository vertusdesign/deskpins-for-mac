#!/bin/bash
# Builds DeskPins.app — a menu-bar-only bundle, ad-hoc signed with a stable identifier
# so macOS keeps the Accessibility grant across rebuilds.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/DeskPins.app"
BUNDLE_ID="com.deskpins.mac"
VERSION="0.9.1"
STAGE="alpha"
APP_NAME="DeskPins for Mac"

# SwiftPM's llbuild database fails with "disk I/O error" under ~/Documents on this setup,
# so the build tree lives in the user cache. Stable path keeps builds incremental.
SCRATCH="${DESKPINS_SCRATCH:-$HOME/Library/Caches/DeskPins-build}"

cd "$ROOT"
mkdir -p "$SCRATCH"

# Universal binary, built one architecture at a time and merged with lipo.
#
# `swift build --arch arm64 --arch x86_64` is the obvious route but goes through xcbuild,
# which ships only with full Xcode — on a machine with just the Command Line Tools it fails.
# Explicit target triples need no xcbuild, so both slices build anywhere, and the app runs
# natively on Apple silicon instead of through Rosetta.
DEPLOYMENT="13.0"
SLICES=()

for ARCH in arm64 x86_64; do
    TRIPLE="$ARCH-apple-macosx$DEPLOYMENT"
    ARCH_SCRATCH="$SCRATCH-$ARCH"
    mkdir -p "$ARCH_SCRATCH"
    echo "==> building $ARCH"
    if swift build -c release --triple "$TRIPLE" --scratch-path "$ARCH_SCRATCH"; then
        SLICE="$ARCH_SCRATCH/$TRIPLE/release/DeskPins"
        # Layouts differ between toolchains; fall back to searching for the Mach-O image.
        if [ ! -x "$SLICE" ] || ! lipo -archs "$SLICE" >/dev/null 2>&1; then
            SLICE=""
            while IFS= read -r candidate; do
                if lipo -archs "$candidate" 2>/dev/null | grep -qw "$ARCH"; then
                    SLICE="$candidate"; break
                fi
            done < <(find "$ARCH_SCRATCH" -type f -perm -111 -name DeskPins \
                          -not -path '*Intermediates*' -print 2>/dev/null)
        fi
        [ -n "$SLICE" ] && SLICES+=("$SLICE")
    else
        echo "warning: could not build for $ARCH"
    fi
done

if [ "${#SLICES[@]}" -eq 0 ]; then
    echo "Build produced no binary" >&2
    exit 1
fi

BINARY="$SCRATCH/DeskPins-universal"
mkdir -p "$SCRATCH"
lipo -create "${SLICES[@]}" -output "$BINARY"
echo "==> binary: $BINARY ($(lipo -archs "$BINARY"))"

if [ "${#SLICES[@]}" -lt 2 ]; then
    echo "warning: only one architecture built; this bundle is not universal."
fi

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
# `security find-certificate` exits 44 when the certificate is absent, which under
# `set -o pipefail` would abort the whole script instead of falling back to ad-hoc signing.
CERT_SHA="$(security find-certificate -c "$CERT_NAME" -Z 2>/dev/null | awk '/SHA-1 hash/{print $3}' || true)"

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
    # Still --options runtime. The certificate is what keeps TCC grants alive across
    # rebuilds; the hardened runtime is a separate, independent protection — it is what
    # stops a local process injecting a dylib and inheriting this app's Accessibility and
    # Screen Recording grants. Dropping it from the fallback shipped release images with
    # library validation off, which is the more dangerous of the two failures.
    codesign --force --options runtime --sign - --identifier "$BUNDLE_ID" "$APP"
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
