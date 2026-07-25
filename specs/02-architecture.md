# 02 — Architecture

## A-1 Shape

A single executable target, no dependencies, plain AppKit. Roughly 1 500 lines of Swift.

```
main.swift ──> AppDelegate ──> PinManager ──> Pin ──> WindowMirror  (floating copy)
                    │              │           └───> PinMarker     (green badge)
                    │              └── WindowFinder  (window identity)
                    ├── SettingsWindowController + ShortcutRecorderView
                    ├── AboutWindowController
                    ├── HotKeyCenter ── Shortcut ── Settings
                    ├── L10n
                    └── LaunchAtLogin
```

## A-2 Files and responsibilities

| File | Owns |
|---|---|
| `main.swift` | Creates `NSApplication`, installs the delegate, runs. |
| `AppDelegate.swift` | Status item and menu, permission prompting, window controllers. Holds no pin state. |
| `PinManager.swift` | The set of pins. Decides, on every relevant event, what each pin's placement is. |
| `Pin.swift` | One pinned window: AX handle, its mirror and badge, its AX subscriptions, drag detection. |
| `WindowMirror.swift` | The floating panel and its ScreenCaptureKit stream. |
| `PinMarker.swift` | The green badge panel and its drawing, positioning and fades. |
| `WindowFinder.swift` | Turning "the frontmost window" into a `(AXUIElement, CGWindowID, pid, name)` tuple; Space membership. |
| `AX.swift` | Typed wrappers over the Accessibility C API; Quartz ↔ Cocoa coordinate conversion. |
| `SystemMetrics.swift` | Values read from the running theme — currently the window corner radius. |
| `Shortcut.swift` | Shortcut model, layout-aware display string, persistence. |
| `HotKey.swift` | Carbon hot-key registration, and suspend/resume while recording. |
| `SettingsWindow.swift` | Settings window and the shortcut recorder control. |
| `About.swift` | About window, outbound links, bundle-derived app identity. |
| `LaunchAtLogin.swift` | `SMAppService` wrapper. |
| `L10n.swift` | Languages, string keys, tables, selection. |

## A-3 Ownership rules

- **`PinManager` decides, `Pin` executes.** A `Pin` never inspects the frontmost
  application or the Space; it is told its placement and applies it. This keeps the policy
  in one readable place.
- **`AppDelegate` holds no pin state.** It renders the menu from `PinManager.pins` and
  forwards actions.
- **`WindowMirror` and `PinMarker` know nothing about pinning.** They are told where to be,
  what level to use, and whether to be visible.

## A-4 Window identity

Three subsystems each know part of the truth and none knows all of it:

| Subsystem | Provides | Lacks |
|---|---|---|
| `CGWindowList` | z-order, geometry, `CGWindowID`, Space membership | Accessibility handles |
| Accessibility | live move/resize/close events, `AXRaise`, focus | any notion of a window ID |
| ScreenCaptureKit | the pixels | needs a `CGWindowID` |

`WindowFinder` bridges them by matching owner pid plus frame, within an 8 pt tolerance, and
returns all identifiers together. A rebuild MUST keep this bridging in one place; scattering
it produces windows that are found by one subsystem and lost by another.

## A-5 Events consumed

No polling anywhere. Every state change comes from one of:

| Source | Notification | Effect |
|---|---|---|
| `AXObserver` on the window | moved, resized | reposition mirror and badge; start drag handling |
| | miniaturized / deminiaturized | hide / restore |
| | destroyed | remove the pin |
| `AXObserver` on the **application** | focused window changed | recompute which pin is active |
| `NSWorkspace` | app activated | recompute placement, raising allowed |
| | active Space changed | recompute placement, raising **not** allowed (C-5) |
| | app terminated | remove that app's pins |
| Carbon | hot key pressed | pin or unpin the frontmost window |
| `NSEvent` monitors | left mouse up | end of a window drag (C-4) |

## A-6 Coalescing

Application switches emit several notifications in a burst. `PinManager` coalesces them
into one recomputation after 50 ms. If any pending trigger permitted raising, the coalesced
run permits it.

## A-7 Threading

Everything is main-thread. The only exception is the ScreenCaptureKit sample-buffer
callback, which arrives on a private serial queue and hops to the main thread to hand the
`IOSurface` to the layer, retaining the pixel buffer until it is replaced.
