
# General coding standards

Rules for any change to source code, in any language. Language-specific rules live next to this file: Swift in `swift.md`, Swift Testing in `swift-testing.md`, logging in `logging.md`. The process around a change (diagnose first, TDD loop, verification, commits, PRs) is `jk:builder`'s.

Four rules outrank everything further down whenever they collide:

1. **The simplest thing that works wins.** Little code is the optimum, not a compromise.
2. **SDK before hand-rolled.** Check the platform first; every line not written needs no tests.
3. **A bug gets a failing test first.** Red proves you understood it; green proves you fixed it.
4. **Comments are for humans: the WHY, in at most 2 lines.**

## Simplicity — little code is the optimum

- Solve the problem in front of you, at the size it actually has. No speculative generality: no extra parameter, protocol, generic, config flag, or indirection for a caller that does not exist.
- **Pass the narrowest input the logic reads** — the field, not the object holding it. Handing over a whole struct to read one field is **stamp coupling**: the signature claims a dependency on every field, callers and tests have to build the full value, and the next change quietly reaches for a second field instead of announcing it in the signature. Take the whole object once three or more of its fields are read (Fowler's *Preserve Whole Object*).

  ```swift
  // FORBIDDEN — stamp coupling: the signature claims 13 fields, the body reads one
  func bubbleColor(for content: MessageRowContent) -> Color {
      content.isOwnMessage ? .brandTinted : .neutral
  }

  // Correct — the call site passes what the decision needs: `bubbleColor(for: content.isOwnMessage)`
  func bubbleColor(for isOwnMessage: Bool) -> Color {
      isOwnMessage ? .brandTinted : .neutral
  }
  ```

- **Duplication beats premature abstraction** when it reads better. Two clear call sites can be better than one abstract one; abstract on the third occurrence, once the shared shape is known.
- **A value used once is written where it is used.** A named or `static` constant earns its name only when a second call site has to stay in sync with it — before that it is indirection plus a name to maintain, and the reader has to jump to find a literal. Count the call sites before extracting; the rationale that would have gone into the constant's doc comment goes into the comment next to the literal.
- **Smallest diff that solves it.** Unrelated cleanups and refactors are a separate change — mention them instead of smuggling them in.
- Delete dead code rather than commenting it out; version control remembers it.
- Do not add a dependency, layer, file, or type when something already in the project fits.
- If the solution turned out large, say so and offer the smaller version — a big diff for a small problem is a design signal, not an achievement.

## SDK first — check, don't recall

- Before writing any helper, look for the platform, framework, or standard-library API that already does it. **Look it up** (`jk:sdk-documentation` for a symbol dump, the framework reference, the LSP) — "I don't remember one" is not evidence that none exists.
- A marginal difference is not a licence to reimplement. One missing option, slightly different wording, a test that wants a fixed instant → adapt the **call site or the test**, not the API. Hand-writing a relative-date formatter when `Date.RelativeFormatStyle` exists costs tests, maintenance, and localisation for free features.
- If the SDK genuinely cannot do it, name the API you checked and what it lacks before writing the substitute.

## Comments

- **Comments are written for humans**, not for the compiler and not to narrate the diff.
- **Keep them to 2 lines, ideally 1.** Go longer only when the reason genuinely cannot be said shorter (a subtle invariant, a linked workaround) or the user asked for more detail.
- **A comment that does earn more than one line is shaped for scanning**, because it is text for a human and structure carries as much of the meaning as the wording:
  - **A list beats prose** as soon as three or more things are enumerated. One item per line, the distinguishing word first, so the reader finds their case down the left edge instead of parsing a sentence to the end.
  - **The point goes in the first line.** A reader who stops there still has it; the rest is detail.
  - **One idea per comment, at the line it explains.** Two unrelated reasons are two comments in two places, never one paragraph stacked on top of the block.
  - **Name the thing** — the symbol in backticks, the real value, the issue URL. "This", "it" and "the object" make the reader reconstruct the referent from context.
  - **No banner lines or ASCII-art boxes.** Wrap at the file's column limit and break at clause boundaries, not mid-phrase.

  ```swift
  // FORBIDDEN — three cases welded into one sentence, each read past to reach the next
  // Retry on 429 and 503 but never on the other 4xx codes because the request itself is wrong,
  // and never once the deadline has passed since the caller has stopped waiting by then.

  // Correct — the cases are the left edge
  // Retry only while the failure is transient:
  // - 429, 503: the server asked us to back off
  // - other 4xx: the request is wrong, a retry cannot fix it
  // - deadline passed: the caller has stopped waiting
  ```

- **The WHY, never the WHAT.** Good names already say what the code does. Comments carry hidden constraints, invariants, workarounds, business rules, and behavior that would surprise a reader. A comment that restates well-named code gets deleted.
- **Skip them entirely for** simple getters, obvious one-liners, and private helpers with descriptive names — the signature already says it. Separate from the `///` DocC rule, which follows architectural relevance rather than access level (see `swift.md`).
- **Do not match surrounding comment density.** Heavily commented neighbours are not a target; judge every comment on its own merit.
- **Never comment at every spot where *you* made a decision.** Having just weighed an option makes it feel noteworthy, but that is a log of the author's reasoning, not something the reader needs — they never had the discussion and see only code that explains itself. The test before writing one: **would a plausible refactor break this without the compiler or the UI showing it?** If not, the code already says it.

  ```swift
  // FORBIDDEN — narrates the three lines below; interesting to decide, not to read
  /// The font reports its size, the padding grows it — no fixed frame.
  private func controlGlyph(_ systemName: String) -> some View {
      Image(systemName: systemName)
          .font(.body)
          .padding(6)
  }

  // FORBIDDEN — reads like an invariant, but a shared function already says that both
  // callers share it, and breaking the equality changes the layout visibly
  /// Both round controls share this treatment — equal glyph heights are what keep the
  /// attachment button as tall as the collapsed composer.
  private func controlGlyph(_ systemName: String) -> some View { … }

  // Correct — moving the line compiles, looks identical, and only shrinks the tap target
  // Inside the label: moved outside the Button, the hit area silently shrinks to the glyph.
  .contentShape(.rect)
  ```

- **Never comment on access levels** — not why something is not `private`, not which file reads it. The access level is the statement; such notes go stale the moment code moves.

  ```swift
  // FORBIDDEN — access-level narration, and it is a WHAT
  // Not `private`: read by the formatting extension in the sibling file.
  let dateFormatter: DateFormatter

  // Correct
  let dateFormatter: DateFormatter
  ```

- Declarations get `///` (DocC); notes inside a function body get `//`. Avoid `/* */`.
- All comments in English. `TODO:` prefix for known-incomplete work.
- Update or delete comments with the code they describe — an outdated comment is worse than none.
- **Swift only — Xcode marker comments** ([SwiftLee](https://www.avanderlee.com/xcode/xcode-mark-line-comment/)): `// MARK: - Title` (titled section + separator), `// MARK: -` (separator only), `// MARK: Title`, plus `// FIXME:` and `// TODO:`, which Xcode shows with an icon in the jump bar. Uppercase, two slashes, colon — otherwise Xcode ignores them. Use them **only where a file really has sections a reader jumps between** (typically one per conformance extension), never as decoration above every second function. Needing many MARKs to make a type navigable means the type is too large — split it instead. Pair a `FIXME:` with `#warning("…")` when the placeholder must not ship.
- No AI attribution, no "generated by" headers, in code, commits, or PRs.

## Naming

Names reveal responsibility and read clearly at the call site. No abbreviations beyond universal ones (URL, ID, UUID). Avoid `Manager`, `Helper`, `Handler`, `Coordinator` — prefer `PaymentProcessor`, `ImageCache`, `EventDispatcher`. For **user-facing** names (features, buttons, labels, settings), use `jk:naming`.

## Errors — surface them, don't swallow them

- No empty `catch`, no `try?` used to make a path compile, no error discarded to keep a signature clean. If a layer cannot handle a failure, propagate it with enough context to diagnose.
- Fail fast on programmer errors (precondition violations); degrade gracefully on expected ones and give the user an actionable message.
- Never silence a compiler warning or a lint rule instead of fixing the cause. If a suppression is genuinely correct, the comment next to it says why.
- Validate data crossing a boundary (network, file, user input) — it is untrusted. No secrets or personal data in source or logs.

## Concurrency — nothing you read before an `await` is still true after it

Language-agnostic rule, because every cooperative-concurrency runtime has it: a suspension point hands control away. State you read before it may have been changed by someone else by the time you resume, so **never write shared state based on a value you read before suspending** — re-read it, or prove you still own what you are about to overwrite. Swift specifics, including the actor-reentrancy catalogue: `jk:swift-concurrency` (`references/bug-patterns.md`).

**Before adding a new `Mutex`, `NSLock`, `os_unfair_lock`, `DispatchSemaphore`, or any other lock**, load `jk:swift-concurrency` and run the choice past it rather than reaching for one from habit — that skill's default is async/await and actors; a lock is the documented exception (a synchronous API you cannot change, a C/ObjC callback, a single scalar), never a reflex. State the reason a suspension-based primitive does not fit before writing the lock, the same way an escape hatch like `@unchecked Sendable` needs a receipt.

The frequent instance: a shared in-flight task is cached to deduplicate callers, and every caller clears it on failure. Each `catch` runs *after* a suspension, so a late one evicts a **newer** task that a different caller has since installed — the dedupe silently stops working.

```swift
// FORBIDDEN — every caller clears; this one may no longer own what it nils out
} catch {
    cachedTask = nil
    return .fallback
}

// Correct — only the creator evicts, and only while it still owns the entry
} catch {
    if existing == nil, cachedTask == task { cachedTask = nil }
    return .fallback
}
```

It is a race condition, not a data race, so neither the compiler nor strict concurrency checking will find it — only reasoning about the suspension will. A test that fails the shared task and then asserts a *single* underlying read is what pins it down.

## Architecture

Follow the architecture the project already uses, and keep domain logic free of infrastructure and UI concerns so it stays testable. Do not introduce layers, modules, or indirection a project does not have — that is the simplicity rule applied to structure. When a project documents its own conventions (the "This repo" part of its `CODING_STANDARDS.md`, its `CLAUDE.md`), those win over these shared files.

## Tests

- Assert observable behavior through the public API, not implementation details, so a refactor does not break the suite.
- Keep tests deterministic: inject clock, randomness, and network; no sleeps, no shared mutable fixture, no dependence on execution order.
- One reason to fail per test, and a name that says what breaks.
- **A test run must have no side effects on the machine running it.** A suite that opens a real window, plays sound, or reaches shared state is not safe inside an automated `test` command and must be isolated and excluded by default. Swift: any suite that constructs an `NSWindow`/`UIWindow` goes in a target suffixed `*UITests`, kept out of the default `swift test` run via `--skip <Target>UITests`. **Verify the exclusion by running it and confirming no window appears** — a `--skip` argument that doesn't match the actual target name silently runs the suite anyway, and reading the skip name back proves nothing.
