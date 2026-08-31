# Accessibility Nutrition Label declarations (issue #318)

Operational runbook for App Store Connect's accessibility declarations. This is not app
documentation — it is the set of `asc` commands a human runs to publish what issue #318
verified, plus the manual VoiceOver checklist that a code audit cannot complete.

No `asc` command in this file has been run except the read-only `list` below. Publishing
these declarations is an outward-facing action left for the user to run and review.

## Current state (recorded via `asc accessibility list --app 1433801905`)

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
```

### Evidence per attribute

| Attribute | Families | Evidence |
|---|---|---|
| `captions` = `false` | all four | The app plays no video content — verified by reading, no player component exists |
| `audio-descriptions` = `false` | all four | Same reason — no video content |
| `dark-interface` = `true` | all four | `colorScheme` is evaluated app-wide; confirm no screen renders unreadable in dark appearance before running the step-1 command |
| `larger-text` = `true` | IPHONE, IPAD, MAC | This PR: `StatCard.swift` now uses `.font(.title.bold())` at `minimumScaleFactor(0.9)` instead of a fixed 28pt size; `TagView.swift` raised from `0.85` to `0.9`. Both checked against Dynamic Type `AX5` per the plan — confirm on device before declaring |
| `larger-text` | VISION | Left undeclared unless the app has actually been run on visionOS hardware/simulator |
| `voiceover` / `voice-control` | IPHONE, IPAD, MAC | Only after the manual checklist below is walked on that platform with no open defects beyond what this PR already fixed |

### Left undeclared, and why

- `supports-sufficient-contrast` — needs colour measurement of the brand palette against
  WCAG contrast ratios, not a code change. Out of scope for #318.
- `supports-differentiate-without-color-alone` — this PR fixes the one known instance
  (`TagView` suggestion vs. assigned tag), but declaring the attribute needs a full sweep
  for colour-only meaning across every screen, which has not been done.
- `supports-reduced-motion` — `accessibilityReduceMotion` is evaluated nowhere in the app;
  whether any animation needs to respect it is unaudited.
- `voiceover` / `voice-control` on any family whose manual checklist below is not walked,
  or comes back with an open defect — a partially declared family is correct; a family
  declared `true` on an unverified attribute is not.

## Manual VoiceOver checklist

No agent can operate VoiceOver by touch. The code audit below fixed what was unambiguously
a defect and fixable without a layout change (see the PR diff: `TagView.swift`,
`CircularProgressView.swift`, the suggested-date buttons in `DocumentInformationForm.swift`).
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
| Suggested tags list | Fixed in this PR: suggestion chips now announce as suggestions and carry a dashed border, not colour alone. Confirm the announcement and that activating one adds it to the document | "Suggested tag, `<name>`, button" |
| Assigned tags list | Fixed in this PR: the remove button now announces its action; the `xmark` icon is hidden from VoiceOver. Confirm double-tap actually removes the tag and focus lands somewhere sensible afterward, not stranded | "`<name>`, button" + hint "Removes this tag from the document" |
| Tag selection delay indicator | Fixed in this PR: the transient circular countdown is now hidden from VoiceOver (it carried no label and would otherwise strand focus on two silent shapes). Confirm it is no longer reachable by swipe | not reachable — hidden |
| `focusedField` order: date → specification → tags → save | Confirm the swipe/rotor order (iOS) and Tab order (macOS) matches this sequence and nothing is skipped or duplicated. **Do not change the order in code** — if this fails, file a follow-up issue instead, per the plan | sequential, no skips |
| End-to-end loop | Scan a document, tag it, save it, find it in the archive — the full loop by touch only, VoiceOver on | every step reachable and announced |

Record every defect found with the screen and the exact announcement heard. Anything that
needs a structural change (a rebuilt focus order, a custom rotor) is a follow-up issue, not
a blocker for this one — file it and link it here before declaring `voiceover` /
`voice-control` `true` for the affected family.
