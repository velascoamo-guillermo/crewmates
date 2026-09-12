# Navigation: native tab bar + FAB

Default choice: **keep the platform tab bar and overlay a FAB.** The custom
floating tab bar with a centre `+` is the alternative, and it costs more than it
looks — trade-offs at the bottom.

## `FloatingActionButton`

56 pt accent circle, 22 pt semibold glyph in `onAccent`, and the one
accent-tinted shadow the language allows (`accent 30 %, radius 10, y 4`) so
exactly one element on screen glows.

```swift
import SwiftUI

struct FloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Palette.onAccent)
        }
        .buttonStyle(FABButtonStyle())
        .accessibilityLabel("Add task")
        .accessibilityIdentifier("fab.addTask")
    }
}

private struct FABButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 56, height: 56)
            .background(Circle().fill(Palette.accent))
            .shadow(color: Palette.accent.opacity(0.3), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
```

It is icon-only, so the label is mandatory — name the action ("Add task"), not
the glyph ("Plus"). The identifier makes it addressable from a UI test
(`app.buttons["fab.addTask"]`) without depending on the localised label.

`Palette.accent.opacity(0.3)` in the shadow is the documented shadow spec, not
an invented colour — that is the only place a token's opacity is spelled at a
call site.

## Overlaying it on the `TabView`

```swift
struct MainTabView: View {
    @Binding var selectedTab: AppTab
    @State private var showAdd = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                DashboardView()
            }
            Tab("Menu", systemImage: "square.grid.2x2.fill", value: AppTab.menu) {
                MenuHubView()
            }
            Tab(value: AppTab.search, role: .search) {
                SearchView()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if selectedTab != .search {
                FloatingActionButton { showAdd = true }
                    .padding(.trailing, 20)
                    .padding(.bottom, TabBarMetrics.fabClearance)
            }
        }
        .sheet(isPresented: $showAdd) { AddItemSheet() }
    }
}
```

Four things that are easy to get wrong:

1. **`.overlay(alignment: .bottomTrailing)` on the `TabView`**, not a `ZStack`
   wrapping it. The overlay does not participate in the tab scene's layout, so
   it cannot resize or reorder the tabs, and it stays put across tab changes.
2. **The bar is not in the overlay's safe area.** An overlay on the `TabView`
   is laid out against the *window's* bottom inset (the home indicator), not
   against the bar — so `.padding(.bottom, 16)` puts the FAB behind the bar.
   The clearance must include the bar's own height.
3. **`Tab(value:role: .search)` survives**, because the native bar survives.
   That is the whole reason to prefer this recipe on iOS 18/26.
4. **Hidden on the search tab** via `if selectedTab != .search` — the search
   role expands a field over the bar area, and a FAB there covers it. Hide it
   while a sheet is presented too, if your sheet is not full-height.

Name the clearance instead of scattering a literal:

```swift
nonisolated enum TabBarMetrics {
    /// Measured bar height, above the bottom safe-area inset. The classic
    /// compact bar is 49; iOS 26's glass bar is taller, and the value differs
    /// on iPad and in landscape. VERIFY THIS ON DEVICE before shipping —
    /// there is no public API for it, so it is a measurement, not a constant.
    static let barHeight: CGFloat = 60
    /// Gap between the bar's top edge and the FAB.
    static let gap: CGFloat = 16
    static var fabClearance: CGFloat { barHeight + gap }
}
```

**This is the recipe's one soft spot.** `barHeight` is eyeballed, so treat a
number you inherited from an existing screen as measured data: if the code you
are replacing used a larger total clearance, keep the larger total rather than
"cleaning it up" to a smaller derived one. A FAB that overlaps the bar is a
worse bug than a FAB sitting a few points high.

**Derive it instead of asserting it** where the bar height is not fixed — iPad,
landscape, an expanded search field, or a future OS that changes the metric.
Read the inset from *inside* a tab, where the bar is already excluded from the
safe area, and place the FAB with `safeAreaInset`:

```swift
extension View {
    /// Applied to a tab's root content: the content's bottom safe area already
    /// excludes the tab bar, so a 16 pt gap here is measured from the bar's
    /// top edge on every device and orientation — no bar-height constant.
    func floatingAddButton(isVisible: Bool, action: @escaping () -> Void) -> some View {
        safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
            if isVisible {
                FloatingActionButton(action: action)
                    .padding(.trailing, 20)
                    .padding(.bottom, 16)
            }
        }
    }
}
```

Trade-off between the two: the overlay floats over content (content can scroll
under the FAB) and lives in one place; the `safeAreaInset` version reserves
space so nothing ever hides behind the FAB and needs no measured constant, but
must be applied per tab. Prefer the overlay with a named constant for a fixed
phone-only compact bar; prefer `safeAreaInset` as soon as iPad, landscape, the
search field or iOS 26's variable-height bar are in scope — i.e. whenever you
cannot verify `barHeight` on every configuration you ship.

**Focus order.** The FAB must come after the content and before the tab bar.
An `.overlay` already lands there; if you move it into a `ZStack`, check with
VoiceOver that it has not jumped ahead of the content.

## iOS 26 notes

- The `Tab(_:systemImage:value:)` builder shown above is the iOS 18+ API and is
  required on iOS 26; the old `.tabItem` form still compiles but opts out of
  role-based tabs and the bar's scroll-minimise behaviour.
- The iOS 26 bar renders as glass and **minimises on scroll**. The FAB does not
  follow it — the overlay stays at a fixed clearance, so on a long scroll the
  gap between the FAB and a minimised bar grows. That is acceptable; animating
  the FAB in sympathy with the bar means re-deriving the bar's live height every
  frame, which there is no public API for.
- Do not add material or glass to the FAB to "match" the bar. The FAB is a flat
  accent circle; the system bar being glass is the system's business.

## Alternative: custom `FloatingTabBar`

Only if the centre `+` **must** live in the bar — i.e. the design's primary
action is a bar item, not an overlay. It is a white pill floating over the
canvas with the accent circle in the middle
(`cute-pastel-style/references/components.md` → Floating tab bar).

What you give up, all of it, permanently:

| Lost | Consequence |
|---|---|
| `Tab(role: .search)` | no system search field, no search-tab behaviour — you build and place the field yourself |
| iOS 26 glass + scroll-minimise | the bar is opaque and always present; the "bar gets out of the way" interaction is gone |
| Per-tab state restoration and the bar's own navigation plumbing | you own `selection`, and the pop-to-root-on-retap gesture, by hand |
| Built-in accessibility | you re-implement: one button per tab, `.isSelected` traits, focus order, and the "Tab N of M" grouping |
| Dynamic Type behaviour | the system bar reflows labels and switches to a compact layout at accessibility sizes; a custom pill clips instead, so you write that too |
| Automatic bottom safe-area inset for content | every screen must inset itself by the bar height, or content scrolls under it |

Budget the re-implementation honestly: the bar itself is an afternoon, the
accessibility and Dynamic Type parity is not. If the answer is "we want the
cute bar but can't afford that", the native bar + FAB **is** the documented
look — it is not a degraded fallback.
