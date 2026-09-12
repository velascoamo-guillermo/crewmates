# Hero header

One number, big enough to be the screen's subject. It is the largest single
share of the accent budget, so a screen gets exactly one.

```swift
import SwiftUI

struct HeroHeader: View {
    let label: String
    let value: Int
    let unit: String
    let subline: String?

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value, format: .number)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.accent)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: value)

                Text(unit)
                    .font(.title3)
            }

            if let subline {
                Text(subline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
```

## Why each line is there

| Line | Reason |
|---|---|
| `design: .rounded` at size 56 | the rounded face on the numeral is the look; the rest of the screen stays on the system face |
| `Palette.accent` | the numeral is the one place the saturated accent is allowed at size |
| `.monospacedDigit()` | tabular figures, so the numeral does not jiggle between 8 and 11 |
| `.contentTransition(.numericText())` | digit-wise roll, not a crossfade of the whole string |
| `.animation(.snappy, value: value)` | the component animates itself. Without it the caller must remember `withAnimation`, and a plain `value += 1` from a store update would jump |
| `alignment: .firstTextBaseline` | the unit sits on the numeral's baseline; centre-aligning floats it |
| `.padding(.vertical, 12)` + `maxWidth: .infinity` | centred hero block, gutter owned by the parent |
| `children: .combine` | one announcement — "3 tasks today, 2 to buy" — instead of three fragments |

`contentTransition(.numericText())` needs the value to be the animation's
trigger. If the numeral crossfades instead of rolling, the `.animation(_:value:)`
is missing or is attached above the `Text` rather than to the transitioning view.

For a value that is not an `Int` — a countdown, a percentage — use
`.numericText(value: Double(value))` so SwiftUI knows the direction of travel
and rolls the digits the right way.

## Call site

```swift
HeroHeader(label: "Good morning · Friday",
           value: store.tasksDueToday.count,
           unit: "tasks today",
           subline: shoppingSubline)
```

The label is a caption on the canvas, not a navigation title — keep the real
`.navigationTitle` as well, or set it to `""` deliberately.

## Zero and empty states

Do not hide the hero when the count is 0, and do not swap the numeral for a
word: the block's height anchors the screen, and a disappearing hero makes the
layout jump on every mutation.

- **Zero is a legitimate hero.** Show `0` in `Palette.accent`, and change the
  *unit and subline* to carry the good news: `unit: "tasks today"`,
  `subline: "Nothing due — enjoy it"`.
- **No data yet** (still loading, or the user has created nothing): render the
  hero with the numeral replaced by a redacted placeholder, keeping the same
  frame — `Text("0").redacted(reason: .placeholder)` — rather than collapsing
  the block.
- **A unit that reads wrong at 1** is a string problem, not a layout problem:
  pass the singular from the call site (`value == 1 ? "task today" : "tasks today"`),
  or use a localised plural-rule string. Never print "1 tasks".
- **Accessibility for zero:** the combined element already reads
  "0 tasks today, Nothing due — enjoy it", which is correct. Do not add an
  `.accessibilityLabel` that contradicts the visible numeral.
