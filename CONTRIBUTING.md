# Contributing

Bug reports, ideas and patches are all welcome. This is a small project maintained in spare
time, so please be patient with response times.

## Before you start

Read [specs/](specs/). The specification is normative: it describes what the app must do
and why, including several behaviours that look like bugs until you know the macOS
constraint behind them. A change that contradicts a spec rule should update the rule in the
same pull request, with the reasoning.

## Reporting a bug

Include:

- macOS version and Mac model
- app version (menu → About DeskPins for Mac)
- what you expected and what happened
- whether any window was pinned at the time, and how many

Window-layering bugs are often specific to the number of pinned windows, whether their
application was active, and which Space they were on. Mention all three.

## Development

```bash
./Scripts/create-signing-cert.sh   # once
```

```bash
./Scripts/build-app.sh --install
```

The app must be restarted after installing. macOS does not apply permission grants to a
running process, and the menu bar item is only created at launch.

### House rules

- No third-party dependencies. The app links only system frameworks, and that is a feature.
- No polling. Everything is event-driven: `AXObserver`, `NSWorkspace` notifications, Carbon
  hot keys. If you find yourself reaching for a `Timer`, look for the event first.
- Comments explain *why*, not *what*. Most of the non-obvious code exists to work around a
  documented macOS behaviour; say which one.
- Verify claims. If you assert that something works, say how you checked.

## Pull requests

Keep them focused. Describe the behaviour before and after, and how you verified it. If the
change affects anything in `specs/08-acceptance-criteria.md`, say which criteria you re-ran.

## Translations

Strings live in `Sources/DeskPins/L10n.swift` as tables keyed by `StringKey`. To add or fix
a language, edit the table — English is the fallback for anything missing. Keep the app name
"DeskPins for Mac" untranslated.

## Code of conduct

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
