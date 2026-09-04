# Design plan — PDF Archiver store frames, iteration on session B

Session B was chosen as the direction (airier than A, device smaller, larger type). This
iteration keeps B's proportions and adds graphic elements. Written against the
`frontend-design` skill, which indicts the previous draft on three counts:

1. **The single-word colour accent is a listed tell** — "accenting just a single word or
   phrase in a headline". Every previous headline did exactly that with `<em>` + coral. Gone.
2. **`-apple-system` is the default reach on any Apple project**, not a choice.
3. **No graphic elements at all** — a gradient, a device outline and text.

## The subject, stated

A document archiver whose actual promise is that the archive is *plain folders and files*:
`2026-04-12--acme-invoice__tax_invoice.pdf` inside `2026/`. Audience: people who keep paper
records for years and distrust apps that own their data. The frames' job: make "this outlasts
the app" visible, not asserted.

**So the material is the product's own artefact — filenames, year folders, paper.** That is
where the graphic elements come from; nothing decorative gets added on top.

## Color — 6 tokens

| Token | Hex | Role |
|-------|-----|------|
| `--slate` | `#0e141c` | the ground; the archive box. Blue-tinted navy from the app icon, not a tinted near-black standing in for black |
| `--slate-lift` | `#18222e` | lifted ground for the gradient and panels |
| `--paper` | `#f2ece4` | warm paper — the literal input material of a scanner, and the second material that keeps the frame from being mono-accent |
| `--ink` | `#eef2f7` | headline |
| `--ink-soft` | `#93a0b1` | filenames, years, secondary data |
| `--coral` | `#e66967` | the app's own tag colour. **Spent once per frame**, never on a single headline word |

## Type — two families, both shipped with macOS

- **Charter** (`/System/Library/Fonts/Supplemental/Charter.ttc`) for headlines. Matthew
  Carter designed it to stay legible on coarse, low-resolution output — a typeface built to
  survive bad conditions. For "an archive that outlasts the app" that is an argument, not a
  mood. Sturdy serifs and a generous x-height also survive the store's thumbnail, where a
  Didone would lose its hairlines.
- **Menlo** for filenames, paths and dates. The skill flags "a monospace face for small data
  labels" as template chrome, and it is right — but here monospace is not a label style, it
  is what a filename *is*. The frame shows real archive material, so it is set the way the
  Finder sets it.
- No third family. Scale: headline 6.4vh / 1.08, filename 2.5vh, year spine 1.9vh.

## Layout — three directions to compare

Alignment is left throughout: these are records, and records are read down a left edge.
The `statement` shot is the one exception, centred, because it has no material to align to.

### B1 · Aktenrücken (the year spine)

A vertical run of years down the left edge, hairline-ruled, device offset right. Years are a
real sequence, so ordered markers are justified here — the test the skill asks for.

```
┌──────────────────────────┐
│ 2026 ┃ Jedes Blatt       │
│ 2025 ┃ bleibt lesbar     │
│ 2024 ┃                   │
│ 2023 ┃   ┌────────────┐  │
│ 2022 ┃   │            │  │
│ 2021 ┃   │   device   │  │
│ 2020 ┃   │            │  │
└──────┸───┴────────────┴──┘
```

### B2 · Dateiname (the filename as hero)

The naming convention set large in Menlo, breaking across two or three lines, with the device
below it. The filename is the proof of the claim, so it gets the boldness — the headline goes
quiet above it.

```
┌──────────────────────────┐
│ Jedes Blatt bleibt       │
│ lesbar                   │
│                          │
│ 2026-04-12--acme         │
│ -invoice__steuer.pdf     │ ← Menlo, large: this IS the graphic
│    ┌────────────┐        │
│    │   device   │        │
└────┴────────────┴────────┘
```

### B3 · Stapel (the paper stack)

The device rests on offset sheets of warm paper, filenames visible along the exposed edges.
The sheets differ in width and angle and are tinted paper, not grey — identical rounded cards
under one soft grey shadow is the SaaS-card tell the skill names.

```
┌──────────────────────────┐
│ Jedes Blatt              │
│ bleibt lesbar            │
│    ╱──────────────╲      │
│   ╱  ┌──────────┐  ╲     │ ← sheets, paper-toned, unequal
│  ╱   │  device  │   ╲    │
│ ╱    │          │    ╲   │
└──────┴──────────┴────────┘
```

## Principles

