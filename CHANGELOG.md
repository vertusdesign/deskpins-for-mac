# Changelog

All notable changes are recorded here. This project follows
[Semantic Versioning](https://semver.org/) once it reaches 1.0; until then the minor
version carries breaking changes.

## [0.9.1-alpha] — 2026-08-06

### Added
- Belarusian interface language, listed third in the Language menu after Ukrainian.
- **Check for Updates…** in the menu, below About, opening the releases page in the default
  browser. The app still contains no networking code — the page is opened, never fetched.
- An `info.circle` icon on the About item. Check for Updates is deliberately left iconless:
  it opens a page rather than checking anything, and an icon would suggest an in-app updater
  that does not exist.

### Fixed
- The permission warnings opened System Settings on **General** instead of Privacy &
  Security. A `x-apple.systempreferences:` deep link loses its anchor when System Settings
  is not already running — which is exactly the first-run case the warnings exist for. The
  link is now sent a second time once the app is up. This was not an identifier problem:
  measured on macOS 26, the legacy and the current pane identifiers both fail cold and both
  work warm, so switching on the OS version would have fixed nothing.
- The row of links in the About window sat flush against both window edges in every
  language. The padding came from `NSStackView.edgeInsets`, but `fittingSize` — read before
  the stack had laid out — reports the content width with the insets left out, and the
  window was sized from it. The padding now lives in constraints, with a 420 pt minimum
  width; the row clears each edge by 28 pt at the widest and 49 pt in English.

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
- Documentation drift caught in review: the behaviour spec still mandated the click-through
  active mirror that B-9.1 forbids, the README still advertised an Intel-only image and did
  not mention the one-pin-per-desktop limit at all, and the release notes claimed both
  universal and Intel-only in the same page.
- The app ships as a universal binary and runs natively on Apple silicon. Earlier images
  carried an Intel-only build, which needed Rosetta on an M-series Mac. Each slice is built
  with an explicit target triple and merged with `lipo`, so no full Xcode is required.
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
