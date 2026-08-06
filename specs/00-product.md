# 00 — Product

## P-1 Purpose

DeskPins for Mac keeps a chosen window visible above all other windows, including windows
of applications the user switches to afterwards. It is the macOS counterpart of the idea
behind [DeskPins](https://deskpins.com/) for Windows.

## P-2 Users and situations

Someone following a video, a chat, a reference document, a terminal running a build, or a
translation while working in another application. The window must remain visible without
being repeatedly re-raised by hand.

## P-3 Shape of the product

- A menu-bar-only application. No Dock icon, no main window, no document model.
- Pinning is a single action; unpinning is a single action reachable from the pinned window
  itself.
- The application is idle-cheap: no polling, no background work when nothing is pinned.

## P-4 In scope

- Pinning the frontmost window, and unpinning it.
- Multiple simultaneously pinned windows.
- A configurable, disableable global keyboard shortcut.
- Launch at login, off by default.
- A user-selectable interface language, independent of the system language.
- Distribution as a drag-to-Applications disk image.

## P-5 Out of scope

Deliberately not built, and a rebuild MUST NOT add them without revising this document:

- Window management beyond pinning — no tiling, snapping, resizing, or moving.
- Per-application rules, profiles, or automatic pinning.
- Window transparency, "click-through window" modes, or always-on-bottom.
- Any network feature: no update checks, no telemetry, no crash reporting, no sync.
- Anything requiring System Integrity Protection to be disabled, or injection into other
  processes.

## P-6 Non-negotiable properties

1. **No third-party dependencies.** System frameworks only.
2. **No networking code.** Not disabled — absent.
3. **Event-driven.** No timers used for polling. Timers MAY be used as bounded fallbacks
   where the OS provides no completion event; each such use MUST say so in a comment.
4. **Minimum privilege.** Only Accessibility and Screen Recording, used only as described
   in [07-security-privacy.md](07-security-privacy.md).

## P-7 Platform

macOS 13 or newer, on Apple silicon and Intel. Developed and verified on macOS 26.5.

## P-8 Release stage

0.9.1 is alpha: the core works and is verified, the edges are known and listed. The About
window and the disk image both state this.

## P-9 Naming

- Display name, shown in menus and windows: **DeskPins for Mac**.
- Bundle file name: `DeskPins.app`. **[constraint]** — users identify the app in
  `/Applications` by this name; it MUST NOT change.
- Bundle identifier: `com.deskpins.mac`. **[constraint]** — TCC permission grants are keyed
  to it. Changing it makes every user re-grant Accessibility and Screen Recording.