- **Boldness once per frame.** B1 spends it on the spine, B2 on the filename, B3 on the
  paper. Everything else stays quiet.
- **Every graphic element carries information.** The years say "this goes back", the filename
  says "it is readable without the app", the paper says "it started as paper". Nothing is
  there to fill space.
- **Coral appears exactly once per frame**, and never as one coloured word in a headline.
- **German copy, sentence case, plain verbs.** No word-level emphasis, no eyebrow labels
  above headlines, no all-caps.

## Genericness review, before building

- *Would I produce the year spine for any app?* No — it only means something because the
  archive is organised by year. Kept.
- *The filename hero?* It is this product's own convention; it cannot transfer. Kept, and
  promoted to the strongest of the three.
- *The paper stack?* Paper is a scanner's literal input. Kept, **with the correction** that
  the sheets must vary in size and tone or it becomes the layered-card default.
- *Dark ground + one bright accent is calibration trait #2.* Mitigated: paper is a second
  material, so the frame is not one accent on near-black, and the ground is genuinely the
  icon's navy rather than a tinted black.
- *Charter risk:* a serif can lose weight on a dark ground at thumbnail scale. To verify by
  rendering and looking, not by assertion.

---

## Critique after building B1 — the thumbnail test changes the ranking

Rendered B1, then downscaled to 180 px wide (three screenshots side by side in App Store
search results on a phone) and magnified back up to see what survives:

| Element | At 1320×2868 | At 180 px |
|---------|--------------|-----------|
| Charter headline, 6vh | reads with clear serif character | **survives** — legible |
| Year spine, 1.9vh Menlo | a ruled record edge | **gone** — grey ticks; only the coral 2026 registers |
| Filename, 2.1vh Menlo | the proof of the claim | **gone** — an unreadable smear |

So B1 spends its boldness on something that disappears at the size where most people meet
the image. Apple's own asset guidance says the same thing from the other direction: *"Ensure
all key elements are readable — especially any text."*

**Revisions this forces:**

1. **Nothing that must be read may be small.** A graphic element made of small type is not an
   element, it is texture. B1's spine is demoted to exactly that, and one large current year
   carries it instead.
2. **B2 is promoted to the favourite** — it puts the same filename material at a size that
   survives, which is the whole point of the direction.
3. **B3 hedges with shape rather than type** — paper edges scale down without losing their
   meaning, so it should survive the thumbnail by construction. Worth building to compare.
4. `word-break: break-all` broke the filename mid-token (`energie_ / rechnung.pdf`), which
   reads as damage rather than as a wrap. Break at the separators or shorten the example.

---

## All three built — thumbnail test as the decider

Every direction re-tested at 180 px (App Store search-result scale):

| | Graphic element | At full size | At 180 px | Verdict |
|---|---|---|---|---|
| **B1 · Aktenrücken** | one large year reading up the left edge, coral | a box-file spine | **survives** — the year is legible | fixed; the eight-year run it replaced was invisible |
| **B2 · Dateiname** | the naming convention in Menlo, 3.5vh | the strongest *argument*: the archive is legible without the app | **recognisable, not readable** — you see it is a filename with a coral extension | conceptually best, weakest at thumbnail |
| **B3 · Stapel** | three unequal paper sheets, warm on slate | phone resting on the paper it came from | **fully survives** — it is a shape, so it loses nothing | strongest at the size that matters |

Confirmed: **a graphic element made of shape survives reduction; one made of type does not.**
That is the single most useful thing this iteration produced, and it generalises beyond this app.

### What changed against the previous draft, and why

- **The single-word coral accent is gone from all three.** It is a listed tell, and comparing
  the new sessions against `session-b-deep` in the overview shows the difference in discipline
  immediately.
- **Charter replaces `-apple-system`** for headlines and holds at thumbnail size — verified,
  it was the one risk flagged in the plan before building.
- **Menlo only where the content is genuinely monospace material** (filenames, dates), never
  as a decorative small-caps-substitute label.
- **Coral is spent once per frame**: B1 on the year, B2 on the file extension, B3 on the top
  sheet's edge in the statement frame.

### Open

- **B3 has no coral at all on four of its five frames.** Restraint, or an inconsistency with
  the stated principle — a judgement call left to the client.
- **The obvious combination is untried:** B3's paper stack carrying B2's large filename on the
  top sheet. It would put the surviving element and the strongest argument in the same frame.
- B3's `statement` frame reads slightly disconnected — headline on the dark ground, paper
  below it, with little tying them together.

---

