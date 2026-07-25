# Working on this repository

Entry point for AI coding agents — Claude Code, Codex, Copilot and anything else. Humans
will find it useful too. `CLAUDE.md` points here; there is one document, not two.

## Read this first

**macOS provides no public API to raise one application's window above another
application's.** Window ordering is application-centric: the active application's windows
are always above every inactive application's. `NSWindow.level` works only on windows you
own, and `AXRaise` reorders a window only within its own application.

This project therefore does not raise the pinned window. It **mirrors** it into a floating
panel that the app itself owns, using ScreenCaptureKit.

An implementation built on the assumption that `AXRaise` can pin a window looks correct in
review and fails on screen. That mistake was made here once already — see
[specs/01-platform-constraints.md](specs/01-platform-constraints.md) §C-3.1.

## Orientation

| If you need | Read |
|---|---|
| What the product is and is not | [specs/00-product.md](specs/00-product.md) |
| Why the design is shaped this way | [specs/01-platform-constraints.md](specs/01-platform-constraints.md) |
| Which file owns what | [specs/02-architecture.md](specs/02-architecture.md) |
| Exact required behaviour | [specs/03-behavior.md](specs/03-behavior.md) |
| How to verify a change | [specs/08-acceptance-criteria.md](specs/08-acceptance-criteria.md) |

The specification is normative. If your change contradicts a rule, change the rule in the
same commit and say why.

## Build and run

```bash
./Scripts/create-signing-cert.sh
```

```bash
./Scripts/build-app.sh --install && open /Applications/DeskPins.app
```

The certificate step is once per machine. Skipping it means macOS forgets the granted
permissions on every rebuild, which will look like a bug in your change
([specs/06](specs/06-build-and-signing.md) §S-5).

Always restart the app after installing. macOS does not apply permission grants to a running
process, and the status item is created at launch.

## Verifying behaviour without a human

Most of this app's behaviour is observable through the Accessibility API, and the reference
implementation was verified that way. Useful patterns:

```bash
osascript -e 'tell application "System Events" to tell process "DeskPins" to get name of menu items of menu 1 of menu bar item 1 of menu bar 1'
```

- Trigger the global shortcut: `key code 35 using {control down, option down, command down}`
- Count on-screen panels: `count windows of process "DeskPins"` — badge only, badge plus
  mirror, or nothing, distinguishes most states
- Window levels: `CGWindowListCopyWindowInfo` reports `kCGWindowLayer`, which is how B-12
  is checked
- `{position, size} of every window` gives geometry to check the badge offset and mirror
  alignment

Do not claim a behaviour works because the code looks right. Check it, and say how you
checked.

## House rules

1. **No third-party dependencies.** System frameworks only.
2. **No networking.** Not disabled — absent. See [specs/07](specs/07-security-privacy.md) §SP-7
   for the full list of things this app must never do.
3. **No polling.** Everything is event-driven. A `Timer` is acceptable only as a bounded
   fallback where the OS provides no completion event, and the comment must say which event
   is missing.
4. **Every window sets `isReleasedWhenClosed = false`.** The default is `true` for
   programmatically created windows and causes an over-release crash whose report points
   nowhere near the cause (§C-10).
5. **Comments explain why.** Most non-obvious code exists to work around a documented macOS
   behaviour. Name it.
6. **Do not change** the bundle identifier `com.deskpins.mac` or the bundle file name
   `DeskPins.app`. Both are load-bearing (§P-9).

## Things that look like bugs and are not

- The mirror does not appear when a single pinned window is the one you are working in.
  Intentional — nothing to overlap, so no capture runs (B-9).
- The mirror disappears while you drag the window. Intentional — a captured copy lags behind
  (B-10).
- The pinned window's mirror is click-through when active. Intentional — it holds its place
  in the stack while clicks reach the real window (B-14).
- macOS shows a capture indicator on pinned windows. Not ours, and not suppressible (C-13).
