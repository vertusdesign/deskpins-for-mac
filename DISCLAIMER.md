# Disclaimer

## No warranty

DeskPins for Mac is provided **as is**, without warranty of any kind. The full legal text
is in the [MIT Licence](LICENSE). Nobody is obliged to fix anything, support anything, or
keep anything working.

## This is alpha software

Version 0.9.0 is labelled alpha deliberately. The core feature — keeping a window above the
others — works and has been tested. Around it there are known rough edges, listed in the
[README](README.md#known-limitations) and in
[specs/08-acceptance-criteria.md](specs/08-acceptance-criteria.md).

Do not use it where a failure would cost you something.

## What the app can see

To do its job the application holds two of the most powerful permissions macOS grants:
Accessibility and Screen Recording. It uses them narrowly, and
[PRIVACY.md](PRIVACY.md) describes exactly how. Since the source is open, you are
encouraged to verify that rather than take anyone's word for it.

If you are not comfortable granting those permissions, do not install the application.
There is no version of it that works without them, because macOS provides no other way to
place a window above another application's.

## Pinned windows stay visible

A pinned window remains on screen while you work in other applications, and above
full-screen apps. It will be visible to anyone who can see your screen, and it will appear
in screen shares and recordings made by other software. Think before pinning a password
manager, a private conversation, or anything else you would not put on a projector.

## Not notarized by Apple

Builds are signed with a local certificate, not an Apple Developer ID, and are not
notarized. macOS Gatekeeper blocks the first launch and says Apple could not verify the app; that
warning is accurate — nobody has scanned this build but its author. Allow it in
System Settings → Privacy & Security → Open Anyway if you accept that. Only
download builds from
<https://github.com/vertusdesign/deskpins-for-mac/releases> and check the published
SHA-256 if you care to.

## Not affiliated

This project is not affiliated with, endorsed by, or connected to Elias Fotinis, the author
of the original Windows DeskPins, or to Apple Inc.