## B4 · Webseite — added on the client's instruction to carry the site's design

Not a reinterpretation: the tokens, the type stack and the annotated-filename component are
lifted from a live fetch of `pdf-archiver.io/css/styles.css` and its markup.

- `--ink #141c27`, `--paper #fbf7f6`, `--paper-sunk #f3eae8`, `--coral #ca414f`,
  `--text #23282f`, `--text-soft #5c626b`, `--rule #e6dbd8`
- `--font-body: system-ui, …` for the headline, `--font-mono` for the filename
- The site's `.filename` figure: a dark navy panel on the light page, the name split into
  `part-date` / `filename-sep` / `part-desc` / `filename-sep` / `part-tags`, each part
  labelled underneath with a rule above the label

**Two carry-overs a style guide would flag**, kept because matching the site is the brief and
the brief wins: the labels are uppercase and letter-spaced, and the display face is the system
sans — both listed as generated-page tells, and both the site's own deliberate choices.

**Thumbnail test: the best result of any direction.** The dark panel on the light ground is a
solid shape, so at 180 px you still read a headline, a structured dark bar with a coral
segment, and a device. It satisfies all four constraints at once — the client's instruction,
thumbnail survival, subject grounding, and the strongest argument for the claim.

### Known issues in B4, both from the light ground

- **A light device on a light ground nearly disappears** while the screen is a placeholder.
  Real captures will fill it, so the composition cannot be finally judged until phase 2 — but
  the `close` layout (2-scan) needs the crop to carry a rule or a deeper shadow regardless.
- **The `statement` frame is very empty**: centred headline and prose on plain paper, with
  nothing of the site's vocabulary in it. It should probably use the filename panel too, the
  way the site's own hero does.
- **The light ground commits the capture side to light mode.** Not a design flaw, a
  dependency: it has to be decided before the snapshot tests are written.

## Ranking after four directions

1. **B4 · Webseite** — the site's own design, best thumbnail survival, strongest argument.
2. **B3 · Stapel** — most distinctive as an image, element survives completely, but it is a
   look of its own rather than the site's.
3. **B2 · Dateiname** — the right idea, undersized; B4 is what B2 wanted to be.
4. **B1 · Aktenrücken** — fixed to survive, but the spine is decoration next to the others.

---

## B5 · Webseite in Linien — the chosen direction, softened

Client feedback on B4: the dark panel is too hard, maybe just lines; and it should appear on
the first frame only. Other site components should carry the remaining frames, and frame 4
should pick the three colours up again and explain the parts.

**The panel became rules.** Each part of the filename now sits on the paper with a rule under
it in that part's own colour. This is still the site's design — a hairline rule is its own
separator idiom (`.faq-entry { border-top: 1px solid var(--rule) }`) — just quieter.

**One site component per frame, so the set varies inside one vocabulary:**

| Frame | Component | Why that frame |
|-------|-----------|----------------|
| 1 · archive | the filename, in rules | the claim's proof, and the only frame that carries it |
| 2 · scan | `.feature-card-tag` numbered circle ① | the site numbers its three steps; scan is the first |
| 3 · tag | numbered circle ② plus `.chips` pills | the shot is about tags, and chips *are* tags |
| 4 · outlasts | the legend: three rules in the three colours | names what each part is for — the callback to frame 1 |
| 5 · find | `.promise-icon` checks | Spotlight, Finder, any app — the site's own promise list |

Numbering passes the test the skill asks for: scan → tag → find is a real sequence, and it is
the site's own.

**Colour translation.** On the site the three parts live in a navy panel as `#a2aebd` / `#fff`
/ coral. White is invisible on paper, so the description takes `--ink`; date softens to
`#7d8894`. Same three roles, readable ground.

### The measured cost of softening

Frames rendered side by side at 180 px:

| | At 180 px |
|---|---|
| B4, dark panel | unmistakable — a solid structured bar |
| B5, rules | **still legible as three coloured segments**, clearly fainter |

So the softer treatment does not vanish the way B1's small type did — coloured rules are still
shapes — but it gives up presence in search results. A middle ground exists if that matters:
thicker rules (0.6vh) and slightly larger values, structure without a block.

### Still open in B5

- Labels (1.2vh) and the legend's explanations (2.1vh) are below thumbnail legibility. Fine
  for frame 4, which Apple does not show in search results; worth checking on the product page.
