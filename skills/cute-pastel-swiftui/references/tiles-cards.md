# Cards, list rows and the tile grid

Three flat surfaces on the canvas. None of them is ever material, glass or
blurred, and none of them carries a gradient — the canvas owns the screen's one
gradient.

## `CardButtonStyle` and `PressableCard`

Press feedback lives in a `ButtonStyle`. A `DragGesture` "press" blocks the
enclosing `ScrollView`'s pan and its pressed state sticks when the scroll steals
the touch — a card that stays shrunk after a flick is that bug.

```swift
import SwiftUI

struct PressableCard<Content: View>: View {
    let fill: Color
    let onTap: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12, content: content)
        }
        .buttonStyle(CardButtonStyle(fill: fill))
    }
}

private struct CardButtonStyle: ButtonStyle {
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: .rect(cornerRadius: 20))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .contentShape(.rect(cornerRadius: 20))
    }
}
```

Exact values: radius 20, inner padding 18, shadow **`black 6 %, radius 6,
y 2`**, press scale 0.97 (chips use 0.96), spring `0.3 / 0.7`.

The 6 % shadow is a ceiling, not a starting point. Above ~8 % the shadow greys
the pastel and the whole screen goes muddy — the surfaces are meant to float a
millimetre, not hover. Never tint the card shadow; the accent-tinted glow is
reserved for the FAB.

`.background(fill, in: .rect(cornerRadius: 20))` and
`.clipShape(.rect(cornerRadius:))` rather than `RoundedRectangle(cornerRadius:)`
— shorter, and it is the modern shape API.

`fill` is `Palette.surface` for a neutral card, or the section's feature fill
(`Palette.tasks`, `Palette.meals`, …) for a category card. Never
`Palette.accent`: a card-sized accent fill is 30–60 % of the visible surface on
its own and forces body text onto a colour that clears only 3:1.

## `pastelRow(_:)`

A `List` row is a flat card too: radius 16, no separator, 10 pt between rows
(the spacing comes from `flatListStyle()` — see `canvas.md`).

```swift
extension View {
    /// Flat pastel backing for a list row, matching the card look one step down.
    func pastelRow(_ fill: Color) -> some View {
        self
            .listRowSeparator(.hidden)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 16).fill(fill)
            )
    }
}
```

Call site:

```swift
List {
    ForEach(store.tasks) { task in
        NavigationLink(value: task) { TaskRow(task: task) }
            .pastelRow(Palette.tasks)
    }
}
.flatListStyle()
```

`listRowBackground` takes a shape view, so this is the one place a
`RoundedRectangle` is spelled out — `.rect(cornerRadius:)` is a
`ShapeStyle`-consuming form and does not fit here.

Do not also apply `.background()` inside the row: you get two stacked
rectangles whose corners disagree by a pixel.

## `Tile` and `TileGrid`

A tile is a 64 pt filled circle with a 26 pt glyph, then 8 pt, then a centred
label of up to two lines. The circle's radius *is* 32 because the circle is 64 —
there is no separate corner radius to set.

```swift
/// A single pastel tile: a filled circle icon over a centred label.
struct Tile: View {
    let title: String
    let systemImage: String
    let fill: Color

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(fill)
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: 26))
                        .foregroundStyle(Palette.ink)
                }
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A 3-column pastel grid. 16 pt spacing on both axes.
struct TileGrid<Content: View>: View {
    @ViewBuilder let content: () -> Content

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            content()
        }
    }
}
```

`.flexible()` columns, not `.adaptive(minimum:)`: three columns is the layout,
and adaptive silently becomes four on a Plus/Max and two at large Dynamic Type.
`frame(maxWidth: .infinity)` on the tile makes each cell share the width evenly
so the circles line up on a grid.

The glyph is decorative — `children: .combine` folds it into one element whose
accessible name is the title, which is exactly what you want. Do not add
`.accessibilityHidden(true)` to the `Image` as well; `.combine` has already
absorbed it.

## Making a tile tappable

Wrap it, don't restyle it: the tile is the label of a `Button` or
`NavigationLink`, so the whole circle-plus-label is one target.

```swift
ScrollView {
    TileGrid {
        ForEach(HubDestination.allCases) { dest in
            NavigationLink(value: dest) {
                Tile(title: dest.title, systemImage: dest.systemImage, fill: dest.fill)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(dest.title)
        }
    }
    .padding(16)
}
.gradientCanvas()
```

- `.buttonStyle(.plain)` stops the link tinting the label blue. Add
  `CardButtonStyle`-style press scaling only if you want it; `.plain` alone
  gives no press feedback, so for a grid that should answer the finger use a
  dedicated tile button style with scale 0.97.
- **`.accessibilityLabel(dest.title)` is what makes the tile addressable in UI
  tests** as `app.buttons["Tasks"]`. Without it the button's name comes from the
  combined child element and is easy to break by changing the glyph.
- `.padding(16)` is the screen gutter, applied once to the grid.
- The grid sits inside a `ScrollView` on the canvas. In the reference look the
  grid lives inside a white card; on a `List`-free hub screen, directly on the
  canvas with the gutter is the accepted variant.

## Which surface for what

| Content | Surface | Radius | Fill |
|---|---|---|---|
| A dashboard block with several lines | `PressableCard` | 20 | feature fill or `surface` |
| One row in a list | `pastelRow(_:)` | 16 | feature fill or `surface` |
| A destination in a hub | `Tile` in `TileGrid` | 64 pt circle | feature fill |
| Anything that must stand out more | promote to a **gradient card** (max two per screen, one shared `promoGradient` pair) | 20 | `promoGradientStart → End`, text in `promoInk` |

Standing out is never achieved by adding a gradient to a plain card, tinting it
with the accent, or blurring it. Those are the three asks to refuse; the
gradient-card promotion is the alternative to offer.
