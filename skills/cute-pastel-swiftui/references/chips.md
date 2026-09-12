# Chips and chip groups

A pill chip carries a **category fill** and, when selected, gains an accent
stroke and a check badge. The fill never changes — it is what encodes the
category, and overwriting it on selection deletes that information exactly when
the user is acting on it (and blows the accent budget once several are
selected).

Use a chip group wherever a segmented `Picker` would truncate, scroll or wrap
badly: 3+ options, or any option whose label is longer than one short word.

## `Chip`

```swift
import SwiftUI

struct Chip: View {
    let title: String
    var systemImage: String? = nil
    let fill: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.accent)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(ChipButtonStyle(fill: fill, isSelected: isSelected))
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
```

The badge is `.accessibilityHidden(true)` because the `.isSelected` trait is
what conveys selection to VoiceOver; announcing a checkmark image as well reads
the state twice. Conversely, **without** `.isSelected` a selected chip announces
nothing at all — a `Button` has no notion of being chosen.

The glyph *leads* the label. An icon-only chip is not available in this
language: the glyph set is playful and ambiguous, and the label is what makes it
usable and what a screen reader gets.

## `ChipButtonStyle`

```swift
private struct ChipButtonStyle: ButtonStyle {
    let fill: Color
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(fill, in: .capsule)
            .overlay {
                if isSelected {
                    Capsule().stroke(Palette.accent, lineWidth: 2)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .contentShape(.capsule)
    }
}
```

Exact values, not ranges: h14 / v9 padding, 2 pt stroke, 14 pt badge, press
scale **0.96** (cards and rows use 0.97), spring `response 0.3,
dampingFraction 0.7`.

Press feedback is a `ButtonStyle`, never a `DragGesture`: a gesture competes
with the enclosing `ScrollView`'s pan, and its pressed state sticks when the
scroll steals the touch. `.contentShape(.capsule)` keeps the hit area on the
pill rather than its bounding box.

There is **no** `.animation(_:value: isSelected)` here, because the fill does
not change on selection. The stroke and badge appear on the same spring as the
press.

`fill` is always a category role (`Palette.tasks`, `Palette.pets`, …), never
`Palette.accent` and never `someToken.opacity(0.18)`. If a group has no
category, pass the one fill that suits the screen's section — not the accent.

## `ChipGroup`

Two initialisers, differing only in selection semantics. Both take the same
closure-based `title` / `systemImage` so any model works without conforming to
a presentation protocol.

- `Binding<Item>` — exactly one always selected; re-tapping the selected chip is
  a **no-op**. This is the `Picker` replacement.
- `Binding<Item?>` — re-tapping the selected chip **deselects** it. This is the
  filter case.

```swift
struct ChipGroup<Item: Identifiable & Hashable>: View {
    let items: [Item]
    private let fill: Color
    private let title: (Item) -> String
    private let systemImage: (Item) -> String?
    private let selection: Binding<Item?>
    private let allowsDeselection: Bool

    /// Always-one-selected. Re-tapping the current chip does nothing.
    init(
        items: [Item],
        selection: Binding<Item>,
        fill: Color,
        title: @escaping (Item) -> String,
        systemImage: @escaping (Item) -> String? = { _ in nil }
    ) {
        self.items = items
        self.fill = fill
        self.title = title
        self.systemImage = systemImage
        self.allowsDeselection = false
        self.selection = Binding<Item?>(
            get: { selection.wrappedValue },
            set: { newValue in
                guard let newValue else { return }
                selection.wrappedValue = newValue
            }
        )
    }

    /// Deselectable. Re-tapping the current chip clears the selection.
    init(
        items: [Item],
        selection: Binding<Item?>,
        fill: Color,
        title: @escaping (Item) -> String,
        systemImage: @escaping (Item) -> String? = { _ in nil }
    ) {
        self.items = items
        self.fill = fill
        self.title = title
        self.systemImage = systemImage
        self.allowsDeselection = true
        self.selection = selection
    }

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items) { item in
                Chip(
                    title: title(item),
                    systemImage: systemImage(item),
                    fill: fill,
                    isSelected: selection.wrappedValue == item,
                    action: { tap(item) }
                )
            }
        }
    }

    private func tap(_ item: Item) {
        if allowsDeselection {
            selection.wrappedValue = ChipSelection.next(current: selection.wrappedValue, tapped: item)
        } else {
            let current = selection.wrappedValue ?? item
            let next: Item = ChipSelection.next(current: current, tapped: item)
            selection.wrappedValue = next
        }
    }
}
```

