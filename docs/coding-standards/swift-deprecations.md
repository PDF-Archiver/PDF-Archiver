
# Availability Workarounds — Make the Compiler Remind You

A workaround that exists **only** because the minimum deployment target is too low is debt with no due date. `if #available` branches, shim types and hand-rolled back-ports all keep compiling silently long after the floor has moved past them — nobody greps for them, and a `TODO` comment is not enforced by anything.

**Rule: every such workaround carries `@available(<platform>, deprecated: <version>, message: …)`.** Raising the floor then turns each call site into a compiler warning that says what to do instead.

## The pattern

Annotate the smallest symbol that would be **deleted** once the floor moves — usually the shim type or function, never the `if #available` statement itself (statements cannot be annotated).

```swift
/// Filled toolbar action. Mirrors `NewChatButton`'s availability split for a text button. That split
/// is the only reason the type exists, so raising the package to `.iOS(.v26)` turns every call site
/// into a warning to delete it — the floor is `.iOS(.v18)` today, where the deprecation stays silent.
@available(iOS, deprecated: 26.0, message: "Inline .buttonStyle(.glassProminent) and delete this type")
struct ProminentToolbarButton: View {
    var body: some View {
        if #available(iOS 26.0, *) {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.borderedProminent)
        }
    }
}
```

Three things make it work:

- **Platform-scoped, versioned** — `@available(iOS, deprecated: 26.0)`, not `@available(*, deprecated)`. The version is what keeps it quiet until the floor reaches it.
- **The version is where the workaround dies** — the OS version whose API you would inline, not the next release you happen to know about.
- **The message names the replacement**, so whoever hits the warning does not have to re-derive the fix. Keep the whole attribute inside the line-length limit.

## Getting a Fix button in Xcode — `renamed:`

`message:` only prints text. `renamed:` additionally attaches a **fix-it**, which Xcode renders as a **Fix** button that rewrites the call site. Both fit in one attribute: the `message:` wins the warning text and the fix-it survives as a `note: use 'X' instead`.

```swift
/// Pre-26 card. `GlassCard` replaces it one-for-one once the floor allows it, so the removal is a
/// plain rename — that earns a `renamed:` on top of the message.
@available(iOS, deprecated: 26.0, message: "Use GlassCard, which needs iOS 26", renamed: "GlassCard")
struct FlatCard: View { … }
```

The fix-it does more than swap an identifier, and it survives the module boundary (shim in a package, call site in the app):

| `renamed:` value | Call site before → after pressing Fix |
| --- | --- |
| `"GlassCard"` (on a type) | `FlatCard()` → `GlassCard()` |
| `"modernHelper()"` | `legacyHelper()` → `modernHelper()` |
| `"modernFoo(first:second:)"` | `legacyFoo(1, 2)` → `modernFoo(first: 1, second: 2)` |
| `"Int.doubled(self:_:)"` | `legacyDouble(3, 4)` → `3.doubled(4)`; `self:` marks the new receiver |

`@available(*, unavailable, renamed:)` carries the same fix-it on an error instead of a warning — for a cutover that must stop compiling.

Verify the fix-it rather than assuming it: `-diagnostic-style llvm` prints the replacement text under the note's caret, and that text is exactly what the Fix button inserts. Type-check the shim on its own with a target at or above the deprecation version, so the warning fires at all (see the traps below):

```bash
xcrun swiftc -typecheck -diagnostic-style llvm \
    -target arm64-apple-ios26.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" Shim.swift
```

### Shape the shim so its removal is a rename

Whether a Fix button is possible at all is decided by the **form** of the shim, not by the attribute. A shim that is a *value* in a position the new API also occupies — a `ButtonStyle`, `ShapeStyle`, `Transition`, a formatter — differs from its replacement by one identifier, so `renamed:` carries the whole fix. A shim that is a *structure* which disappears — a wrapper view, a duplicated modifier chain — has no name to rename to. Where both forms are open, pick the first:

```swift
struct CompatProminentButtonStyle: PrimitiveButtonStyle { … }

extension PrimitiveButtonStyle where Self == CompatProminentButtonStyle {
    /// Exists only for the pre-26 floor, and `.glassProminent` sits in exactly this position — so the
    /// removal is a one-identifier rename that the Fix button can perform.
    @available(iOS, deprecated: 26.0, renamed: "glassProminent")
    static var compatProminent: CompatProminentButtonStyle { .init() }
}
```

