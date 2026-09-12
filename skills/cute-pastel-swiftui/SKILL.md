---
name: cute-pastel-swiftui
description: Use when building or restyling a SwiftUI or WidgetKit screen in the cute-pastel look — gradient canvas behind a List or Form, huge animated hero numeral, wrapping pill chip pickers, floating action button over a TabView, pastel tile grid, pressable pastel cards — or when a SwiftUI project needs pastel Palette colour tokens, contrast tests for them, or a spring press style for cards and chips.
---

# Cute Pastel — SwiftUI

SwiftUI recipes only. **Tokens, metrics and the five rules live in
`cute-pastel-style` — read it first.** Colours here are named roles (`accent`,
`chipFill`, `surface`); values live in its `references/tokens.md`.

## Targets

iOS 17+: `contentTransition(.numericText())`,
`scrollContentBackground(.hidden)`, `containerBackground(_:for:)`, `Layout`.
Swift 6, `MainActor` default isolation. iOS 26 `Tab`/glass-bar: `navigation.md`.

## Adoption order

1. `Palette` + contrast test
2. `gradientCanvas()` + `flatListStyle()`
3. Cards and list rows
4. `Chip` / `ChipGroup`
5. `HeroHeader`
6. Tab bar + FAB
7. `Tile` / `TileGrid`

See the File map.

## File map

One canonical type per job, all in `references/`.

| Need | Reference | Types |
|---|---|---|
| Tokens, dark mode, contrast | `palette.md` | `nonisolated enum Palette`, contrast suite |
| Gradient behind list or widget | `canvas.md` | `GradientCanvas`, `gradientCanvas()`, `flatListStyle()` |
| Animated numeral | `hero.md` | `HeroHeader(label:value:unit:subline:)` |
| Pill chip picker | `chips.md` | `Chip`, `ChipButtonStyle`, `ChipGroup`, `FlowLayout` |
| FAB over a tab bar | `navigation.md` | `FloatingActionButton`, overlay recipe |
| Cards, rows, tile grid | `tiles-cards.md` | `CardButtonStyle`, `pastelRow(_:)`, `Tile`, `TileGrid` |

Extend these: a twin `FlowLayout`, or a `pastelBackground()` beside
`gradientCanvas()`, is the failure this skill prevents.

## Rules that bite

- **The gradient is two modifiers, always both:** `.ignoresSafeArea()` on the
  gradient *and* `.scrollContentBackground(.hidden)` on the `List`/`Form`.
  Either alone ships a grey list; `flatListStyle()` applies both.
- **Press feedback is a `ButtonStyle`, never a `DragGesture`** — a gesture
  blocks the enclosing `ScrollView`'s pan and sticks on scroll-steal.
- **`Palette`, `GradientCanvas` and every `Layout` conformer are
  `nonisolated`** — widgets and `Layout` run off the main actor and cannot read
  a `@MainActor` enum.
- **A selected chip keeps its fill** and gains a 2 pt `accent` stroke plus a
  14 pt check badge. Swapping the fill deletes the category.
- **Chips need `.accessibilityAddTraits(.isSelected)`** — a selected `Button`
  announces nothing.
- **No colour at a call site:** no hex, no `Color(red:green:blue:)`, no
  `someToken.opacity(0.18)` — a token's opacity is still an invented colour.
