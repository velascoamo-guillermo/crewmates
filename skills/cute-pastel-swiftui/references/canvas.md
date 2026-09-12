# Gradient canvas

One soft vertical gradient owns the screen. It is the only gradient the screen
gets (the two gradient-card variants excepted — see
`cute-pastel-style/references/components.md`).

## The type and the modifier

Three stops, vertical, locations 0 / 0.45 / 1 — which is what
`LinearGradient(colors:startPoint:endPoint:)` gives you for three colours.
Two stops read as a flat wash, four as a rainbow.

`nonisolated` so the widget extension can use the same fill.

```swift
import SwiftUI

nonisolated enum GradientCanvas {
    static var fill: LinearGradient {
        LinearGradient(colors: [Palette.canvasTop, Palette.canvasMid, Palette.canvasBottom],
                       startPoint: .top, endPoint: .bottom)
    }
}

extension View {
    /// The canvas behind any screen. `ignoresSafeArea` is on the gradient, not
    /// on the content, so content keeps its insets while the wash reaches the
    /// screen edges and stays put under a navigation bar or sheet.
    func gradientCanvas() -> some View {
        background(GradientCanvas.fill.ignoresSafeArea())
    }
}
```

`GradientCanvas.fill` is a computed property, not a `let`: `Palette`'s colours
are dynamic `UIColor`s and must resolve against the *current* trait collection
each time the view body runs.

## Pairing it with `List` and `Form`

A `List`/`Form` paints its own opaque `systemGroupedBackground` **over**
whatever is behind it. So the canvas needs two modifiers, and shipping one
without the other is the single most common failure here:

1. `.scrollContentBackground(.hidden)` on the `List`/`Form` — makes the list's
   own chrome transparent.
2. `.gradientCanvas()` — puts the wash behind it.

Never expose those as two modifiers a call site has to remember. Ship one:

```swift
extension View {
    /// Inset-grouped list over the app canvas, with inter-row spacing so rows
    /// read as separate flat cards rather than one slab.
    func flatListStyle() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listRowSpacing(10)
            .gradientCanvas()
    }
}
```

Call site — the whole change to an existing `List`-based screen:

```swift
List {
    ForEach(items) { item in
        ItemRow(item: item)
            .pastelRow(Palette.tasks)   // see tiles-cards.md
    }
}
.flatListStyle()
.navigationTitle("Tasks")
```

`Form` is the same story: `.scrollContentBackground(.hidden)` plus
`.gradientCanvas()`. A `Form` inside a sheet gets the canvas too — the sheet
reuses the screen's wash and does not introduce a second gradient.

For a `ScrollView`-based screen there is no chrome to hide; `.gradientCanvas()`
alone is enough.

## Diagnosing "the gradient isn't showing"

| Symptom | Cause | Fix |
|---|---|---|
| List/Form still grey | `.scrollContentBackground(.hidden)` missing | use `flatListStyle()` |
| Gradient stops at the safe area | `ignoresSafeArea()` applied to the content instead of the gradient | keep it inside `gradientCanvas()` |
| Rows are opaque white slabs | default row background | `pastelRow(_:)` per row |
| Gradient visible but flat | two stops | three stops, `Palette.canvasTop/Mid/Bottom` |
| Gradient runs corner to corner | `.topLeading → .bottomTrailing` | `.top → .bottom` |

## Widget

From iOS 17 a widget's root `.background()` is ignored — WidgetKit requires the
container API, and the same three stops go through it:

```swift
struct HomeWidget: Widget {
    let kind = "HomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            HomeWidgetEntryView(entry: entry)
                .containerBackground(GradientCanvas.fill, for: .widget)
        }
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
```

This is the reason `Palette` and `GradientCanvas` are `nonisolated`: the widget
extension is a separate target with its own isolation, and it shares these two
files. Text inside the widget uses `Palette.ink` / `Palette.inkSecondary`, same
as the app.

## Flat fallback

Where the wash cannot run — a `.systemSmall` widget, a Live Activity, a
Watch complication, a printable export — drop to the flat `canvasBottom`
(the near-white stop), never to a system grey and never to a two-stop
approximation:

```swift
.containerBackground(Palette.canvasBottom, for: .widget)
```

**Never** reach for `.regularMaterial`, `.ultraThinMaterial`, `.blur()` or a
`backdropFilter` equivalent on top of the canvas. The wash is already the soft
layer; blurring it samples and smears the gradient, and costs GPU to look worse.
