# Changelog

All notable changes are recorded here. This project follows
[Semantic Versioning](https://semver.org/) once it reaches 1.0; until then the minor
version carries breaking changes.

## [0.9.0-alpha] — 2026-07-25

First public release.

### Added
- Pin the frontmost window above all others, via a global shortcut or the menu bar.
- Configurable global shortcut (⌃⌥⌘P by default), which can be switched off.
- Green pin badge on each pinned window; click it to unpin.
- Settings window with shortcut recorder, restore-default button, and launch at login.
- About window with version, links and attribution.
- 16 interface languages, selectable from the menu regardless of the system language.
- Launch at login via `SMAppService`.
- Drag-to-Applications disk image.

### Implementation notes
- Windows are kept on top by mirroring them into an owned floating panel with
  ScreenCaptureKit. macOS provides no public API to raise another application's window
  above the active app — see `specs/01-platform-constraints.md`.
- Mirror corner radius is read from the running system theme rather than hard-coded.
- Signed with the hardened runtime and a certificate-based designated requirement, so
  granted permissions survive rebuilds and dylib injection is blocked.

### Fixed before release
- Pinning is limited to one window per desktop; pinning another releases the previous one on
  that desktop. Two pinned windows on one desktop cannot both behave correctly — selecting
  one either buried it under the other or made clicks bounce between them — and no public API
  can lift one application's real window above a panel another application owns. Different
  desktops keep their own pin.
- With two or more windows pinned, clicking one did not give it back: its mirror was raised
  above the other pins and made click-through, so clicks fell through into the next mirror
  down, activated that pin instead, and the two swapped places on every click. All mirrors
  now share one level and the active pin shows its real window.
- Screen Recording is requested on a delay when the Accessibility prompt is also going up:
  two system prompts raised at once leave only one on screen, and the screen-recording one
  was the casualty, so the app never reached that list until the following launch.
- A pin attempt with a permission still missing now opens the relevant System Settings pane
  instead of failing quietly, since macOS only ever shows its own prompt once.
- Granting Screen Recording takes effect without quitting the app. The system preflight call
  caches its answer for the process lifetime; a ScreenCaptureKit query is used as the
  authority instead.
- Both permissions are now requested, not just the first missing one. Requesting is what
  registers an app in the System Settings list, so stopping at Accessibility left the app
  absent from Screen Recording and users had to add it by hand.
- The menu is refilled every time it opens. Permission state is read while building it, and
  at launch TCC has often not caught up, which left a stale warning row in place.

### Known limitations
- The floating copy is an image; interacting with an inactive pinned window takes one click.
- macOS marks captured windows with its own indicator, which cannot be suppressed.
- Builds are not notarized; first launch needs right-click → Open.
- Right-to-left languages are translated but the layout is not mirrored.
