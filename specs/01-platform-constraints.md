# 01 — Platform constraints

Read this before writing code. Every awkward decision in the architecture follows from
this document.

## C-1 The Windows implementation does not translate

On Windows, DeskPins is essentially one call:

```c
SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
```

Windows lets a process change another process's window z-order. macOS does not.

## C-2 macOS window ordering is application-centric **[constraint]**

The windows of the **active application** always sit above the windows of every inactive
application, for ordinary window levels. This is a property of the window server, not a
per-window setting.

Consequences:

- `NSWindow.level` applies only to windows your own process owns. There is no public API to
  set the level of another application's window.
- `AXRaise` reorders a window **only within its own application's** window list. It cannot
  lift a background application's window above the application the user is working in.

## C-3 Approaches evaluated

### C-3.1 Accessibility re-raising — rejected, does not work

Subscribe to application activation and call `AXRaise` on the pinned window each time.

Fails by C-2. The window is raised correctly *inside its own application* and remains below
the windows of whatever application is active. This was implemented, shipped to a test user,
and observed to fail. Do not revisit it.

### C-3.2 Private SkyLight API — rejected, unacceptable cost

`SLSSetWindowLevel` can set another window's level, but changing a window owned by another
process requires a privileged window-server connection. In practice this means injecting
into `Dock.app` with System Integrity Protection partially disabled — the approach used by
tiling window managers. It breaks with macOS updates and cannot be asked of ordinary users.

### C-3.3 Mirroring into an owned window — adopted

A window **the application itself owns** does obey `NSWindow.level`. So the thing that
floats is a borderless panel owned by DeskPins, displaying the live content of the target
window captured with ScreenCaptureKit, positioned exactly over the original.

Cost: Screen Recording permission, and the floating copy is an image rather than the window.
Both are accepted and mitigated in [03-behavior.md](03-behavior.md).

## C-4 Accessibility reports moves but never their end **[constraint]**

`kAXWindowMovedNotification` fires continuously during a drag. There is no
"drag finished" notification. Detect the end from a mouse-up event
(`NSEvent.addGlobalMonitorForEvents` / `addLocalMonitorForEvents`, which need no extra
permission for mouse events), with a short idle timer as fallback for moves that never
involve the mouse — keyboard moves, Stage Manager, another application.

## C-5 `AXRaise` across Spaces switches Spaces **[constraint]**

Calling `AXRaise` on a window that lives on another Space makes macOS switch to that Space.
Since switching to a new desktop also changes the frontmost application, an activation
handler that raises pinned windows will drag the user straight back. Raising MUST be guarded
by a check that the window is on the current Space.

## C-6 Space membership is discoverable **[constraint]**

`CGWindowListCopyWindowInfo` with `optionOnScreenOnly` lists only windows on the Space the
user is currently viewing. Comparing a pinned window's `CGWindowID` against that list is the
supported way to answer "is this window on the current desktop".

Collection behaviour alone is not enough: `canJoinAllSpaces` shows an owned panel on every
desktop, and `transient` (which is what hides it in Mission Control) does not restrict it to
one. Visibility across Spaces MUST therefore be decided explicitly.

## C-7 Collection behaviour flags that matter **[constraint]**

`managed`, `transient` and `stationary` are mutually exclusive; the last one set wins.

- `stationary` means *unaffected by Exposé* — the panel stays visible over Mission Control.
- `transient` means *hidden by Exposé* — the correct choice for both the mirror and the
  badge.

## C-8 Panels animate when ordered in **[constraint]**

`NSPanel.animationBehavior` defaults to `.default`, which for a panel resolves to the
utility-window animation. It reads as the mirror "popping" into existence. Set `.none`.

## C-9 Window corner radius is not exposed

There is no public API for the system window corner radius. It can be read from a throwaway
titled window's frame view via the `cornerRadius` key (16.0 on macOS 26.5), guarded by
`responds(to:)` and a range check, with a per-version constant as fallback. Prefer this to
hard-coding, so the app keeps matching after an OS update.

## C-10 `NSWindow` created in code releases itself on close **[constraint]**

`isReleasedWhenClosed` defaults to `true` for programmatically created windows. Calling
`close()` on a window ARC still owns causes an over-release and a crash at the next
autorelease-pool pop. Every window and panel this app creates MUST set it to `false`.

This caused a shipped crash. The crash report points at `objc_release` inside
`objc_autoreleasePoolPop`, far from the offending code.

## C-11 Global shortcuts: Carbon, not an event tap **[constraint]**

`RegisterEventHotKey` reports only the combination registered, costs nothing while idle, and
needs no additional permission. A `CGEventTap` would observe every keystroke in the system
and require Input Monitoring. Use Carbon.

## C-12 TCC grants are pinned to the code signature **[constraint]**

An ad-hoc signature carries no identity, so macOS pins the permission to the binary's
`cdhash`:

```
designated => cdhash H"…"
```

Every rebuild changes the hash and silently invalidates the grant, while the row remains
visible in System Settings looking healthy. Signing with a certificate — even a local,
self-signed, untrusted one — produces:

```
designated => identifier "com.deskpins.mac" and certificate leaf = H"…"
```

which survives rebuilds. See [06-build-and-signing.md](06-build-and-signing.md).

## C-13 System capture indicator cannot be suppressed

macOS marks windows that are being captured with its own indicator. It is a privacy feature
and there is no API to hide it. `SCStreamConfiguration.includeChildWindows = false` is the
only related lever, and it also drops sheets and popovers from the capture.
