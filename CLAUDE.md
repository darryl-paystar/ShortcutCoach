# Shortcut Coach

A macOS menu-bar app (SwiftUI + AppKit, macOS 15+) that coaches keyboard shortcuts, written mainly for people switching from Windows. Build, install and self-test commands are in `README.md`.

## Design system

Before any UI or copy work, read the brand book of the design system at https://claude.ai/artifact/Ru9bXkcR7LEcqvk1uLRhGN: Artifact tool, `action: "read"`, `path: "project/README.md"`. A component's spec is at `project/components/<Name>/README.md`. It's the single source of truth for tokens, copy and components; the rules below are its Swift-level summary, enough to work from when the page can't be read.

The feel is polished, clean and professional, never monotone: native, quiet chrome, with color spent only where it has a job.

**Surfaces**
- A scrolling main-window section is a `ScrollView` or `Form` with `.sectionGround()` (content ground + a fade under the toolbar). Content sits in `GroupedBox` (lists) or `Card` (free-form), each under a `SectionLabel`. Page padding is 24, sections are 24 apart, and a label sits 10 above its box.
- The main window's title bar stays transparent (`App.swift`); the fade keeps content clear of the title.
- Floating panels use `.glassCard(cornerRadius:)` with a shadow. Shadows belong to floating glass only.

**Color**
- Views use system colors (`Color(nsColor:)`, `.primary`, `.secondary`, `.blue`…). Custom colors live in `UI/Brand.swift`.
- Color carries meaning: green is progress, orange is a Windows habit or a warning, yellow is a tip, always alongside a symbol and words. Red only mirrors the red window button.
- Each section and category owns one hue and SF Symbol: `MainSection.color` / `tileSymbol`, `CheatSheets.style`, `TipStyle`. A new section gets its own hue there.
- `brandWash`, `brandIndigo`, `brandSpark` and `LearnedIcon` are for moments only: the onboarding welcome, "Shortcut learned", empty states.

**Keys and controls**
- Every Mac shortcut renders as `KeycapRow`: size 14 in toasts, 13 by default, 12 in lists, 10 in the overlay, 22 for hero moments. Modifiers go in ⌃⌥⇧⌘ order. A Windows shortcut is text ("Ctrl+C") in the blue monospaced chip (`WindowsKeys` in `LearnViews.swift`).
- Section icons are `IconTile`; hint icons are `HintIcon`. Icons are SF Symbols.
- A toolbar control with state is a hairline pill like `CoachingPill` (system glass hidden with `.sharedBackgroundVisibility(.hidden)`), and its shortcut also gets a main-menu item. Plain toolbar buttons keep the system glass.
- Controls are native (`Button`, `Toggle`, `Picker`, `Menu`) in system styles, with at most one `.borderedProminent` per view.

**Copy**
- Second person, plain and encouraging; warmth comes from the em dash, never exclamation marks. Title Case for buttons and menu commands, sentence case everywhere else. `→` for menu paths, `·` between metadata, `×` for counts, `…` on commands that open more UI.

**Keeping it in sync**
When a change sets a new pattern (a color, component, layout or copy rule), update the design system in the same task: read and edit its files under `project/` (`tokens.json`, `README.md`, `components/<Name>/`) as its `SKILL.md` describes, then republish to the same URL.

**Checking UI**
`--selftest` renders previews with `ImageRenderer`, which draws AppKit-backed controls (switches, link buttons, menus) as yellow 🚫 placeholders and the app icon as a folder. That's expected. Judge layout in the running app.

## Releases and versioning

Before touching versions, signing or the release workflow, read `README.md` → Releases. On every change:
- A push to `main` that changes the app is a release: colleagues' installed copies offer it within the hour. Work in progress stays on a branch until it's ready to ship.
- The version comes from the commit count, so a change needs no version edit. Docs-only commits count but don't release, so release numbers skip, which is expected. `Info.plist`'s major.minor changes only for a deliberate version jump.
- `main` only grows: land work as new commits (merge or fast-forward). The commit count is the build number Sparkle compares, so a rewritten history would hide updates from installed copies.
