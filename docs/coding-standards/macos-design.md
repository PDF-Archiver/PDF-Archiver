
# macOS Design — Layout Metrics, Window Chrome, Mac Interaction

A Mac app is not an iOS app with a pointer. It owes the user a full menu bar, resizable windows, keyboard parity, and a layout built on **center equalization** rather than a touch grid. This file carries the concrete numbers and the rules that iOS habits get wrong.

Sources: Mario Guzman's Mac design guidelines (layout, toolbar, sidebar, inspector) and the `platform-design-skills` macOS HIG ruleset — both linked at the bottom. Where they disagree on spacing, the metrics below win: they are AppKit's actual layout values.

## The iOS reflexes that break on Mac

- **There is no 8-point grid.** Mac spacing is `6` between stacked controls, `12` between groups, `20` at window margins. Applying an 8pt rhythm produces a layout that is subtly wrong everywhere.
- **Controls are compact** (roughly 22–28 pt tall), because the pointer is precise. Touch-sized buttons read as a lazy port.
- **No hamburger menu, no bottom tab bar, no floating action button.** The menu bar is the command surface, the sidebar is the navigation surface, the toolbar holds frequent actions.
- **Never sheet-by-default.** Sheets are for multi-step or consequential flows; use popovers, inspectors, or inline editing for everything else.
- **A fixed or non-resizable window is a bug.** So is a custom title bar that hides the traffic lights.

## Layout metrics

`20` and `6` carry most layouts. Consistency outranks the exact value: a reader never notices an 18-point margin, but always notices a left margin wider than the right.

### Regular-size controls (the default — start here)

| Distance | Value |
|---|---|
| Left / right / bottom window margin | 20 |
| Titlebar or toolbar → first control (not in a group box or tab view) | 14 |
| Label colon → its stacked control | 6 |
| Between stacked controls | 6 minimum |
| Above and below a separator | +12 (on top of the 6) |
| Extra separation inside a group (e.g. checkbox under a radio group) | +8 (on top of the 6) |
| Bottom control group → button row | 12 |

Tab views: `12` from the top of the tab view to the titlebar/toolbar, `20` window margins, and at least `16` inside a group box and between controls and the tab-view edge. Always center a tab view in its window.

### Small and mini controls

Reach for these **only** where space is genuinely at a premium — tool palettes, toolbar accessory views, HUDs, inspector sidebars, utility windows. Never mix control sizes in one window or pane.

| Distance | Small | Mini |
|---|---|---|
| Window margins | 20 (10 when using group boxes) | 10 left/top/right, 14 bottom |
| Titlebar/toolbar → first control | 14 | — |
| Between sections | 12 | 12 (last control → next section title) |
| Section title → first control | 8 | 8 |
| Between related checkboxes / radio groups | 6 | 4 |
| Slider: title → slider, and below its labels | 4 | — |

Both examples use a **bold label per section** instead of separators or group boxes, which is how they buy the space back.

### Grouping — pick one and stay with it

- **White space**: `12`–`24` between groups, `12` minimum. Best for small groups.
- **Separators**: equal spacing above and below, `12` for regular controls, less for small/mini. Preferred when space is tight.
- **Group boxes**: `16` margin top and bottom inside the box, at least `16` left and right. The strongest visual separation and the most expensive in space; the box title takes over the section name, so rename controls to kill the redundancy.

### Bottom button row

`12` above, `20` left/bottom/right. Help button always bottom-left. The confirmation button sits **to the right of Cancel**, matches its width (longer only if it must), and fires on Return.

### Bottom bars

A window-frame strip below the body, holding controls that act on the content directly above it — frequently used, but less important than the toolbar. Use a **recessed, momentary-push-in** button so it highlights on hover like a toolbar item. All controls vertically centered; labels in Secondary Label Color.

| | Large | Small |
|---|---|---|
| Bar height (including separator) | 32 | 22 |
| Control size | Regular | Mini |
| Button size | 31 × 18 | ≥ 25 × 14 |
| Space to leading/trailing edge | 8 | 6 |
| Between buttons | 1 | 1 |

