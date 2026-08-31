# Accessibility Nutrition Label declarations (issue #318)

Operational runbook for App Store Connect's accessibility declarations. This is not app
documentation — it is the set of `asc` commands a human runs to publish what issue #318
verified, plus the manual VoiceOver checklist that a code audit cannot complete.

No `asc` command in this file has been run except the read-only `list` below. Publishing
these declarations is an outward-facing action left for the user to run and review.

## State before this work (`asc accessibility list --app 1433801905`)

Recorded once, as the "before" this PR is measured against. Re-run the command for the
current state — this snapshot stops being true the moment step 1 runs.

```json
{"data":[],"links":{"self":"https://api.appstoreconnect.apple.com/v1/apps/1433801905/accessibilityDeclarations"},"meta":{"paging":{"total":0,"limit":50}}}
```

Zero declarations exist for any device family — this is the "developer has not yet
indicated" state the issue is fixing.

## Step 1 — declare the three safe attributes now

Run once per device family. `captions` and `audio-descriptions` are honestly `false` (the
app plays no video); `dark-interface` is already implemented (`colorScheme` is evaluated
throughout the app) and should be spot-checked once in dark appearance on iOS and macOS
before running these.

```bash
asc accessibility create --app 1433801905 --device-family IPHONE \
  --supports-captions false --supports-audio-descriptions false --supports-dark-interface true

asc accessibility create --app 1433801905 --device-family IPAD \
  --supports-captions false --supports-audio-descriptions false --supports-dark-interface true

asc accessibility create --app 1433801905 --device-family MAC \
  --supports-captions false --supports-audio-descriptions false --supports-dark-interface true

asc accessibility create --app 1433801905 --device-family VISION \
  --supports-captions false --supports-audio-descriptions false --supports-dark-interface true
```

Every other flag is left unset on purpose — an unset attribute stays undeclared, which is
the honest state for `voiceover`, `voice-control` and `larger-text` until step 7.

After creating, each `create` response includes an `id`. Record the four IDs (one per
family) — step 7 needs them for `asc accessibility update --id <id>`.

**A created declaration is a draft.** `--publish` exists only on `update`, not on `create`,
so nothing reaches the product page until the publish step at the end of this file is run.

## Step 7 — declare what the code changes in this PR make true

Run **after** the manual VoiceOver checklist below has been walked for a given family.
Replace `<id-iphone>` etc. with the IDs recorded in step 1.

```bash
# All four families: the Dynamic Type fixes in this PR (StatCard, TagView) apply everywhere.
asc accessibility update --id <id-iphone> --supports-larger-text true
asc accessibility update --id <id-ipad>   --supports-larger-text true
asc accessibility update --id <id-mac>    --supports-larger-text true
# VISION: only if the app has actually been exercised on visionOS. Leave unset otherwise —
# see "Left undeclared" below.
# asc accessibility update --id <id-vision> --supports-larger-text true

# IPHONE and IPAD: only once the manual VoiceOver checklist below comes back clean on iPhone.
asc accessibility update --id <id-iphone> --supports-voiceover true --supports-voice-control true
asc accessibility update --id <id-ipad>   --supports-voiceover true --supports-voice-control true

# MAC: only once the manual VoiceOver checklist below is repeated and comes back clean on macOS
# — the form shares code with iOS but not behaviour, so the iPhone pass does not cover it.
asc accessibility update --id <id-mac> --supports-voiceover true --supports-voice-control true

# All four families: colour is never the sole carrier of meaning (sweep below).
asc accessibility update --id <id-iphone> --supports-differentiate-without-color-alone true
asc accessibility update --id <id-ipad>   --supports-differentiate-without-color-alone true
asc accessibility update --id <id-mac>    --supports-differentiate-without-color-alone true
asc accessibility update --id <id-vision> --supports-differentiate-without-color-alone true

# Reduce Motion: after toggling the setting on device and confirming nothing still scales.
asc accessibility update --id <id-iphone> --supports-reduced-motion true
asc accessibility update --id <id-ipad>   --supports-reduced-motion true
asc accessibility update --id <id-mac>    --supports-reduced-motion true
```

## Step 8 — publish

Nothing above is visible on the product page until each declaration is published. Run this
last, once the attributes for a family are final:

