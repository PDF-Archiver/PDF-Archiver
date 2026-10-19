
# Swift and SwiftUI

**Clarity > Brevity > Consistency.** Code compiles without warnings. Comment rules live in `general.md`; doc comments belong to the `jk:swift-docc` skill.

## Swift / SwiftUI

- Doc comments: use the `jk:swift-docc` skill (it ships the rules plus a lint script). What earns a `///` is **architectural relevance, not the access level** — domain models and the protocols that serve as the contract between components get one; a declaration does not earn one by being `public`, and an `internal` cross-component seam still deserves one.
- Concurrency and SwiftUI specifics: `jk:swift-concurrency` and the SwiftUI skills; tests: `swift-testing.md`.
- **macOS UI: `macos-design.md`** — layout metrics, window chrome, and Mac interaction. Mac layout is **not** an 8-point grid (`20` margins, `6` between controls, `12` between groups), and iOS reflexes — hamburger menu, bottom tab bar, touch-sized controls, sheet-per-action — are the visible tell of a port.
- **An element that appears and disappears keeps its space — `.opacity(…)`, not a conditional `if` that removes it from the hierarchy.** An unread indicator in a list row, a `ProgressView` during a load, a validation hint: removing the view makes the surrounding layout jump the moment it comes back. Reserve the space by default; reflow it only when the developer asked for the jump explicitly.
- Always add `#Preview` macros for views. Prefer type inference for simple properties. Never write `internal` explicitly. TCA: keep Feature and View in the same file.
- **A workaround that only exists because the deployment target is too low gets `@available(<platform>, deprecated: <version>, message: …)`**, so raising the floor turns it into a compiler warning instead of silent debt — plus `renamed:` where the fix is a plain rename, which gives Xcode a **Fix** button, and `obsoleted: <version>` where a later floor has to turn the warning into an error: `swift-deprecations.md`.
- Never use `if`/`switch` expressions (SE-0380) — `let x = if p { … } else { … }` and `let y: Float = switch value { … }` are forbidden; use the statement form (examples under *No `if`/`switch` expressions* below).

## Naming

- `UpperCamelCase` for types and protocols, `lowerCamelCase` for everything else.
- Clear at the call site — read the declaration as it will be *used*.
- No abbreviations except the universal ones (URL, ID, UUID). Spell out `cfg`, `mgr`, `ctx`, `desc` as `configuration`, `manager`, `context`, `description`.
- Avoid `Manager`, `Handler`, `Helper`, `Coordinator` — they hide the responsibility. Prefer `PaymentProcessor`, `EventDispatcher`, `ImageCache`.

```swift
let maximumWidgetCount = 100
func fetchUser(byID id: String) -> User
```

## Golden path

The left-hand margin is the happy path. Guard and return early instead of nesting `if`s — deep nesting is what makes a function hard to follow.

```swift
func process(value: Int?) throws -> Result {
    guard let value else { throw ProcessError.nilValue }
    guard value > 0 else { throw ProcessError.invalidValue }
    return compute(value)
}
```

## No `if`/`switch` expressions (SE-0380)

Never use `if` or `switch` as an expression ([SE-0380](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0380-if-switch-expressions.md)) — not to initialize a `let`/`var`, not as a single-expression function or closure body. Use the statement form that assigns in each branch, or extract a function.

```swift
// FORBIDDEN — if/switch expressions
let x = if p {
    [1]
} else {
    [1].map(expensiveOperation)
}

let y: Float = switch value {
case 0..<0x80: 1
case 0x80..<0x0800: 2.0
default: 4.5
}

// Correct — statement form, each branch assigns
let x: [Int]
if p {
    x = [1]
} else {
    x = [1].map(expensiveOperation)
}

let y: Float
switch value {
case 0..<0x80: y = 1
case 0x80..<0x0800: y = 2.0
default: y = 4.5
}
```

## Access control

- `private` over `fileprivate`.
- Never write `internal` — it is the default, and stating it adds noise.
- Access control is the leading specifier on a declaration.

## `self`

Omit `self` unless the compiler requires it, and be consistent — mixing the two styles obscures capture semantics at a glance.