- **The device still reads as nearly empty**, because a light placeholder on a light ground has
  almost no contrast. It is a placeholder artifact, not a design flaw — but the composition
  cannot be finally judged until real light-mode captures are in.
- The legend frame has a lot of empty space above and below its three rows.

---

## Correction: the dark panel was never the site's design

B4 lifted a dark navy panel from the stylesheet's `.filename*` rules. **The live hero does not
use them.** It uses `.sig-card` / `.sig-line` / `.sig-part`, and that component is:

```css
.sig-card { background: var(--card);        /* #fff — a WHITE card */
            border: 1px solid var(--rule);  /* a hairline */
            border-radius: 1.5rem;
            box-shadow: 0 24px 50px -32px rgba(20,28,39,.22); }
.sig-label { border-top: 1.5px solid currentcolor; }  /* a rule per part, in its colour */
.sig-date { color: var(--text-soft) } .sig-desc { color: var(--text) }
.sig-tags { color: var(--accent) }    .sig-sep, .sig-ext { color: #b9c2cc }
```

The `.filename` rules are still in the file but appear to be superseded. So the client's
instinct — *"der dunkle Kasten ist zu hart, vielleicht nur Linien"* — independently landed on
what the site actually does, including the per-part rules. B5 was already closer to the real
site than B4 was; B6 makes it exact.

## Why a static render of the site came out empty

The hero types itself in: `.sig-reveal { clip-path: inset(0 100% 0 0); animation: reveal-type … }`,
with labels fading in on a delay. A still capture freezes an animation's **first** frame, so
the card rendered as an empty white box. The site already ships the finished state — inside its
`prefers-reduced-motion` block — so forcing that state is what makes a still render show what a
visitor ends up seeing:

```css
.sig-reveal { animation: none !important; clip-path: inset(0 0 0 0) !important; }
.sig-label  { animation: none !important; opacity: .75 !important; }
```

Worth remembering generally: any animated page needs its end state forced before it is
captured, and the load gate cannot detect this — the page is *correct*, just mid-animation.

## Charter on the homepage

Both faces built as real local copies of pdf-archiver.io (`website-charter/charter` and
`website-charter/system-ui`, `vergleich.png` for the pair). Charter makes the lead prose and
the three-step cards distinctly more editorial, which suits an app about keeping records; the
headline gains character and loses a little hardness. The mono parts are untouched either way.

## B6 · Charter, corrected component, real capture

The site ships `assets/img/screenshots/archive-iphone-en.png` at exactly **1320×2868** — a real
app capture at store size. Wired in as the frames' screenshot, so the composition is finally
judgeable rather than a placeholder guess. Two things it revealed:

- **The app's own coral tag chips echo the coral in the filename card.** The set coheres for a
  reason nobody designed, which is the best kind.
- **A dark app screen inside a light frame works better than predicted.** It reads as a screen,
  not as a hole. A light-mode capture would still be more cohesive.

**Best thumbnail of every direction so far**, because the real screen carries most of the
communication at that size and the card survives as a three-segment shape.

### Two fixes it forced