```bash
asc accessibility update --id <id-iphone> --publish true
asc accessibility update --id <id-ipad>   --publish true
asc accessibility update --id <id-mac>    --publish true
asc accessibility update --id <id-vision> --publish true
```

Then re-run `asc accessibility list --app 1433801905` and confirm the product page no longer
shows "The developer has not yet indicated which accessibility features this app supports".

### Evidence per attribute

| Attribute | Families | Evidence |
|---|---|---|
| `captions` = `false` | all four | The app plays no video content — verified by reading, no player component exists |
| `audio-descriptions` = `false` | all four | Same reason — no video content |
| `dark-interface` = `true` | all four | `colorScheme` is evaluated app-wide; confirm no screen renders unreadable in dark appearance before running the step-1 command |
| `larger-text` = `true` | IPHONE, IPAD, MAC | This PR: `StatCard.swift` uses `.font(.title.bold())` instead of a fixed 28pt, so the value now grows with Dynamic Type; its `minimumScaleFactor` stays at `0.7` because `.title` reaches 53pt at AX5 and a tighter floor truncates a value like "45,3 MB". `TagView.swift` raised from `0.85` to `0.9`. Walk the whole Statistics screen at AX5 on device before declaring |
| `larger-text` | VISION | Left undeclared unless the app has actually been run on visionOS hardware/simulator |
| `voiceover` / `voice-control` | IPHONE, IPAD, MAC | Only after the manual checklist below is walked on that platform with no open defects beyond what this PR already fixed |
| `differentiate-without-color-alone` = `true` | all four | Full sweep (below): every colour-coded state already carries a distinct SF Symbol and a text label. The one colour-only case, `TagView`'s suggestion fill, is fixed in this PR |
| `reduced-motion` = `true` | IPHONE, IPAD, MAC | This PR gates the app's two scale animations (`IAPView` badge, `DropButton` drop target) on `accessibilityReduceMotion`; every other animation is a fade or a sub-100ms functional transition. Confirm on device with the setting on before declaring |

### Left undeclared, and why

- `supports-sufficient-contrast` — **measured and failing**, see below. Declaring it would
  require darkening the brand red app-wide, which was deliberately declined; the attribute
  stays undeclared rather than being declared falsely.
- `voiceover` / `voice-control` on any family whose manual checklist below is not walked,
  or comes back with an open defect — a partially declared family is correct; a family
  declared `true` on an unverified attribute is not.

## Manual VoiceOver checklist

No agent can operate VoiceOver by touch. The code audit below fixed what was unambiguously
a defect and fixable without a layout change (see the PR diff: `TagView.swift` and the
suggested-date buttons in `DocumentInformationForm.swift`).
Everything else in this list needs a human to walk it on-device, once per platform (iPhone
first, then macOS — the tagging form shares code but not behaviour between the two).

Start in the tagging screen (`DocumentInformationForm`) — that is where the 2021 review
that opened this issue got stuck.

| Screen / control | What to verify | Expected announcement |
|---|---|---|
| Date section — `DatePicker` | Swipe up/down adjusts the date and VoiceOver announces the new value | "Date, `<value>`, adjustable" |
| Date section — suggested-date buttons | Fixed in this PR: label now spells out the date instead of the raw two-digit numbers. Confirm the full sentence is read, and that activating one visibly updates the `DatePicker` | "Suggested date, `<long-form date>`, button" + hint "Sets the document date to this value" |
| Date section — "Today" button | Confirm the icon-only button still announces its title (it already should — same `Label` pattern used ~50 times elsewhere) | "Today, button" |
| Specification field — `TextField` (`axis: .vertical`) | Type multi-line text; confirm the "insertion point at end" announcement (heard after editing) does not strand focus and the field is still reachable afterward. This is expected system behaviour for a multi-line field, not a code defect — record only if VoiceOver actually gets stuck | "Specification, text field, `<value>`" |
| Tag field — `TextField` + `onSubmit` | Type a tag name and confirm the return key (`onSubmit`) adds it while VoiceOver is active, on both a hardware and the on-screen keyboard | "Tag, text field" |
| Suggested tags list | Fixed in this PR: suggestion chips announce as suggestions, carry a dashed border rather than colour alone, and have their own "adds" hint. Confirm activating one adds it to the document | "Suggested tag: `<name>`, button" + hint "Adds this tag to the document" |
| Assigned tags list | Fixed in this PR: the remove button now announces its action; the `xmark` icon is hidden from VoiceOver. Confirm double-tap actually removes the tag and focus lands somewhere sensible afterward, not stranded | "`<name>`, button" + hint "Removes this tag from the document" |
| Tag selection delay indicator | `CircularProgressView` is two bare `Circle()` shapes, which expose no accessibility element at all — nothing to hide and nothing announced. Confirm it is genuinely not reachable; if a VoiceOver user should know the suggestion list is about to refresh, that needs a real label and is a follow-up | not reachable |
| `focusedField` order: date → specification → tags → save | Confirm the swipe/rotor order (iOS) and Tab order (macOS) matches this sequence and nothing is skipped or duplicated. **Do not change the order in code** — if this fails, file a follow-up issue instead, per the plan | sequential, no skips |
| End-to-end loop | Scan a document, tag it, save it, find it in the archive — the full loop by touch only, VoiceOver on | every step reachable and announced |

