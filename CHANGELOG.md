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

### Known limitations
- The floating copy is an image; interacting with an inactive pinned window takes one click.
- macOS marks captured windows with its own indicator, which cannot be suppressed.
- Builds are not notarized; first launch needs right-click → Open.
- Right-to-left languages are translated but the layout is not mirrored.