```swift
func configure() {
    backgroundColor = .systemBackground
}
```

## Type inference & sugar

Let the compiler infer when the type is obvious. Empty collections need the annotation.

```swift
var names: [String] = []
var cache: [String: Int]
var name: String?
```

## Computed properties

Omit `get` for read-only:

```swift
var diameter: Double {
    radius * 2
}
```

## Closures

Trailing-closure syntax only when there is a single closure parameter. In escaping closures:

```swift
resource.request().onComplete { [weak self] response in
    guard let self else { return }
    self.updateModel(response)
}
```

## Constants

Once a value has earned a name (see *Simplicity* in `general.md` — one call site means no constant), namespace it with a case-less enum, which cannot be instantiated by accident:

```swift
enum Math {
    static let pi = 3.14159
}
```

## Organization

Group conformances into extensions with `MARK:` headers:

```swift
// MARK: - UITableViewDataSource
extension MyViewController: UITableViewDataSource { }
```

Sparingly — see *Comments* in `general.md`: a file needing many MARKs to stay navigable is too large.

Braces open on the same line, one blank line between methods, no space before a colon and one after.

## Typography (SwiftUI)

Prefer semantic text styles so type scales with Dynamic Type: `.font(.footnote.weight(.medium))` instead of `.font(.system(size: 12, weight: .medium))`. Fall back to `.system(size:)` only when a design genuinely cannot be expressed semantically. See [Apple HIG — Typography](https://developer.apple.com/design/human-interface-guidelines/typography).

## Layout (SwiftUI)

A view is sized **from the inside out**: the parent proposes a size, the child determines its own, and the child's answer is final — *"the parent cannot alter this size unilaterally"* (*Thinking in SwiftUI*, ch. Layout). Grow a view with `.padding`, which adds its insets to whatever the content reported. Avoid `.frame(width:height:)`: it proposes a fixed size and reports it *independent of the subview*, which hard-codes a magic number Dynamic Type cannot move — the same book calls fixed frames in production code "actually quite rare".

Watch for `.resizable()`. It strips an `Image` of its reported size so the view accepts any proposal, and from then on a fixed frame is the only thing that *can* size it. That is a self-inflicted problem, not a justification for the frame.

```swift
// FORBIDDEN — the glyph has no size of its own, so a magic number has to supply it
Image(systemName: "paperplane.fill")
    .resizable()
    .scaledToFit()
    .frame(width: 32, height: 32)

// Correct — the font reports the size, the padding grows it, both follow Dynamic Type
Image(systemName: "paperplane.fill")
    .font(.title3)
    .padding(6)
```

Two sizes that must match are expressed structurally rather than computed: give both the same content treatment and add the difference as padding, so the equality survives every text size. Fixed frames stay legitimate for design elements that genuinely cannot or should not scale.

## API availability & deprecation

When a newer OS version offers an API that replaces a legacy fallback, isolate the fallback behind its own helper so the **compiler** tells you when it is safe to delete ([Swift with Majid](https://swiftwithmajid.com/2023/05/17/api-availability-in-swift/)):

```swift
extension View {
    @ViewBuilder
    func scrollBounceDisabled() -> some View {
        if #available(iOS 16.4, *) {
            self.scrollBounceBehavior(.basedOnSize)
        } else {
            legacyScrollBounceDisabled()
        }
    }

    @available(iOS, deprecated: 16.4, message: "Use scrollBounceBehavior(.basedOnSize) directly.")
    private func legacyScrollBounceDisabled() -> some View {
        // legacy implementation
    }
}
```

The deprecation version is the one that introduced the replacement: once the deployment target reaches it, every call site warns and the helper is provably dead code. The `message:` names the replacement so removal is mechanical. A `renamed:` would additionally give Xcode a **Fix** button, but only where the replacement's call shape matches — `scrollBounceBehavior(_:)` takes an argument the shim does not, so the button would insert non-compiling code (`swift-deprecations.md`). Never inline an indefinite legacy branch — cleanup should be compiler-driven, not memory-driven.