1. **The filename ran off the frame.** Fixed with the site's own device: `container-type:
   inline-size` on the card and `font-size: clamp(…, calc(160cqw / var(--fn-chars)), …)`, so the
   name is sized from the card's width rather than the viewport's.
2. **Then it was too small to matter.** 55 characters shrink the type below use. So the example
   filename's *length* is a design parameter, not just content — shortened to
   `2026-03-12--stadtwerke__energie.pdf` (35 chars).

### Still open

- The wired-in capture is **English** (`electricity bill`, `rental agreement`) while the copy is
  German. Needs real German captures from phase 0.
- Frame 4's explanations sit below thumbnail legibility — acceptable there, worth a check on the
  product page.

---

## Content pass on B6, and why the step numbers went

**The numbered circles are gone from 2-scan and 3-tag.** On the website the numbers work
because the three cards sit side by side and the sequence is visible in one view. A store
frame is seen alone — Apple may show only the first three of the set — so an isolated "2" has
nothing to count against and reads as a stray UI fragment. This is the skill's own test
applied properly: the content has to be a sequence *within the frame*, not across the set.

They are replaced by the site's plain `.feature-lead` line, which lets the capture carry the
frame.

**The copy now comes from the client's own `/de/` page** rather than being translated:

| Frame | Headline | Source |
|-------|----------|--------|
| 1 · archive | Ein Archiv, das die App überdauert | the site's hero lead (it says *überdauert*, not *überlebt*) |
| 2 · scan | Halte dein iPhone über die Seite | the site's "Scan it." lead, verbatim |
| 3 · tag | Datum, Beschreibung, Tags | the site's "Tag it." lead, verbatim |
| 4 · keep | Der Name erklärt sich selbst | ours — the site's own section here is "Keep it." |
| 5 · find | Such nach einem Tag oder dem Text im Dokument | the site's "Find it." lead, verbatim |

The promises are the site's too: *Alles bleibt auf deinem Gerät. · Kein Konto. · Du
entscheidest, wo die Dateien liegen.*

Worth knowing: the German page keeps **"Scan it. Tag it. Find it."** in English as the brand
line, and its section structure is a four-beat — Scan · Tag · Find · **Keep** — not three.

## Frame 4, regrouped

Three loose rules on the paper read as three separate thoughts. They now sit inside **one**
white card — the site's `.sig-card` — separated by hairlines, which is the site's own
`.faq-entry` idiom for items inside a block. Each value keeps its part's colour and its own
underline, so a reader who saw frame 1 recognises the same three marks being explained.

Three composition fixes from looking at the result: the promises were footnote-sized and are
now read size (2.6vh), the filename card hugged its type too loosely (padding down, width up
to 93vw), and frame 4 was bottom-heavy.

### The one content problem left, and it is not fixable here

**Frames 1, 3 and 5 all show the same capture** — the archive list, three times — because the
only real capture available is the site's `archive-iphone-en.png`. The set needs its own
screens: the scan view, the tagging fields, a search result. That is phase 0 work in the app
repo, and it is also where the **English/German mismatch** gets fixed (`electricity bill` under
German headlines).

Until then the layouts are settled but the set repeats itself, which is the one thing a
five-frame series must not do.

---

## Phase 2 · all three platforms, real captures throughout

The app now writes its own captures (`../<locale>/{iphone,ipad,mac}`), so every frame that
shows a device shows a real screen and the set no longer repeats itself. The framed sets moved
to `../framed/<locale>/<set>` — the raw directories beside them are the *unframed* store set the
UI tests write and are this design's input, not its output. `build-all.sh` renders all six sets
and the overview page in one go.

| Set | Target | Device in the frame | Captures |
|-----|--------|--------------------|----------|
| `iphone-6.9` | 1320×2868 | 70vw portrait, bleeds off the bottom | 1260×2736, downscaled |
| `ipad-13` | 2752×2064 **landscape** | 60vw, bleeds off the right | 2752×2064, downscaled |
| `mac` | 2880×1800 | 60vw, bleeds off the right | 1440×900, upscaled 1.2× |

### The portrait design became token-driven instead of being copied

`frame.css` held the iPhone's geometry as literals (`70vw`, `aspect-ratio: 1320/2868`, `6vh`),
so the iPad and Mac manifests' `--device-*` overrides were dead and a landscape frame rendered a
portrait device holding a landscape capture. Geometry is now `:root` tokens whose defaults are
the iPhone frame — the portrait set re-renders **byte-identical**, which is the check worth
keeping when touching this file.

### Landscape is a media query, not a second stylesheet

The renderer pins the viewport to the target pixel size, so `@media (min-aspect-ratio: 1/1)` is
deterministic: it is the target's aspect, not a guess about a viewer. That block turns the stack
into two columns — copy left, device right — and it belongs in the stylesheet rather than in four
manifests' `style` strings, which is where a per-platform copy of a composition rots.

**Two findings from building it:**

1. **A device that fits its column floats.** Sized to fit, the window filled ~50 % of the canvas
   height and the frame read as content adrift in a void. `justify-content: flex-start` on the
   stage lets a device wider than its column run off the right edge — the same bleed the portrait
   frames give the phone at the bottom. 60vw cuts ~5 %, which reads as "continues past the frame".
   Measured against 64vw, which cut 10 % and took the Mac tagging form's right column with it:
   **the bleed has to stop before it eats a control the frame's headline is about.**
2. **A device-less layout must not collapse to one column.** `statement` and `symbols` first fell
   back to a single centred column, which left the right half of the canvas empty while the
   portrait frames were full. Their component now takes the device's column, and both get a
   larger headline (10.4vh iPad, 12.6vh Mac) because no device is competing for the space.

### The Mac window's own corners are baked into the capture

The capture is the screen rectangle, so the desktop shows through the window's rounded corners as
black wedges — inside a bezel they read as damage. Measured across all three Mac captures: the
dark inset runs 41–56 px at the extreme rows, so the radius is ~55 px in a 1440 px wide capture.
The screen is clipped at that radius scaled to the displayed device:

```
--screen-corner: calc(var(--device-width) * 0.038)   /* 55 / 1440 */
```

Against `--device-width`, not a literal, so changing the device size cannot silently reopen the
wedges. `--bezel: 0` with it: a macOS window already carries its own chrome, and a light bezel
around it reads as a fake monitor.

The same clip on the iPad had to come **down**, not up: at 2.8vh it ate the leading `1` of the
status bar's `10:48`. The capture is full-bleed, so the only thing needing clipping there is the
simulator's own corner artifact — 1.4vh.

### The Mac set is its own four beats

The Mac has three captures (archive, tagging, the open document) and no camera, so the iPhone's
`2-scan` symbols frame would be a lie. The set is `1-archive · 2-tag · 3-document · 4-keep ·
5-privacy`, and two of those headlines are **newly written rather than taken from the site** —
worth a read before upload:

- `3-document`: "Such nach einem Tag oder dem Text im Dokument" is the site's *Find it.* lead, but
  the lead under it ("Der erkannte Text steckt im PDF — im Archiv, in Spotlight, im Finder.") is ours.
- `5-privacy`: "Ohne Konto, ohne Server" is ours; the three promises under it are the site's.

### Still open

- **The Mac capture is 1440×900 and the frame is 2880×1800**, so the window is upscaled 1.2×.
  Fixing it properly is a capture-side change (a larger window), and the skill's own note says a
  bigger window renders the app's text too small to read — so it is a trade, not a bug.
- **The iPad's archive screen is mostly empty below the list**, which the frame inherits. Only a
  denser fixture archive fixes that, not the framing.
- Leads and the filename card's labels stay below thumbnail legibility, as in phase 1. The
  headlines and the device carry the frame at 180 px, which the thumbnail sheets confirm.

---

## Phase 2b · client pass over all three sets

Per-frame instructions, so the composition now varies per shot inside one vocabulary — which is
the stated principle, applied further than phase 2 took it.

| Frame | Change |
|-------|--------|
| iPhone 1 | the whole phone, bottom flush; equal air above and below the filename card |
| iPhone 3 | same device width, bottom flush, the phone's top dissolving into a blur |
| iPhone 5 | same device width (still bleeds off the bottom) |
| iPad 2 | headline on top across the full width, lead and tiles beneath it |
| iPad 3 | headline across both columns, iPad anchored bottom-right with its shadow inside the frame |
| iPad 4 | headline on top across the full width, the card beneath it |
| Mac 1–3 | the window fits its column — no crop — and the gap to the copy widened to 5vw |
| Mac 4–5 | headline on top across the full width, the component beneath it |

`--hero-device-width: 72.4vw` ties the three iPhone devices together. It is **derived, not
chosen**: it is the width at which frame 1's device fills the height left by the headline and the
card, which is what makes that frame's two gaps equal (measured 89 px / 91 px). Change frame 1's
copy and the number needs re-measuring — the other two frames follow it.

### Two bugs the client pass exposed, both worth remembering

1. **A label wider than its value sets the filename row's width, and the name then runs off the
   card.** `.fn-label` was sized in `vh`, so scaling the Mac set up by 1.67× made
   "BESCHREIBUNG" wider than "stadtwerke" and pushed `.pdf` past the card's edge. Fixed at the
   root: the label is sized from the card like `.fn` itself, at 0.70 of the value
   (`calc(100cqw / var(--fn-chars))`), so no target can reintroduce it. Measured after: ink ends
   at x=716 in a card whose content runs to x=1006.
2. **A gradient mask tiles.** `mask-image` defaults to `mask-repeat: repeat`, so the blurred copy
   on iPhone 3 had its halo painted *opaque* 54 px above the phone's top edge — a soft grey band
   floating over the paper. `mask-repeat: no-repeat` plus `overflow: hidden` on the device fixes
   it; the cost is the device's drop shadow, which the mask clips away. On a frame whose top
   deliberately dissolves, that is no loss.

**How the blur is built**, since CSS cannot blur part of one element: a second copy of the capture
as a `background-image` on `.device::before`, blurred and masked to the top, over the sharp one,
with the whole device masked to fade out upward. Sharp at the bottom → defocused → transparent.
Verified rendering in the snapshot path — the framing reference's warning about `filter: blur()`
and `mask-image` applies to `createPDF`, which this pipeline does not use.

### Measuring beats eyeballing here

Two readings in this pass were wrong from looking at the image and right from measuring: the
device widths appeared to differ (it was the drop shadow's falloff, not the bezel), and frame 1's
card gaps appeared unequal (they are 89/91). The probes now live in the session scratchpad, but
the technique is worth rebuilding when it matters: bands down the canvas, transitions along one
column or row, and a slope test over 4 px to tell a bezel edge from a shadow ramp.

### Open

- **iPhone 5's phone still bleeds off the bottom** while 1 and 3 sit flush — only its width was
  brought in line.
- **The four stacked frames leave the lower canvas empty** (iPad 2, iPad 4, Mac 4, Mac 5). The
  arrangement is as instructed; filling it needs either a larger component or the block centred
  in the space under the headline.
- iPad 3's chips wrap onto two lines now that its text column is 32 %.

---

## Phase 2c · one title everywhere, and the Mac window's corners

**The title is now a single declaration** — Charter, 700, and one size that renders at the same
172 px in all fifteen frames (6vh on the iPhone's 2868 px canvas, 8.34vh on the iPad's 2064,
9.56vh on the Mac's 1800). The per-layout variants are gone too, so the `statement` and `symbols`
frames no longer carry a bigger title than the frames beside them. It sits top-left in every
frame with **the same padding above and left**, which works because both come from one token in
one unit: `--frame-pad`, in `vw`. Two lengths in different units cannot be trusted to render
equal; the same length in the same unit always does.

Measured across all fifteen: ink starts 106/94 px (iPhone), ~150/138 (iPad), ~155/145 (Mac) from
the top and left edges. The few extra pixels on top are the half-leading above the cap line.

**A regression on the way there, worth recording:** unifying the title by deleting *all* the
per-target type overrides collapsed the body scale too, and the landscape sets came out uniformly
tiny. Only the title was ever meant to be uniform. The leads, chips, legend and promises keep
their per-target sizes.

### Why the Mac corners needed a mask rather than a radius

Clipping the frame to the window's corner radius never removed the desktop wedge cleanly, and the
reason is geometric: **a macOS window corner is a continuous curve, not a circular arc.** A circle
of the same nominal radius leaves slivers on one side or bites into the window on the other. No
value of `--screen-corner` fixes that.

The obvious alternative — flood-fill the dark wedge to transparent — worked on two captures and
destroyed the third. Measured luminance:

| | Desktop wedge | Window content at the corner |
|---|---|---|
| `01-archive`, `02-tagging` | 12–16 | 196–255 (sidebar, list) |
| `03-document` | 12–16 | **54–63** (the viewer's own chrome, touching the window edge) |

A fill wide enough to catch the wedge's anti-aliased rim walks straight through 54 into the app
and erases a block of it — which is exactly what happened, a rectangular hole at both right
corners.

**The fix is to stop discriminating on the hard image.** All three captures come from the same
pinned window at the same size, so the corner shape is identical. `clear-window-corners.swift`
picks the capture with the *lightest* corners, where 15-against-250 is unambiguous, builds one
alpha mask there — with a proportional ramp across the rim, so the curve stays smooth — and
applies that same mask to all three. The frame then carries `--screen-corner: 0`, a transparent
`.screen` and no device background, so the window's own rounding is what shapes the corner.

Generalises past this app: **when one input in a set is ambiguous and the others are not, derive
the decision from an easy one and apply it, instead of tuning a threshold until every case
passes.**

### Open

- A faint light-grey speck remains at the frames' top-left corner — a remnant of whatever was on
  the desktop there, above the mask's threshold. Raising the threshold removes it; the honest fix
  is a clean desktop behind the window at capture time.

### Correction: one width for all three iPhone device frames

Widening frame 3 to 84vw so its phone reached up *behind* the tags was wrong twice over: it broke
the set's single device width, and it put the tags on top of a half-blurred screen instead of on
the paper. All three device frames share `--hero-device-width` again, and the tags are what starts
the blur — the phone's top edge sits 246 px below them (chips end y=562, device starts y=809), so
the whole fade is visible underneath and nothing overlaps.

Measured across the set: 72.4vw in all three. Frames 1 and 5 read ~930-948 px against frame 3's
~955 px only because frame 3's mask clips the drop shadow, so its edge detector finds the bezel
itself rather than the shadow's ramp — the declared width is identical.

---

## Phase 3 · the pages became the source

The manifest pipeline was the wrong shape once the frames stopped being variations on one
template: every per-shot decision had to be written as a CSS string inside JSON, and each round
of client feedback made that worse. **The pages under `../frame-build/<locale>-<platform>/` are
now the source.** `build-all.sh` is gone — it regenerated them from the manifests and would erase
every hand edit.

```bash
open -a Safari ../frame-build/de-DE-iphone-6.9/3-tag.html   # edit, reload, repeat
./render.sh ../frame-build/de-DE-iphone-6.9/3-tag.html      # one page, ~1 s
./render.sh                                                  # all 30, then the index
./sync-css.sh ../frame-build/de-DE-iphone-6.9/frame.css      # push a shared change to the rest
```

Verified output-neutral: all 30 PNGs re-rendered **byte-identical** to the ones the manifest
pipeline produced, before and after the switch.

### Each page says where it belongs

`render.sh` holds no table of sets, because a table beside the files is a second thing to keep in
step. The pages carry it:

```html
<meta name="frame-size" content="1320x2868">
<meta name="frame-out"  content="de-DE/iphone-6.9">
```

`plan.json` — what the overview checks completeness against — is derived from those, so a set
cannot be measured against a size it no longer renders at.

### The one cost, and how it is contained

The renderer refuses a stylesheet linked outside the page's own directory, so **`frame.css` now
exists six times**, once per set. `render.sh` compares them and names the ones that differ; it
never resolves the difference itself, because the copy you just edited is the one that should win
and only you know which that is. `sync-css.sh <the one you edited>` propagates it, `source/frame.css`
included, so a re-scaffold would start from the current design rather than resurrecting an old one.

### What is left of the old pipeline, and when it bites

`frames*.json`, `frame.html` and `derive-manifests.py` stay as the record of how each set was laid
out. They are **not** wired into anything. Running `derive-manifests.py` alone is harmless — it only
writes JSON — but following it with `build-frames.sh` overwrites every page. Do that only to
scaffold a set from scratch, and expect to lose hand edits in it.

**When the app is re-captured**, the pages do not update themselves: each set directory holds its
own copy of the captures it embeds, so the new files have to be copied in. The Mac captures need
no preparation — the desktop wedge in the window corners is clipped away in CSS
(`--screen-corner`), which replaced a script that used to mask it into the PNG.

---

## Phase 3, cleaned up · the tree that ships

The staging copies are gone: there was a `frame-build/` of pages, a `framed/` of renders and a
`final/` holding a copy of both. One source, one output now.

```
assets/screenshots/
  de-DE/ en-US/                      the raw captures the UI tests write (input, never edited here)
  appstore/<locale>/<platform>/      the rendered PNGs that go to App Store Connect
  source/index.html                  the overview — HTML/Bild switch, locale filter
  source/pages/<locale>-<platform>/  THE SOURCE: the design HTML, its frame.css, its captures
  source/                            render.sh · sync-css.sh · these notes
