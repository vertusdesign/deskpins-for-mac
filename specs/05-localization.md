# 05 — Localization

## L-1 Approach

Strings live in Swift tables in `L10n.swift`, keyed by a `StringKey` enum — not in `.lproj`
bundles. Two reasons:

1. The language is chosen **in the app**, independently of the system language, and must
   change every visible string immediately without a restart.
2. The bundle is assembled by a shell script rather than Xcode, so there is no resource
   pipeline to hang `.lproj` directories on.

A rebuild MAY use `.lproj` instead, but then it MUST still provide in-app language selection
that overrides the system language at runtime.

## L-2 Languages

Sixteen, by ISO 639-1 code:

`en`, `uk`, `ar`, `de`, `el`, `es`, `fr`, `hi`, `it`, `ja`, `ko`, `pl`, `pt`, `tr`, `vi`, `zh`

## L-3 Default and fallback

English is the default when nothing has been chosen, and the fallback for any key missing
from the selected language's table. A missing key MUST NOT render as an empty string or a
key name.

## L-4 Menu order

English and Ukrainian first, in that order. Everything else sorted by **native name** using
`localizedStandardCompare`. Languages are listed under their own names — someone looking for
their language does not know what it is called in the one currently displayed.

## L-5 Selection

The chosen language is stored in `UserDefaults` under `language`. Changing it MUST refresh
the menu and any open Settings or About window without a restart.

## L-6 Untranslated strings

- The application name **DeskPins for Mac** stays as-is in every language, including inside
  translated sentences such as "Quit DeskPins for Mac".
- Modifier symbols (⌃⌥⇧⌘) and key names are produced from the keyboard layout, not
  translated.

## L-7 String keys

| Key | English |
|---|---|
| `pinFrontmost` | Pin Frontmost Window |
| `noPinnedWindows` | No Pinned Windows |
| `pinnedHeader` | Pinned |
| `unpinAll` | Unpin All |
| `clickToUnpin` | Click to unpin |
| `settings` | Settings… |
| `language` | Language |
| `launchAtLogin` | Launch at Login |
| `quit` | Quit DeskPins for Mac |
| `accessibilityNeeded` | Accessibility Access Required… |
| `screenRecordingNeeded` | Screen Recording Access Required… |
| `noWindow` | no window |
| `shortcutTitle` | Global shortcut: |
| `shortcutRecord` | Click to record |
| `shortcutPress` | Press keys… |
| `shortcutNone` | Disabled |
| `shortcutHint` | Pins the frontmost window. Press ⌫ to disable the shortcut. |
| `shortcutRestoreDefault` | Restore Default |
| `settingsWindowTitle` | DeskPins for Mac Settings |
| `about` | About DeskPins for Mac |
| `aboutTagline` | Keeps any window above the others. |
| `aboutAlphaNotice` | Alpha version — some rough edges remain. |
| `aboutInspiredBy` | Inspired by DeskPins for Windows |
| `aboutSource` | Source code |
| `aboutTerms` | Terms of Use |
| `aboutDisclaimer` | Disclaimer |
| `aboutPrivacy` | Privacy Policy |

## L-8 Right-to-left

Arabic is translated. The layout is **not** mirrored: text renders correctly through the
bidirectional algorithm, but menu and window alignment stay left-to-right. This is a known
limitation, stated in the README, and a fair target for a future release.

## L-9 Adding a language

Add the case to `Language`, its native name, a table, and a line in the `table(_:)` switch.
The compiler will not catch a missing key — the fallback hides it — so check against L-7.
