
# Coding standards

The shared coding standards for Julian's private repos: what the code looks like, the rules a reviewer can check in a diff. Each repo carries a copy of these files in `docs/coding-standards/` and links them from its `CODING_STANDARDS.md`, followed by the repo's own rules. This folder is the only place they are edited; the copies are regenerated from it.

How to work on a change (diagnose first, the TDD loop, verification, commits, PRs) is not here: that is the `jk:builder` skill.

| File | Covers | Read when |
|---|---|---|
| `general.md` | Simplicity, SDK first, comments (incl. Xcode `MARK:`), naming, errors and absent values, security, the concurrency rule, architecture, performance, tests (isolation, edge cases, fakes at the seams) | Every change, any language |
| `swift.md` | Swift and SwiftUI style: naming, golden path, no `if`/`switch` expressions, access control, doc comments, typography, layout, availability | Writing or reviewing Swift |
| `swift-testing.md` | Swift Testing: `ext:swift-testing-pro` first, custom assertions with `sourceLocation`, helper naming | Any work with `import Testing` |
| `logging.md` | Static message with values in `metadata:`, levels, errors, the `OSLog` variant, what not to log | Adding, reviewing, or fixing a log call |
| `swift-deprecations.md` | `@available(…, deprecated:)` on availability workarounds, `renamed:` for an Xcode Fix button, `obsoleted:` for an error at a later floor, and how to verify they fire | Writing or reviewing an `if #available` branch or a shim a higher floor would delete |
| `macos-design.md` | Mac layout metrics, center equalization, window chrome, menu bar and keyboard parity, toolbar, sidebar and inspector | Writing or reviewing macOS UI, or porting an iOS layout |
