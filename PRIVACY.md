# Privacy Policy

**Last updated: 25 July 2026. Applies to DeskPins for Mac 0.9.0-alpha.**

DeskPins for Mac collects nothing, stores nothing about you, and sends nothing anywhere.
This document exists because the app requests two powerful permissions, and you deserve a
precise account of what it does with them.

## The short version

- No analytics, no telemetry, no crash reporting, no update checks, no accounts.
- The app contains **no networking code at all** — it cannot send data even in principle.
- Captured window content is displayed on your screen and discarded. It is never written to
  disk, never encoded, never transmitted.

## Permissions and what they are used for

### Accessibility

Used only to:

- find the frontmost window when you pin it, and read its title for the menu;
- read the pinned window's position and size, and follow them as it moves;
- learn which window its application currently has focused;
- call `AXRaise` to bring a pinned window forward when you ask for it.

The Accessibility API can do far more than this — read text fields, press buttons, type.
DeskPins for Mac does none of it. There is no keystroke synthesis and no reading of window
contents through Accessibility anywhere in the source.

### Screen Recording

Required by ScreenCaptureKit, which draws the pinned window's live content into the
floating copy. The capture is scoped with `SCContentFilter(desktopIndependentWindow:)` — it
captures **only the windows you explicitly pin**, never the display, never other
applications, never the menu bar.

Each captured frame is handed to a Core Animation layer as an `IOSurface` and released when
the next one replaces it. No frame is ever saved or copied elsewhere.

Capture runs only while a floating copy is on screen. When you are working in the pinned
window itself and there is nothing to overlap, the stream is stopped entirely.

## What is stored on your Mac

In `UserDefaults` (`com.deskpins.mac`), and nothing else:

| Key | Value |
|---|---|
| `language` | The interface language you picked |
| `shortcut.keyCode`, `shortcut.modifiers`, `shortcut.enabled` | Your global shortcut |

If you enable **Launch at Login**, macOS records that in its own login-item database via
`SMAppService`. You can revoke it in System Settings → General → Login Items.

No pinned-window titles, no window contents, no usage history are persisted.

## What other software may see

Two things are outside this project's control and worth knowing:

- macOS itself displays an indicator on windows that are being captured. That is a system
  privacy feature, and DeskPins for Mac cannot and should not suppress it.
- A pinned window stays visible above other applications, including over full-screen apps.
  If you pin a window with sensitive content, that content remains on screen while you work
  elsewhere, and will appear in screen shares and recordings made by other software.

## Children

The app is a desktop utility with no accounts and no data collection, and is not directed
at children.

## Changes

Any change to this policy will appear in this file and in
[CHANGELOG.md](CHANGELOG.md) with the release that introduces it.

## Questions

Open an issue at
<https://github.com/vertusdesign/deskpins-for-mac/issues>.
