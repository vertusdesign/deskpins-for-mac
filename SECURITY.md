# Security

## Reporting a vulnerability

Report privately through GitHub's
[security advisory form](https://github.com/vertusdesign/deskpins-for-mac/security/advisories/new)
rather than a public issue. Please include the macOS version, the app version, and the
steps to reproduce.

This is a hobby project maintained without a schedule. Expect a first response within a
couple of weeks, and no guaranteed fix timeline.

## Why this project takes security seriously

DeskPins for Mac holds Accessibility and Screen Recording permission. An attacker who
subverted it would inherit both. That makes a few properties worth stating explicitly, all
of which can be checked against the source.

## What the app does not do

Verified against the built binary, not just the source:

- **No networking.** No network framework is linked and no networking symbol appears in the
  binary. It cannot exfiltrate anything.
- **No code execution.** No `NSTask`, no `posix_spawn`, no `dlopen`.
- **No input monitoring.** No `CGEventTap` and no `CGEventPost`. The global shortcut uses
  Carbon's `RegisterEventHotKey`, which reports only the one combination it registered and
  requires no Input Monitoring permission — unlike an event tap, which would see every
  keystroke in the system.
- **No entitlements, no URL schemes, no XPC services, no listening sockets** — there is no
  external attack surface to reach.

## Hardening

- The app is signed with the **hardened runtime** enabled. This turns on library
  validation, which prevents a local process from injecting a dylib
  (`DYLD_INSERT_LIBRARIES`) into DeskPins and inheriting its TCC permissions. This was a
  real finding during development, fixed and then verified by attempting the injection with
  and without the flag.
- The designated requirement is certificate-based
  (`identifier "com.deskpins.mac" and certificate leaf = H"…"`), so a replaced binary
  signed by anyone else does not inherit granted permissions.

## Known residual risks

- **The local signing key.** `Scripts/create-signing-cert.sh` imports the certificate with
  an ACL that lets any process use it to sign code without prompting. An attacker who
  already runs code as you could sign a binary that inherits the app's permissions. To
  tighten this, remove the certificate and re-import it without `-A`, or keep it in a
  separate password-protected keychain, at the cost of a prompt on every build.
- **Not notarized.** Distributed builds do not go through Apple's malware scanning. Verify
  the published SHA-256 of the disk image.
- **Pinned windows are visible.** A pinned window stays on screen above other applications
  and appears in screen shares. This is the feature, but it is also an information-exposure
  risk worth managing.
- **UI overlay.** Any app that can draw a floating window can, in principle, be used to
  overlay misleading UI. DeskPins only ever displays the live content of windows the user
  explicitly pinned, and marks each one with a visible badge.

## Scope

In scope: anything that lets a third party use the app to gain access it could not
otherwise obtain, or that makes the app leak captured content.

Out of scope: the fact that pinned windows are visible on screen; macOS's own capture
indicator; Gatekeeper warnings on unnotarized builds.