For mini bars, prefer the `fill` variant of a symbol — it stays legible at that size.

## Center equalization and alignment

**Center equalization is visual balance, not center justification**: the visual weight left and right of the window's invisible center axis matches. A label column on the left balances a denser control column on the right. It applies to windows, panes, and the inside of group boxes.

- Section labels **right-aligned** (their colons line up); their stacked controls **left-aligned**.
- Checkboxes and radio buttons left-aligned to each other.
- **First-baseline align every element in a row**, so label text lines up with pop-up button and combo-box text. Pop-up buttons, text fields, pickers, and combo boxes are taller than checkboxes — give them extra room when stacking.
- Similar controls get **equal widths even across different group boxes**.
- A control that depends on another's state goes below it, indented so its leading edge aligns with the parent's text label.
- Alignment carries across group boxes: the section titles of one box align with the next.

**Optional description labels** under a control (when the control's own label cannot say enough): small-size, multi-line, Secondary Label Color, `4` below the control. Left-aligned with the control — except under a checkbox or radio button, where it aligns with the control's *title*, so indent at least `14`.

## Windows

- Freely resizable with a sensible minimum; a maximum only when the content truly cannot scale.
- Opt into native fullscreen and Split View (`.fullScreenPrimary`).
- Support multiple windows unless the app is a genuine single-purpose utility; document-based apps use `DocumentGroup` and allow many documents at once.
- Document windows show the document name, the proxy icon (draggable), and the edited dot — `representedURL`, `title`, `isDocumentEdited`.
- Persist frame and state across launches (`setFrameAutosaveName`, or SwiftUI scene restoration).
- Traffic lights stay top-left, visible, functional — including under `titlebarAppearsTransparent` + `.fullSizeContentView`.

## Menu bar and keyboard

The menu bar is where a user looks for a command they cannot find. Every toolbar item must also exist as a menu command; the reverse does not hold.

- Standard menus: **App, File, Edit, View, Window, Help** (File only if document-based). App-specific menus go between Edit and View, or View and Window. Never rename or drop the standard App-menu items (About, Settings ⌘, Services, Hide, Quit).
- **Every action reachable by mouse needs a key equivalent.** ⌘+letter for primary, ⌘⇧ for a variant, ⌘⌥ for an alternative mode, ⌘⌃ for window/view controls.
- Menu items track state: disable what does not apply, retitle for context ("Undo Typing", "Delete 3 Items"), check what is toggled. AppKit does this in `validateMenuItem(_:)`.
- Esc cancels and dismisses (popover, sheet, dialog, in-progress operation; reverts a text field). Return fires the default button — `.keyboardShortcut(.defaultAction)` / `.cancelAction`.
- Delete removes the selection, ⌘Delete for the destructive variant, and **⌘Z undoes it**. Space invokes Quick Look. Arrows move selection; left/right collapse/expand or change column; ⌘↑/⌘↓ jump to the ends. Tab and ⇧Tab reach every control — no keyboard traps.
- ⌘-click extends a non-contiguous selection, ⇧-click a range. Right-click opens a contextual menu on **every** interactive element.
- Sidebar toggling has **no HIG-standard shortcut** — ⌘⌃S is common but not reserved. Pick one and put "Show/Hide Sidebar" in the View menu.

## Toolbar

Only frequent actions, and only in the **default** set — the user adds the rest. Order items by the user's mental model: highest-visibility first (leading), grouped by task, ranked inside each group. Items enable and disable with the First Responder.

- **Anchored ends, never a moving target.** The sidebar toggle is pinned leading, the inspector toggle trailing. Expanding either column pushes the *other* items inward; a toggle that slides with it makes the user chase it. Trailing order, outermost first: **inspector toggle → Share → global Search** (Search expands into a field, so it cannot be outermost).
- **The sidebar's toolbar section holds at most two items** — realistically just the sidebar toggle. A narrow sidebar pushes the rest into the overflow menu, where they vanish. Sidebar-specific actions belong in the sidebar's **bottom bar** instead, where they cannot be hidden.
- Overflow order: **lowest `visibilityPriority` goes first regardless of position**, then remaining items right-to-left.
- Centered items (`centeredItemIdentifiers`) are for one special control — a view picker, an address bar, a now-playing view. `NSToolbarItemGroup` renders as a segmented control and collapses to a pop-up when space runs out.
- A title/subtitle is optional and costs item space; use it for the current section and its context (mailbox name + message count), never the app name.
- Styles: **Unified** (or Unified Compact) is the default for most apps; **Expanded** for document-based apps; **Preference** for Settings windows.
- Use the built-ins rather than rebuilding them — `.toggleSidebar`, `.sidebarTrackingSeparator`, `.toggleInspector`, `.inspectorTrackingSeparator`, `.cloudSharing`, `.writingToolsItemIdentifier`, `NSSharingServicePickerToolbarItem`, `NSSearchToolbarItem`, `NSMenuToolbarItem`, `NSToolbarItemGroup`, `NSTrackingSeparatorToolbarItem`. They arrive with the right icon, title, localization, and action. (SDK-before-hand-rolled, applied to chrome.)
- Toolbar items carry an icon *and* a label (`Label`); labels are what make them discoverable.
- An **accessory bar** (`NSTitlebarAccessoryViewController`) is the secondary surface: content-scoped controls only, no global ones. It spans the content columns but not the sidebar or inspector.

## Sidebar (source list)

Navigation for "shoebox" apps — the user picks an item, the detail view shows it. It abstracts the file system away (libraries and playlists, not paths); document-based apps rarely need one.

- Width: **min 225–275, max 350–400**. Needing no maximum is a sign the layout is wrong.
- **At most two levels of hierarchy.** Deeper data gets a second source list between sidebar and detail (as in Notes), or a browser view for deeply nested objects.
- Section headers are optional but fine for distinguishing logical groups ("Folders").
- Bottom bar for sidebar-scoped actions: add, remove, edit, get info, refresh, sync status — `NSSplitViewItemAccessoryViewController` / `addBottomAlignedAccessoryViewController(_:)` in AppKit, `tabViewSidebarBottomBar(content:)` or `safeAreaBar(edge:alignment:spacing:content:)` in SwiftUI.
- Contextual menus carry the actions that matter but do not earn a bottom-bar button; put important ones in **both**.
- Add a search field when the list can get long. Let the user customize the contents.
- **macOS 26 (Tahoe): sidebar icons tint black in light mode, white in dark** — no longer the app's accent color, because the translucent glass sidebar now floats over the content and tinted icons clash with it.
- Respect the system sidebar icon size (Small/Medium/Large) by using standard API behavior. In AppKit set `allowsExpansionToolTips` so a truncated row reveals itself on hover (SwiftUI needs an `NSViewRepresentable` wrapper for that).

```swift
// Sidebar and inspector both need a clamped width; the ideal is what the user first sees.
NavigationSplitView {
    SidebarList()
        .navigationSplitViewColumnWidth(min: 250, ideal: 260, max: 375)
} detail: {
    DetailView()
}
```

## Inspector

Auxiliary metadata or controls for the current selection, shown or hidden by the user. Contextual and dynamic: content updates, enables, or hides the moment selection or focus changes.

- **Sidebar is the modern form** — slides in from the trailing edge, part of the main window. A floating **panel** becomes key while the app stays main, and closes on Esc.
- Same widths as a sidebar: min 225–275, max 350–400.
- Group content in collapsible disclosure sections, tabs, or both — so the user can remember the way back to a control. Inspectors use the **small control size**, densely packed.
- A menu-bar item must open it; a sidebar inspector also needs its toolbar toggle.
- Panel title: the selected tab's name, otherwise just "Inspector". Disable the minimize button.
- Never say "panel" in the UI — "Show Inspector", or "Show Inspector Window".
- HUD style (dark, translucent, small white/gray controls) only when the app is media-centric, lives in a dark or immersive environment, or a standard panel would cover what the user is adjusting. One inspector keeps one style; never switch by mode.

## Visual design

- System font at semantic sizes (`.title`, `.headline`, `.body`, `.caption`), SF Mono for code. Never hardcode point sizes.
- System materials for sidebar and toolbar surfaces (`.listStyle(.sidebar)`, `NSVisualEffectView` with `.sidebar` / `.behindWindow`) — vibrancy is what anchors a window to the Mac.
- **Respect the system accent color.** Do not force a brand color onto standard controls.
- Semantic colors only (`.primary`, `.secondary`, `windowBackgroundColor`, `controlBackgroundColor`), so Light and Dark both work. Never `Color.white` / `.black` for a surface. Test both appearances.

## Accessibility

- Every icon-only button and toolbar item gets an `accessibilityLabel` — "trash" alone is meaningless to VoiceOver.
- Full keyboard access: everything the mouse can do, the keyboard can do; logical VoiceOver traversal order (fix divergence with `accessibilitySortPriority` / `accessibilityElement(children:)`).
- Honour **Reduce Motion** (drop decorative animation), **Reduce Transparency** (solid background instead of the material), **Bold Text** (`\.legibilityWeight` for custom rendering), and **Increase Contrast** (`\.colorSchemeContrast`, or `accessibilityDisplayShouldIncreaseContrast`).

```swift
struct SidebarBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        // Reduce Transparency must replace the material outright — dimming it is not enough.
        if reduceTransparency {
            Color(nsColor: .windowBackgroundColor)
        } else {
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}
```

- Hover state on every interactive element, and a cursor that names the affordance (I-beam, crosshair, resize, grab).
- Drag and drop both ways: reorder, move between containers, accept Finder drops, export content.

## System integration

Dock icon at 1024×1024 plus a Dock menu with recent documents; Core Spotlight indexing for app content; Quick Look previews for custom file types; the Share menu (`ShareLink`) in both directions; the Services menu; App Intents for Shortcuts, and an `.sdef` where AppleScript support matters.

Notify only for events the user must know about from outside the app, and make it actionable. Success gets inline status, not an alert; modal alerts are for stopping the user before something consequential. Recurring alerts carry a suppression checkbox (`showsSuppressionButton`) and the choice is persisted. Clear the Dock badge as soon as it is addressed.

## Review checklist

- [ ] Margins `20`, control spacing `6`, groups `12`–`24` — and the same on both sides
- [ ] Center-equalized; labels right-aligned, controls left-aligned, rows first-baseline aligned
- [ ] Regular control size, unless the pane is a palette / inspector / HUD — and no mixing
- [ ] Complete menu bar; every action has a shortcut; items enable/disable and retitle
- [ ] Window resizable, minimum set, frame restored, traffic lights untouched
- [ ] Sidebar and inspector toggles anchored; trailing order inspector → Share → Search
- [ ] Sidebar ≤ 2 hierarchy levels, width clamped, its actions in the bottom bar
- [ ] ⌘Z undoes every destructive action; Esc dismisses; Space previews; Delete removes
- [ ] Hover states, contextual menus, drag and drop, ⌘/⇧-click multi-selection
- [ ] Dark Mode, system accent, semantic colors, materials
- [ ] VoiceOver labels; Reduce Motion / Reduce Transparency / Bold Text / Increase Contrast honoured

## Sources

- [Mac Design Guidelines — Mario Guzman](https://marioaguzman.github.io/design/): [Layout](https://marioaguzman.github.io/design/layoutguidelines/), [Toolbar](https://marioaguzman.github.io/design/toolbarguidelines/), [Sidebar](https://marioaguzman.github.io/design/sidebarguidelines/), [Inspector](https://marioaguzman.github.io/design/inspectorguidelines/) — every metric above
- [platform-design-skills / macOS](https://github.com/ehmo/platform-design-skills/blob/main/skills/macos/SKILL.md) — menu bar, keyboard, accessibility, anti-patterns
- [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/) — the authority when either source is stale
