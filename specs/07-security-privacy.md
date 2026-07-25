# 07 — Security and privacy

## SP-1 Why this needs its own document

The application holds Accessibility and Screen Recording permission. Anything that subverts
it inherits both. The design therefore aims at a small, checkable surface rather than at
defence in depth.

## SP-2 Permission use, exhaustively

**Accessibility** is used for exactly: reading a window's position, size and title; reading
an application's focused window; subscribing to move, resize, minimize, destroy and
focus-changed notifications; and calling `AXRaise`. There MUST be no keystroke synthesis, no
reading of field contents, and no pressing of other applications' controls.

**Screen Recording** is used only through
`SCContentFilter(desktopIndependentWindow:)` — a filter naming one window. The app MUST NOT
capture a display, and MUST NOT capture any window that is not currently pinned.

## SP-3 Data handling

Frames are handed to a `CALayer` as an `IOSurface` and released when replaced. No frame is
written to disk, encoded, or copied elsewhere. Persisted state is limited to the language
and the shortcut, in `UserDefaults`.

## SP-4 Properties to preserve

A rebuild MUST keep all of these, and they are verifiable against the built binary:

| Property | How to check |
|---|---|
| No networking | `nm -u` shows no networking symbols; `otool -L` links no networking framework |
| No code execution | no `NSTask`, `posix_spawn`, `dlopen` |
| No input monitoring | no `CGEventTap` / `CGEventPost`; the hot key is Carbon (C-11) |
| No external surface | no entitlements, URL schemes, XPC services or listening sockets |
| Hardened runtime | `codesign -dv` reports `flags=0x10000(runtime)` |
| Signature-stable grants | `codesign -d -r-` shows a certificate leaf, not a `cdhash` |

## SP-5 Findings fixed during development

Recorded because both were real and both are easy to reintroduce.

1. **Hardened runtime was not enabled.** Library validation was off, so
   `DYLD_INSERT_LIBRARIES` injection succeeded and would have inherited both TCC
   permissions. Fixed with `--options runtime`; verified by attempting the injection with
   and without it, including a control run to prove the test was not a false negative.
2. **The pin badge lived at `.screenSaver` level** (1000), above system UI and the screen
   saver. Lowered to just above the mirrors (B-12, B-15).

## SP-6 Residual risks

- **Local signing key.** Imported with an ACL that allows any process to sign with it
  (S-6). An attacker already executing code as the user could sign a binary that inherits
  the app's permissions. Mitigation, at the cost of a prompt per build: re-import without
  `-A`, or keep the key in a separate password-protected keychain.
- **Not notarized.** No Apple malware scanning on distributed builds. Publish and check the
  SHA-256.
- **Pinned content is visible.** By design, and therefore also visible to anyone watching
  the screen and to any screen-sharing software. Stated in the README, DISCLAIMER and
  PRIVACY documents rather than hidden.
- **UI overlay potential.** Any application able to draw a floating window could overlay
  misleading UI. This one displays only live content of windows the user explicitly pinned,
  and marks each with a visible badge.

## SP-7 Things the app must never do

Listed so that a future contributor — human or AI — recognises them as out of bounds rather
than as reasonable features:

- Add networking of any kind, including update checks and crash reporting.
- Capture a display, or a window that is not pinned.
- Persist or transmit captured frames.
- Use a `CGEventTap`, or request Input Monitoring.
- Suppress macOS's capture indicator (C-13), or any other system privacy indicator.
- Require System Integrity Protection to be disabled, or inject into another process.

## SP-8 Reporting

`SECURITY.md` at the repository root. Private security advisories, not public issues.