`.buttonStyle(.compatProminent)` → Fix → `.buttonStyle(.glassProminent)`, which compiles. The bare identifier is enough; a type prefix works too — the fix-it's `.Type.member` result is a valid implicit member chain (SE-0287) — but buys nothing.

### When to leave `renamed:` off

- **The value must be a declaration name** — "an operator, identifier, or full function name, optionally prefixed by a type name". `renamed: "buttonStyle(.glassProminent)"` is a **compile error**, not a silent no-op. So `ProminentToolbarButton` above, whose fix is *inline the modifier and delete the type*, cannot have a Fix button; there `message:` is the whole answer.
- **The fix-it rewrites the name and the argument labels, never the arity.** A no-argument shim pointed at `renamed: "modernWithArg(_:)"` produces `modernWithArg()` — the Fix button leaves code that does not compile. Add `renamed:` only when the replacement's call shape matches, or when labels and `self:` express the whole difference.

## Stopping the build at a later floor — `obsoleted:`

`deprecated:` never does more than warn, and a warning can sit in the build log for as long as nobody reads it. `obsoleted: <version>` in the same attribute adds a second floor: once the deployment target reaches it, every call site is a compile error.

```swift
@available(iOS, deprecated: 26.0, obsoleted: 27.0, renamed: "GlassCard")
struct FlatCard: View { … }
```

| Deployment target | A `FlatCard()` call site |
| --- | --- |
| below 26.0 | compiles silently |
| from 26.0, below 27.0 | `warning: 'FlatCard' was deprecated in iOS 26.0: renamed to 'GlassCard'` |
| 27.0 and later | `error: 'FlatCard' has been renamed to 'GlassCard'`, plus `note: 'FlatCard' was obsoleted in iOS 27.0` |

`renamed:` keeps its fix-it on the error, and a `message:` is appended to it (`error: 'X' is unavailable in iOS: <message>`). The declaration itself still compiles; only its uses fail.

The price: raising the floor to the obsoleted version breaks the build until every such shim is gone, in that same change. Add `obsoleted:` when a shim has to be gone by a known floor, and leave it off where a leftover shim is merely untidy.

To verify it, raise the floor to the obsoleted version as in the traps below and grep for `was obsoleted in iOS`.

## What not to use instead

| Instead of | Why it fails |
| --- | --- |
| `@available(*, deprecated, message:)` | Unconditional — warns immediately, on every platform, today. |
| `#warning("remove when iOS 26")` | Fires on every build from now on; becomes noise and gets ignored. |
| A `TODO:` comment | Nothing enforces it. This is exactly the case the compiler can enforce for you. |

## Verifying it — two traps

The annotation is worthless if it never fires, so verify it once instead of assuming.

**Trap 1: `swift build` compiles for the host, i.e. macOS.** An `@available(iOS, …)` never fires there. Verify with a real iOS build:

```bash
xcodebuild -scheme <Target> -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
```

**Trap 2: it is supposed to be silent right now.** A deprecation warns only once the deployment target the file is compiled with reaches the version — for a SwiftPM package that is its own `platforms:` floor. So "no warning" on the current floor is the correct result, not a failed setup.

Prove both halves by temporarily raising the floor:

```bash
cp Package.swift /tmp/Package.swift.bak
sed -i '' 's/\.iOS(\.v18),/.iOS(.v26),/' Package.swift
xcodebuild -scheme <Target> -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 \
    | grep "was deprecated in iOS"
cp /tmp/Package.swift.bak Package.swift && rm /tmp/Package.swift.bak
```

Expected: the grep prints the warning with your message, and the floor is back where it was.

## Where else this applies

The same annotation fits any deliberate, version-bound workaround — a back-ported formatter, a `UIViewRepresentable` wrapping a control SwiftUI gained later, a duplicated modifier chain behind `if #available`. If you can name the OS version that makes the code unnecessary, annotate it.

It does **not** fit code that is merely old or unloved: deprecation is a promise that a specific version removes the need. Without that version, write the fix or a tracked `TODO:` instead.
