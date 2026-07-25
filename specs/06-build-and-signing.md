# 06 — Build, signing and packaging

## S-1 Toolchain

Swift Package Manager, no Xcode project. Xcode Command Line Tools are sufficient. macOS 13
deployment target.

## S-2 Build scratch path **[constraint]**

SwiftPM's llbuild database fails with `accessing build database … disk I/O error` when the
build tree lives under `~/Documents` on some systems — compilation succeeds, linking never
runs, and no binary appears. The build script therefore puts the scratch path in
`~/Library/Caches/DeskPins-build`, overridable with `DESKPINS_SCRATCH`.

## S-3 Universal binary

The script attempts `--arch arm64 --arch x86_64` and falls back to the host architecture
alone. Cross-compiling both slices requires full Xcode; with only the Command Line Tools
SwiftPM reports a missing `xcbuild`. Release artefacts SHOULD be universal.

## S-4 Bundle

Assembled by `Scripts/build-app.sh`: binary, generated `AppIcon.icns`, and an `Info.plist`
containing at least

| Key | Value |
|---|---|
| `CFBundleName`, `CFBundleDisplayName` | `DeskPins for Mac` |
| `CFBundleIdentifier` | `com.deskpins.mac` — **MUST NOT change** (P-9) |
| `CFBundleExecutable` | `DeskPins` |
| `CFBundleIconFile` | `AppIcon` |
| `CFBundleShortVersionString` | `0.9.0` |
| `DPReleaseStage` | `alpha` — custom key, shown in About |
| `LSMinimumSystemVersion` | `13.0` |
| `LSUIElement` | `true` — menu-bar only, no Dock icon |

## S-5 Signing **[constraint]**

Sign with the local certificate created by `Scripts/create-signing-cert.sh`, with the
hardened runtime enabled:

```bash
codesign --force --options runtime --sign "$CERT_SHA" --identifier com.deskpins.mac "$APP"
```

Two separate reasons, both verified rather than assumed:

**Certificate, not ad-hoc.** An ad-hoc signature makes TCC pin the grant to the binary hash
(C-12), so every rebuild silently invalidates Accessibility and Screen Recording while the
row in System Settings still looks fine. With a certificate the requirement names the
signer. Verified by changing a string, rebuilding, and observing the `cdhash` change while
the designated requirement stayed identical.

**Hardened runtime.** Without it, library validation is off and any local process can inject
a dylib into the app and inherit its two TCC permissions. Verified by attempting
`DYLD_INSERT_LIBRARIES` injection: it succeeds without `--options runtime` and is blocked
with it.

The script falls back to an ad-hoc signature with a loud warning when no certificate exists.

## S-6 The local certificate

`Scripts/create-signing-cert.sh` creates a self-signed code-signing certificate named
`DeskPins Local Signing` in the login keychain. Notes for a rebuild:

- LibreSSL's default PKCS#12 ciphers are rejected by the macOS keychain. Export with
  `-certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1`.
- The certificate does **not** need to be trusted. `codesign` accepts an untrusted
  self-signed certificate, and Gatekeeper is not involved for a locally built app.
- The script is idempotent.
- It imports with `-A`, which lets any process use the key without prompting. This is a
  known trade-off, recorded in [07-security-privacy.md](07-security-privacy.md).

## S-7 Changing signing identity

Switching between ad-hoc and certificate, or between certificates, invalidates existing
grants once. Clear the stale rows so the user is not left with an entry that looks correct
but does nothing:

```bash
tccutil reset Accessibility com.deskpins.mac && tccutil reset ScreenCapture com.deskpins.mac
```

## S-8 Installing

`./Scripts/build-app.sh --install` copies the bundle to `/Applications`, replacing any
running copy. The app MUST be restarted after any permission change: macOS does not apply
new grants to a running process.

## S-9 Disk image

`Scripts/make-dmg.sh` builds the app, stages it with a symlink to `/Applications` and a
plain-text install note, and produces
`dist/DeskPins-for-Mac-<version>-<stage>.dmg` (UDZO, zlib level 9) plus a `.sha256`
alongside it. The installer is exactly the drag-onto-Applications convention — no custom
background, no installer package, no scripts run on the user's machine.

## S-10 Notarization

Not performed. Releases state this, and tell users about the right-click → Open detour.
Notarizing would require an Apple Developer ID; if one becomes available, notarize and
delete that paragraph from the README, DISCLAIMER and disk-image note.

## S-11 Reproducing a release

```bash
./Scripts/create-signing-cert.sh
./Scripts/make-dmg.sh
```

Then attach the `.dmg` and its `.sha256` to a GitHub release tagged `v<version>-<stage>`.
