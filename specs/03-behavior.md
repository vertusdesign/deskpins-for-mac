# 03 — Behaviour

Normative. Most of these rules are the resolution of a bug that was observed on screen; the
ones marked **[constraint]** cannot be changed without breaking something described in
[01-platform-constraints.md](01-platform-constraints.md).

## Pinning

**B-1** Pinning acts on the **frontmost window**: the focused window of the frontmost
application. The application MUST ignore its own windows when looking for it.

**B-2** Invoking the pin action on an already-pinned window unpins it.

**B-3** If no suitable window is found, the app MUST NOT fail silently: it briefly labels
the menu-bar icon and does nothing else.

**B-4** Pinning requires both permissions. If either is missing, the app triggers the
system's own permission dialog, flags it in the menu, and does not pin. It MUST NOT show an
alert of its own — that alert appears on top of the system dialog and hides it.

## Placement

Each pin has a placement, recomputed by `PinManager` on every event in A-5:

- `onCurrentSpace` — the window's `CGWindowID` is in the on-screen list (C-6)
- `isActive` — the window's application is frontmost **and** the application's
  `AXFocusedWindow` is this window
- `hasCompany` — at least one other pin is on the current Space

**B-5** A pin whose window is **not on the current Space** MUST hide both its mirror and its
badge. **[constraint]** Otherwise `canJoinAllSpaces` leaves them floating over an unrelated
desktop.

**B-6** A minimized window's pin hides both, and restores them on deminiaturize.

**B-7 "Active" means the user is working in *this window*, not merely in its application.**
When another window of the same application is raised over the pinned one, the pinned window
is no longer active and its mirror MUST appear. This is what keeps a pinned Finder window
above its siblings. Detected via `kAXFocusedWindowChangedNotification` observed on the
**application** element.

## Mirror visibility

**B-8** The mirror is shown whenever the pin is on the current Space and not minimized,
**except** in the two cases below, where the real window is right there and better.

**B-9** Not shown when the pin is active — the user is working in that window, so the real
one is what should receive input, and no capture is started at all.

**B-9.1** All mirrors MUST share one window level, and the active pin's mirror MUST NOT be
raised above the others and made click-through. That was tried and MUST NOT be reintroduced:
the raised mirror covers the other pinned windows, which is the opposite of pinning them, and
a click passing through it lands in the next mirror down, activating that pin — the two then
swap levels on every click and neither window can be used.

The consequence is accepted deliberately: the window being worked in sits below the other
pinned windows. That is what pinning those windows means, and no public API can lift another
application's real window above a panel we own.

**B-10** Not shown while its window is being dragged: a captured copy lags behind the window
it mirrors, which reads as smearing.

**B-11** Capture runs only while the mirror is visible. Hiding it MUST stop the stream, not
merely hide the panel.

## Layering

**B-12** Window levels, and nothing between them:

| Element | Level |
|---|---|
| Resting mirror | `.floating` (3) |
| Active pin's mirror | `.floating + 1` (4) |
| Pin badge | `.floating + 2` (5) |

**B-13** The mirror of the **active** pin sits above the other mirrors, so selecting a
pinned window brings it above the other pinned windows rather than below them.

**B-14** The active pin's mirror MUST be click-through (`ignoresMouseEvents = true`). It
holds its place in the stack while every click, scroll and drag reaches the real window
directly beneath it. Non-active mirrors MUST NOT be click-through — clicking one is how the
user selects that window.

**B-15** The badge MUST NOT use `.screenSaver` or any level above the mirrors. An ordinary
application has no business drawing over system UI or the screen saver.

## Interaction

**B-16** Clicking a non-active mirror raises the real window (`AXRaise`) and activates its
application.

**B-17** Clicking the badge unpins.

**B-18** Unpinning a window whose real window is buried behind other applications MUST bring
that window forward. Otherwise the mirror simply vanishes and the window appears to have
been lost. This applies to explicit unpinning only — a window that was closed, or an
application that quit, has nothing to reveal, and quitting DeskPins MUST NOT activate other
applications.

**B-19** "Unpin All" does not bring windows forward: activating several applications in
sequence produces focus churn and possible Space switches, and only the last would win.

## Raising

**B-20** `AXRaise` MUST NOT be called for a window that is not on the current Space.
**[constraint]** C-5 — doing so drags macOS back to that Space, which is what makes a new
desktop appear impossible to switch to.

**B-21** Raising is permitted only in response to an application activation or a direct user
action. A Space change MUST recompute placement without raising anything.

## Dragging

**B-22** On the first move notification the badge fades out over 0.1 s and stops being
positioned. **[constraint]** C-4.

**B-23** The drag ends on left mouse-up, watched with both a global and a local `NSEvent`
monitor. The badge is repositioned once, at the window's final location, and fades in over
0.12 s.

**B-24** A 0.4 s idle fallback ends the drag when no mouse-up arrives — keyboard moves,
Stage Manager, another application moving the window.

**B-25** A drag ending mid-fade MUST NOT leave the badge invisible.

## Geometry

**B-26** The mirror is positioned exactly over the window it mirrors and follows move and
resize events.

**B-27** A resize invalidates the stream's fixed output size; the stream is rebuilt,
debounced by 0.2 s.

**B-28** The mirror's corners use the system window corner radius (C-9) with
`cornerCurve = .continuous`, and the panel is non-opaque so the corners are transparent.

**B-29** The badge sits at the window's top-right corner, offset so that it overhangs by
6 pt in each direction.

## Lifecycle

**B-30** A pin is removed when its window is destroyed, when its application terminates, or
when capture fails irrecoverably.

**B-31** Quitting removes all pins and stops all capture.

**B-32** The status-bar menu briefly makes DeskPins frontmost. Placement recomputation MUST
ignore that and leave the pins as they are.
