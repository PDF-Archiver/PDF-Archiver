
# Logging

How to log so the output stays aggregatable, filterable, and free of secrets. For *temporary* instrumentation during a bug hunt, use `jk:builder`'s `references/debug-logging.md` instead — different rules apply there.

## The rule in short

Use the project's logger — `swift-log` (`OSLog` if `swift-log` is unavailable). **Never** `print`, `Swift.print`, `dump`, `debugPrint`, or `os_log`. **Never interpolate dynamic values into the message**: keep the message static and pass values via `metadata:`, otherwise every call site produces a unique string and log aggregation breaks. Levels, `error:` handling, and full examples follow below.

## Setup — one logger per file

```swift
private let logger = Logger(label: "com.example.ChannelRepository")
```

If the project ships its own logging package with a convenience factory (e.g. a label derived from the file), prefer that over hand-written labels.

A file-scoped `private let` is enough: no logger passed through initializers, no logger stored on types. The label identifies the source, so it never has to be repeated in the message.

**Never** use `print`, `Swift.print`, `dump`, `debugPrint`, or `os_log` — SwiftLint enforces this. They bypass levels, labels, and metadata, and they ship to production silently.

## The one rule: static message, dynamic values in `metadata:`

Interpolating a value into the message makes every call site produce a unique string, so the log backend can no longer group occurrences of the same event — the message is the aggregation key.

```swift
// FORBIDDEN — message varies per call, defeats aggregation
logger.debug("Initialized ChannelCollectionView.ViewModel for \(dutyIDs.count) duty ids")

// Correct — static message, dynamic values in metadata
logger.debug("Initialized ChannelCollectionView.ViewModel", metadata: ["dutyIdCount": "\(dutyIDs.count)"])
```

Metadata keys are `lowerCamelCase` and stable across call sites (`dutyId`, not `duty_id` here and `dutyID` there) — a query filtering on a key only works if the key is spelled the same everywhere. Put every value you might later want to *correlate on* into metadata: entity IDs, counts, states.

## Levels

| Level | Use for |
| --- | --- |
| `logger.debug(...)` | Init, internal state transitions, fine-grained flow ("Fetching channels for duty ids …"). |
| `logger.info(...)` | User-visible or cross-layer events ("Button tapped", "Resolved channels"). |
| `logger.warning(...)` | Recoverable problems, missing optional data — the flow continues. |
| `logger.error(...)` | Failures the user or an operator needs to know about. |

`trace` and `critical` exist but are rarely the right answer: `trace` belongs to a temporary probe, and a `critical` that does not page someone is just an `error`.

## Errors

Always attach the error itself — the message says what failed, the error says why.

```swift
// swift-log has no `error:` parameter — put the error in metadata
logger.error("Failed to load channels", metadata: ["error": "\(error)", "dutyId": "\(dutyID)"])
```

If the project's logging wrapper has a dedicated `error:` parameter, use it instead of metadata.

Add a correlation ID whenever one exists, so the failure can be tied back to the request or entity that caused it. Log an error **once**, at the layer that decides how to handle it — an error logged at every level on the way up looks like several failures.

## `OSLog` variant

When `swift-log` is not available:

```swift
import OSLog

private let logger = Logger(subsystem: "com.example.app", category: "ChannelRepository")

logger.error("Failed to load channels: \(error.localizedDescription, privacy: .public)")
```

`OSLog` has no `metadata:`, so values go into the message — that is fine here, because `OSLog` keeps the format string and the arguments separate internally, so aggregation survives. Dynamic values are redacted to `<private>` unless annotated, so add `privacy: .public` to anything that must appear in a captured log — and deliberately *omit* it for anything sensitive.

## What not to log

- No secrets, tokens, passwords, or auth headers — not even at `debug`.
- No personal data beyond an opaque identifier; log the user ID, not the email or name.
- Nothing inside a hot loop or a SwiftUI `body` — that is a probe (`jk:builder`'s `references/debug-logging.md`), not a log.
- No log line that only restates the previous one. One line per meaningful decision or boundary crossing, not one per statement.
