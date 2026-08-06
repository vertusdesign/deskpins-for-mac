# 08 — Acceptance criteria

How to tell whether a rebuild actually works. Each criterion names the rule it verifies and
a way to check it. Several can be automated through the Accessibility API, which is how the
reference implementation was verified; those are marked **[scriptable]**.

## Build and signature

**AC-1** `swift build -c release` completes with no errors and no warnings.

**AC-2** `codesign -dv` on the built bundle reports `flags=0x10000(runtime)` (S-5).

**AC-3** `codesign -d -r-` reports
`identifier "com.deskpins.mac" and certificate leaf = H"…"` — no `cdhash` term (C-12).

**AC-4** Change any string, rebuild, and compare: the `CDHash` differs, the designated
requirement is identical. This is the property that keeps permissions across rebuilds.

**AC-5** `DYLD_INSERT_LIBRARIES` injection into the signed binary fails. Run the same test
against a copy signed without `--options runtime` to confirm the test is meaningful.

**AC-6** `nm -u` finds no networking, `NSTask`, `posix_spawn`, `dlopen`, `CGEventTap` or
`CGEventPost` symbols (SP-4).

## Core function

**AC-7 [scriptable]** With another application frontmost, invoking the shortcut pins its
focused window; the menu lists it as `Application — Title`.

**AC-8 [scriptable]** After switching to a third application, the pinned application has two
windows owned by DeskPins on screen — the mirror and the badge.

**AC-9** The mirror shows live content, positioned exactly over the real window, with the
system corner radius (B-26, B-28).

**AC-10 [scriptable]** Moving the pinned window moves the mirror with it; during the move
DeskPins owns zero on-screen windows, and after it ends, one again — the badge fade
(B-22 … B-24).

## Layering

**AC-11 [scriptable]** With two pinned windows, one active, `CGWindowListCopyWindowInfo`
reports layers 3 (resting mirror), 4 (active mirror) and 5 (both badges) — B-12, B-13.

**AC-12 [scriptable]** Pin one window of an application that has several. While it is
focused, DeskPins owns one on-screen window (badge only — B-9). Pin a window of another
application on the same desktop: the menu lists exactly one pinned window, the new one, and
the first pin has been released (B-9.1). Raise a sibling window: two,
because the mirror appears above the sibling (B-7).

**AC-13** Clicking the active pin's mirror interacts with the real window beneath it rather
than stopping at the image (B-14).

## Spaces and Mission Control

**AC-14** With windows pinned, create a new desktop in Mission Control and switch to it.
The system MUST stay there (B-20, C-5), and no mirror or badge from the other desktop is
visible (B-5).

**AC-15** In Mission Control, mirrors and badges are hidden (C-7).

**AC-16** Returning to the original desktop restores the mirrors and badges.

## Unpinning

**AC-17 [scriptable]** Pin a window, switch away so the mirror takes over, then unpin from
the menu: the real window's application becomes frontmost and DeskPins owns no on-screen
windows (B-18).

**AC-18** Closing a pinned window removes its pin without activating anything (B-18, B-30).

**AC-19** Quitting DeskPins removes every pin and activates nothing (B-31).

## Shortcut and settings

**AC-20** ⌘, opens Settings. The recorder shows the current shortcut.

**AC-21** Recording a new combination re-registers the hot key immediately; the old one stops
working. ⎋ cancels, ⌫ disables, a modifier-less key beeps and is rejected (U-6).

**AC-22 [scriptable]** **Restore Default** is disabled while the default shortcut is in use
and enabled otherwise.

**AC-23** Launch at Login survives a reboot, and is off in a fresh install.

## Localization and identity

**AC-24 [scriptable]** The Language submenu lists seventeen languages, English, Ukrainian and
Belarusian first, and carries the globe symbol (U-2).

**AC-25** Selecting a language changes the menu, Settings and About immediately, without a
restart (L-5).

**AC-26 [scriptable]** The menu's last three items are `About DeskPins for Mac` — carrying
the `info.circle` symbol — then `Check for Updates…` with no icon, then
`Quit DeskPins for Mac`.

**AC-26.1** `Check for Updates…` opens the releases page in the default browser. Nothing is
fetched in-process: the app has no networking code (SP-4).

**AC-27 [scriptable]** About shows the icon, `DeskPins for Mac`, `Version 0.9.1 (alpha)`,
the tagline, the alpha notice, five links with accessible titles, and the copyright line.

**AC-27.1 [scriptable]** In every language the link row clears both window edges by at least
the horizontal inset — it MUST NOT sit flush against them (U-7).

## Permissions

**AC-28** With permissions revoked, pinning does not crash, shows warning rows in the menu,
and displays no alert of the app's own (B-4).

## Resources

**AC-29** Idle with nothing pinned: 0 % CPU, roughly 23 MB resident.

**AC-30** With a single pinned window that the user is working in, no capture stream is
running (B-9).

## Packaging

**AC-31** `Scripts/make-dmg.sh` produces a disk image that mounts and contains
`DeskPins.app`, an `Applications` symlink, and the install note.

**AC-32** Dragging the app from the image to Applications and launching it works on a Mac
that has never seen the project — modulo the Gatekeeper detour (S-10).
