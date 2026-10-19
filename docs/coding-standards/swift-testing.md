
# Swift Testing

Rules for any work with `import Testing` — writing, reviewing, or migrating from XCTest. Test rules for every language (behavior through the public API, determinism, isolation of window-opening suites) are in `general.md`.

## Swift Testing

1. **Invoke `ext:swift-testing-pro` first.** It carries the full, up-to-date Swift Testing ruleset (structs over classes, `#expect`/`#require`, async tests, traits, migration); load whichever of its reference files fit the request. Its review process and output format are the default here.
2. **Layer custom-assertion judgment** — whenever the work involves a shared, reusable, or multi-part assertion / verification helper (or the user asks about one), apply *Custom assertions* below: decide whether a helper is even warranted, pick `#expect` vs `#require` vs `Issue.record`, and thread `sourceLocation` so failures report at the call site.
3. **Run the detector when reviewing existing tests** — `scripts/find-assertion-helpers.sh` in the `jk:builder` skill, over the test sources, flags helpers missing a `sourceLocation:` parameter. Treat hits as leads to confirm, then fix per Pattern 1/2 below.
4. **Report** in the base skill's output format (findings by file, rule named, brief before/after), folding the custom-assertion findings in alongside.

Nothing here contradicts `ext:swift-testing-pro`. Where it already covers a point (e.g. the `sourceLocation` passthrough for verification methods), defer to it rather than restating it.

## Custom assertions

Reusable assertion helpers — `expectValidEmail(_:)`, `requireUser(from:)`, `verifyDivision(_:…)` — that wrap one or more `#expect` / `#require` / `Issue.record` calls so a multi-part or complex check reads as a single line at the call site.

Source: Jon Reid, *"Custom Test Assertions in Swift Testing"* (qualitycoding.org). All snippets below were compile- and behaviour-verified on Swift 6.3.3 (macOS 26 target) against the `Testing` module.

### 1. Extract sparingly — the bar is higher than in XCTest

Custom assertions matter **less** in Swift Testing than they did in XCTest, because `#expect` already prints the operands of a failed comparison (`(user.name → "Bob") == "Taylor"`). You rarely need a helper just to get a readable message. Extract one only when it buys something `#expect` can't:

- **Multi-part validation** — several checks that always travel together (a valid email needs an `@` *and* no spaces *and* a domain).
- **Navigating complex objects** — digging into JSON / nested models where `==` on the whole value isn't meaningful and you assert on extracted fields.

If a single `#expect(a == b)` says it clearly, don't wrap it. A helper that hides one comparison adds a stack frame and a name to learn for no diagnostic gain.

### 2. The call-site rule (and how it relates to `ext:swift-testing-pro`)

Any helper that contains `#expect` / `#require` / `Issue.record` **must** take a `sourceLocation` parameter defaulting to `#_sourceLocation` and pass it to every assertion inside — otherwise a failure is reported at the line *inside the helper*, and you fire up the debugger to find which test actually failed.

`ext:swift-testing-pro` (`references/writing-better-tests.md` → *verification methods*) already teaches this passthrough mechanic. Don't re-derive it; this section adds the *decision* layer (§1), the `Issue.record`-in-`if` diagnostic pattern (§3 Pattern 2), the value-returning and async variants (Patterns 3–4), and the detector script (§4).

> `#_sourceLocation` keeps the leading underscore — that is the current spelling, not a typo.

### 3. The patterns

#### ❌ Anti-pattern — no `sourceLocation`

Failures land inside the helper, not at the test that called it:

```swift
func expectValidEmail(_ email: String) {
    #expect(email.contains("@"), "Missing @ in \"\(email)\"")
    #expect(!email.contains(" "), "Should not contain spaces: \"\(email)\"")
}
```

#### ✅ Pattern 1 — thread `#_sourceLocation` through every assertion

```swift
func expectValidEmail(
    _ email: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(
        email.contains("@"),
        "Missing @ in \"\(email)\"",
        sourceLocation: sourceLocation
    )
    #expect(
        !email.contains(" "),
        "Should not contain spaces: \"\(email)\"",
        sourceLocation: sourceLocation
    )
}
```

`Testing.SourceLocation` is the same type, fully qualified — useful when `SourceLocation` is ambiguous in scope. The message is the optional `Comment` (second positional arg); a string literal is enough.

#### ✅ Pattern 2 — `Issue.record()` inside an `if`, for clean conditional checks

When the check is conditional or multi-step, an expanded `#expect(complexBool)` produces noisy diagnostics. Decide in plain Swift and record a tidy message:

```swift
func expectValidEmail(
    _ email: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    if !email.contains("@") {
        Issue.record(
            "Missing @ in \"\(email)\"",
            sourceLocation: sourceLocation
        )
    }
}
```

`Issue.record(_:sourceLocation:)` is also the primitive for failures that aren't a single boolean — it's the Swift Testing replacement for `XCTFail`.

#### ✅ Pattern 3 — `#require`-style helper that unwraps and returns

Use `#require` (not `#expect`) when later lines depend on the value: it throws and stops the test on failure. Make the helper `throws` and return the unwrapped value:

```swift
func requireUser(
    fromJSON json: [String: Any],
    sourceLocation: SourceLocation = #_sourceLocation
) throws -> User {
    let name = try #require(
        json["name"] as? String,
        "Expected String 'name' in \(json)",
        sourceLocation: sourceLocation
    )
    let email = try #require(
        json["email"] as? String,
        "Expected String 'email' in \(json)",
        sourceLocation: sourceLocation
    )
    return User(name: name, email: email)
}
```

Call it with `let user = try requireUser(fromJSON: payload)`.

#### ✅ Pattern 4 — async helper

Mark the helper `async`, `await` inside, still thread `sourceLocation`:

```swift
func expectUserCount(
    _ expected: Int,
    in store: UserStore,
    sourceLocation: SourceLocation = #_sourceLocation
) async {
    let actual = await store.count
    #expect(actual == expected, sourceLocation: sourceLocation)
}
```

### 4. Detecting helpers that forgot `sourceLocation`

`scripts/find-assertion-helpers.sh [path …]`, which ships with the `jk:builder` skill (`~/.claude/skills/jk/skills/builder/scripts/`), flags every non-`@Test` function that calls `#expect` / `#require` / `Issue.record` without a `sourceLocation` parameter. It's a heuristic lead-finder (naive about braces inside string literals), so confirm each hit — but it's the fast first pass on a review:

```
$ scripts/find-assertion-helpers.sh Tests/
Tests/EmailTests.swift:42: helper 'expectValidEmail' uses #expect/#require/Issue.record but has no `sourceLocation:` parameter — failures will point inside the helper, not the call site
```

Exit code is 1 when any lead is found, 0 when clean — usable as a CI gate.

### 5. Naming

The article uses `assert…`; `ext:swift-testing-pro` uses `verify…`; the Swift Testing idiom is to mirror the underlying macro — `expect…` for non-throwing checks, `require…` for throwing helpers that unwrap/return. Lead with `expect…` / `require…` because the prefix tells the reader at the call site whether the helper can throw and stop the test. Whichever you pick, match the surrounding test target rather than mixing conventions.
