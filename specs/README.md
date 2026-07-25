# Specification

This directory is the normative description of DeskPins for Mac. It is written to be
sufficient on its own: given only these documents, a competent developer — or an AI coding
agent — should be able to rebuild the application from an empty directory and arrive at the
same behaviour.

The source tree is the implementation. Where the two disagree, that is a bug in one of
them, and the pull request that fixes it should say which.

## Reading order

| Document | Answers |
|---|---|
| [00-product.md](00-product.md) | What this is, who it is for, what it deliberately does not do |
| [01-platform-constraints.md](01-platform-constraints.md) | Why the obvious implementation is impossible on macOS, and what was tried |
| [02-architecture.md](02-architecture.md) | The components and what each one owns |
| [03-behavior.md](03-behavior.md) | Normative behaviour rules — the heart of the spec |
| [04-user-interface.md](04-user-interface.md) | Menu, settings, about, badge, icon |
| [05-localization.md](05-localization.md) | Languages, string keys, selection rules |
| [06-build-and-signing.md](06-build-and-signing.md) | Building, signing, why the certificate matters, packaging |
| [07-security-privacy.md](07-security-privacy.md) | Threat model, permissions, hardening |
| [08-acceptance-criteria.md](08-acceptance-criteria.md) | How to verify a rebuild actually works |

## Conventions

- **MUST / MUST NOT / SHOULD / MAY** carry their [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119)
  meanings.
- Rules are numbered per document (`B-12` is rule 12 of `03-behavior.md`) so that code
  comments, issues and acceptance criteria can cite them.
- Rules marked **[constraint]** exist because of an OS behaviour, not a preference. They
  look arbitrary and are not. Each one names the behaviour that forces it.

## For AI coding agents

Start with [../AGENTS.md](../AGENTS.md), then read `01-platform-constraints.md` before
writing any code. The single most expensive mistake available in this project is to assume
that a window can be raised above another application's windows with a public API. It
cannot, and an implementation built on that assumption will appear to work in code review
and fail on screen.
