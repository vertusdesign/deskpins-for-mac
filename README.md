# DeskPins for Mac

Keep any window above the others. A menu-bar utility for macOS, inspired by
[DeskPins](https://deskpins.com/) for Windows.

**Status: alpha (0.9.0).** The core feature works. Some rough edges remain — see
[Known limitations](#known-limitations).

> ### ⚠️ macOS will block the first launch — this is expected
>
> DeskPins for Mac is **not notarized by Apple** (notarization requires a paid Apple
> Developer account). On first launch macOS says *"Apple could not verify DeskPins is free
> of malware"* and offers only **Done** and **Move to Bin**.
>
> **Press Done**, then open **System Settings → Privacy & Security**, scroll to
> **Security**, and press **Open Anyway** next to the DeskPins line. That is it — once only.
>
> On macOS 15 and newer the old right-click → Open trick no longer works for unnotarized
> apps. If you prefer the terminal, `xattr -d com.apple.quarantine /Applications/DeskPins.app`
> does the same thing. Building from source avoids the warning entirely, because nothing is
> downloaded and so nothing is quarantined.

- Pin the frontmost window with a global shortcut (⌃⌥⌘P by default) or from the menu
- One pinned window per desktop; each desktop keeps its own
- Unpin by clicking the green pin badge on the window, or from the menu
- Configurable shortcut, which can also be switched off entirely
- Optional launch at login
- 16 interface languages
- No Dock icon, no background polling, no network access of any kind

## Install

Download the disk image from the [latest release](https://github.com/vertusdesign/deskpins-for-mac/releases/latest),
open it and drag **DeskPins.app** onto **Applications**.

One disk image covers both processor families: the app is a universal binary and runs
natively on Apple silicon and on Intel, no Rosetta involved.

**Then allow it past Gatekeeper — see the notice at the top of this page.** The app is not
notarized, so the first launch is blocked until you press **Open Anyway** in
**System Settings → Privacy & Security**. Once only.

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

## One pinned window per desktop

Pinning a window releases any pin already on the same desktop. Different desktops are
independent and keep a pin each.

This is a deliberate product limit rather than an unfinished feature. Two pinned windows on
one desktop cannot both behave correctly. Each is drawn by a panel this app owns, floating
above ordinary windows, and selecting one of them cannot lift its real window above the
other's panel — macOS has no public API for that. Both arrangements were built and both
failed: with every mirror on one level, the window being used was buried under the other pin;
with the active pin's mirror raised and made click-through, it hid the other pinned window,
and clicks passing through it landed in the mirror below, so the two swapped places on every
click and neither window could be used.

A Space has no public identity API, and none is needed here: `optionOnScreenOnly` lists only
the windows of the desktop in view, so pins living elsewhere are simply not in that list and
are left alone.

## Known limitations

- **One window can be pinned per desktop.** Pinning another releases the previous one on
  that desktop; different desktops keep their own pin. This is a deliberate limit — see
  [One pinned window per desktop](#one-pinned-window-per-desktop).

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