Record every defect found with the screen and the exact announcement heard. Anything that
needs a structural change (a rebuilt focus order, a custom rotor) is a follow-up issue, not
a blocker for this one — file it and link it here before declaring `voiceover` /
`voice-control` `true` for the affected family.

## Beyond the issue — sweep of the three remaining attributes

Issue #318 put these three out of scope as unaudited. They have now been audited; this is
the evidence, so the decision does not have to be re-derived later.

### `supports-differentiate-without-color-alone` — declarable

Every state that uses colour also carries a distinct shape and a word:

| Location | State | Non-colour carrier |
|---|---|---|
| `AppleIntelligenceSettings.swift:198-228` | available / incompatible / unavailable | `checkmark.circle.fill`, `xmark.circle.fill`, `exclamationmark.circle.fill` + text |
| `PremiumSectionView.swift:70-88,126-141` | active / inactive | `checkmark.circle.fill` / `xmark.circle.fill` + text |
| `DropButton.swift:104-107` | finished | `checkmark.circle` glyph itself |
| `DocumentDetails.swift:290,351` | destructive | `Label("Delete", systemImage: "trash")` |
| `TagView.swift` | suggestion vs. assigned | **was colour-only — fixed in this PR** (dashed border + "Suggested tag" in the accessibility label) |

### `supports-reduced-motion` — declarable after this PR, confirm on device

`accessibilityReduceMotion` was evaluated nowhere. Eight animations exist outside the
widgets; only two are the positional/scaling motion the setting targets, and both are now
gated:

| Site | Motion | Handling |
|---|---|---|
| `IAPView.swift` | `.transition(.scale)` on the Premium badge | gated -> `.opacity` under Reduce Motion |
| `DropButton.swift` | `.scaleEffect(1.1)` when a drag enters the target | gated -> no scale under Reduce Motion |
| `TagView.swift` | `.transition(.opacity)` | fade; Reduce Motion does not require suppressing it |
| `CircularProgressView.swift` | 0.1s linear trim | functional micro-transition |
| `DropButton.swift` | `.symbolEffect(.pulse)` | opacity-based, not positional motion |
| `OnboardingScreens.swift`, `DeleteDocumentButtonView.swift` | `withAnimation` around a state toggle | no explicit motion of their own |

With Reduce Motion off, rendering is unchanged by these gates.

### `supports-sufficient-contrast` — NOT declarable, and deliberately not fixed

`paRed.colorset` is display-P3 `0xE6/0x69/0x67`, resolving to sRGB `#F85F62` (relative
luminance 0.290). It has no dark-appearance variant. Measured against WCAG 2.1:

| Pair | Where | Ratio | AA text (4.5:1) | AA large / UI (3:1) |
|---|---|---|---|---|
| white on `paRed` | `TagView` assigned tag, ~17pt | 3.09:1 | fail | pass |
| white on `Color.gray` | `TagView` suggestion, ~17pt | 3.26:1 | fail | pass |
| `paWhite` on `paRed` | `IAPView` "Premium" badge, 13pt | 2.96:1 | fail | fail |
| `paRed` on `paBackground` | `CircularProgressView` ring | 2.96:1 | fail | fail |

Reaching 4.5:1 with white text needs the brand red at roughly `#C94D50` — same hue and
saturation, brightness 0.97 -> 0.79. That is a visible app-wide brand change and was
declined; the attribute stays undeclared. Revisit only as a deliberate brand decision.