The two-line selection rule is pulled out so it is unit-testable without a view
host — the overload chosen by optionality *is* the semantics:

```swift
nonisolated enum ChipSelection {
    static func next<Item: Hashable>(current: Item, tapped: Item) -> Item {
        tapped
    }

    static func next<Item: Hashable>(current: Item?, tapped: Item) -> Item? {
        current == tapped ? nil : tapped
    }
}
```

The non-optional init funnels into the same `Binding<Item?>` so the body has one
code path; its setter drops `nil`, which is what makes the re-tap a no-op.

## Replacing a segmented `Picker`

```swift
// Before — truncates, and the segmented control is not in this language.
Picker("", selection: $intervalUnit) {
    ForEach(IntervalUnit.allCases) { Text($0.label).tag($0) }
}
.pickerStyle(.segmented)

// After
ChipGroup(items: IntervalUnit.allCases,
          selection: $intervalUnit,
          fill: Palette.tasks,
          title: \.label)
```

`Item` needs `Identifiable & Hashable`; a `String`-raw-value enum gets `id` with
`var id: String { rawValue }`. Delete the `.pickerStyle(.segmented)` line —
leaving the `Picker` behind "as a fallback" is how a screen ends up with both.

In a `Form` row, put the group in its own row and let it wrap:

```swift
Section("Repeat every") {
    Stepper("\(intervalValue)", value: $intervalValue, in: 1...99)
    ChipGroup(items: IntervalUnit.allCases, selection: $intervalUnit,
              fill: Palette.tasks, title: \.label)
}
```

## `FlowLayout`

Wraps children left-to-right, top-to-bottom. There is exactly one of these per
app — if you are about to write a second flow layout under another name, use
this one.

`Layout`'s requirements are `nonisolated`, so the conformer must be `nonisolated`
too. Under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` a plain `struct
FlowLayout: Layout` fails to conform, with an error about main-actor-isolated
witnesses.

```swift
/// Wraps its children left-to-right, top-to-bottom, breaking to a new row when
/// the next child would overflow the proposed width.
nonisolated struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 10_000
        let rows = makeRows(subviews: subviews, maxWidth: maxWidth)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        let rows = makeRows(subviews: subviews, maxWidth: maxWidth)
        var y = bounds.minY
        var index = 0
        for row in rows {
            var x = bounds.minX
            for _ in row.indices {
                let subview = subviews[index]
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
                index += 1
            }
            y += row.height + spacing
        }
    }

    private func makeRows(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let additionalWidth = current.indices.isEmpty ? size.width : size.width + spacing

            if !current.indices.isEmpty && current.width + additionalWidth > maxWidth {
                rows.append(current)
                current = Row()
            }

            current.indices.append(index)
            current.width += current.indices.count == 1 ? size.width : size.width + spacing
            current.height = max(current.height, size.height)
        }

        if !current.indices.isEmpty {
            rows.append(current)
        }

        return rows
    }
}
```

Notes on the implementation:

- **8 pt spacing on both axes** — one `spacing` value, used between chips in a
  row and between rows.
- `proposal.width ?? 10_000` handles the unspecified proposal SwiftUI sends when
  sizing in an unbounded context; a `nil` there would otherwise put every chip
  on one row.
- `sizeThatFits` returns `proposal.width` when it has one, so the layout fills
  its container rather than hugging its widest row — that keeps chips flush with
  the leading gutter.
- `subview.sizeThatFits(.unspecified)` is asked for once per measurement pass;
  chips are cheap and self-sizing, so the empty `cache` is deliberate. Do not
  add a cache before you have measured a problem.
- Rows grow to the tallest chip in them, which is what keeps a wrapped group
  aligned when one label bumps to two lines at large Dynamic Type.
