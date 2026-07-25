# DeskPins for Mac

Keep any window above the others. A menu-bar utility for macOS, inspired by
[DeskPins](https://deskpins.com/) for Windows.

**Status: alpha (0.9.0).** The core feature works. Some rough edges remain — see
[Known limitations](#known-limitations).

- Pin the frontmost window with a global shortcut (⌃⌥⌘P by default) or from the menu
- Unpin by clicking the green pin badge on the window, or from the menu
- Configurable shortcut, which can also be switched off entirely
- Optional launch at login
- 16 interface languages
- No Dock icon, no background polling, no network access of any kind

## Install

Download the disk image from the [latest release](https://github.com/vertusdesign/deskpins-for-mac/releases/latest),
open it and drag **DeskPins.app** onto **Applications**.

The app is **not notarized by Apple**, so macOS blocks the first launch with
*"Apple could not verify DeskPins is free of malware"*. To allow it:

1. In that dialog press **Done** — never *Move to Bin*.
2. Open **System Settings → Privacy & Security** and scroll to the **Security** section.
   There is a line saying DeskPins was blocked, with an **Open Anyway** button.
3. Press it, authenticate, and confirm.

Once only. On macOS 15 and newer the old right-click → Open shortcut no longer works for
unnotarized apps; Open Anyway is the way.

If you prefer the terminal, this does the same thing by clearing the download quarantine
flag:

```bash
xattr -d com.apple.quarantine /Applications/DeskPins.app
```

### Permissions

The first time you pin a window macOS asks for two permissions. Both are required, and
both must be granted in System Settings → Privacy & Security:

| Permission | Why it is needed |
|---|---|
| **Accessibility** | To read the pinned window's position and size and follow it as it moves |
| **Screen Recording** | To draw the pinned window's live content above the other windows |

After granting them, **restart the app** — macOS does not apply new permissions to a
process that is already running.

Screen Recording sounds alarming for a window-pinning tool. It is unavoidable, and the
reason is explained in [Why it needs Screen Recording](#why-it-needs-screen-recording).
DeskPins for Mac captures only the specific windows you pin, never the screen, and the
frames never leave your machine. See [PRIVACY.md](PRIVACY.md).

## Why it needs Screen Recording

On Windows, DeskPins is one line: `SetWindowPos(hwnd, HWND_TOPMOST, …)`. Windows lets an
application change another application's z-order.

macOS does not, and there is no public API that does. Window ordering on macOS is
**application-centric**: the windows of the active application always sit above the windows
of every inactive one. `NSWindow.level` applies only to windows you own, and the
Accessibility API offers position, size and `AXRaise` — but `AXRaise` reorders a window
only *within its own application*, so it can never lift a background window above the app
you are working in.

So the window that floats is one DeskPins owns: a borderless panel at a floating level,
showing the pinned window's live content, streamed with ScreenCaptureKit and kept exactly
over the original. Clicking it brings the real window forward.

The full reasoning, including the two approaches that were tried and rejected, is in
[specs/01-platform-constraints.md](specs/01-platform-constraints.md).

## Known limitations

- **The 0.9.0-alpha disk image is Intel-only (x86_64).** It was built on an Intel Mac
  without full Xcode, which is required to link a universal binary. On Apple silicon it runs
  under Rosetta 2. A universal build is planned for the next release.

- The floating copy is an image, not the window. Interacting with a pinned window that is
  not active takes one click to bring it forward first.
- macOS marks captured windows with its own "being captured" indicator. That indicator is
  a system privacy feature and cannot be suppressed by the capturing app.
- Not notarized, so Gatekeeper blocks the first launch until you allow it in
  System Settings → Privacy & Security (see [Install](#install)).
- Right-to-left languages are translated but the layout is not mirrored.

## Build from source

Requires macOS 13 or newer and a Swift toolchain (Xcode Command Line Tools are enough).

```bash
git clone https://github.com/vertusdesign/deskpins-for-mac.git
```

```bash
cd deskpins-for-mac && ./Scripts/create-signing-cert.sh && ./Scripts/build-app.sh --install
```

`create-signing-cert.sh` is a one-time step. It creates a local, self-signed code-signing
certificate so macOS keeps your granted permissions across rebuilds; without it every
rebuild invalidates them. It is explained in
[specs/06-build-and-signing.md](specs/06-build-and-signing.md).

To produce the disk image:

```bash
./Scripts/make-dmg.sh
```

## Documentation

| Document | Contents |
|---|---|
| [specs/](specs/) | Full specification, written so the project can be rebuilt from it alone |
| [docs/architecture.ru.md](docs/architecture.ru.md) | Engineering notes in Russian, including the reasoning behind each fix |
| [PRIVACY.md](PRIVACY.md) | What the app can see, what it does with it (nothing leaves the machine) |
| [TERMS.md](TERMS.md) | Terms of use |
| [DISCLAIMER.md](DISCLAIMER.md) | No warranty, and what that means in practice |
| [SECURITY.md](SECURITY.md) | Threat model and how to report a vulnerability |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to propose changes |
| [CHANGELOG.md](CHANGELOG.md) | Release history |

## Relationship to the original DeskPins

DeskPins for Mac is an independent implementation for a different operating system,
inspired by [DeskPins](https://deskpins.com/) by Elias Fotinis. It shares no code with the
Windows original and is not affiliated with or endorsed by its author. The name is used to
credit the idea.

## Licence

[MIT](LICENSE).