```

Retired with the manifests: `frames*.json`, `frame.html`, `derive-manifests.py`,
`clear-window-corners.swift` and the `.mac-captures/` staging directory. `build-index.sh` locates
the page directories by name, so it now accepts `pages` as well as `frame-build`.

## The bug that made every design look wrong, and why nothing caught it

`render-frame.swift` cancelled the Retina backing scale with `pageZoom = 1 / scale`. Under a page
zoom, **WebKit resolves viewport units inside `font-size` against the UNZOOMED viewport.**
Measured in one page on an 1800 px canvas:

| Declaration | Expected | Rendered |
|-------------|----------|----------|
| box `height: 180px` | 180 px | 180 px |
| text `font-size: 180px` | 130 px cap | 130 px cap |
| text `font-size: 10vh` (= 180 px) | 130 px cap | **65 px cap** |

Every box was right, so the devices sat exactly where the design put them — and every type size
written in `vh`, which is all of them, came out at half scale. The gates check the viewport size,
the output size and the alpha channel; none of them looks at type, so it shipped silently through
every render in this project.

The fix is to stop zooming: the view is the target size in points and
`WKSnapshotConfiguration.snapshotWidth` brings the capture back down. `devicePixelRatio` is 2 by
design now, so that assertion went — the viewport-size and output-size guards together still prove
one CSS px equals one output pixel.

**The lesson worth keeping: a render gate that checks dimensions is not checking the design.** The
client caught this by comparing the page in the browser against the PNG, which is the one
comparison the pipeline never made.
