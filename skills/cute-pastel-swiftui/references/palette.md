# Palette + contrast tests

Step 1 of the adoption order. Nothing else in this skill works until `Palette`
exists and its contrast suite is green.

## The type

`Palette` must be `nonisolated`: the widget extension and every `Layout`
conformer run off the main actor, and under
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` a plain `enum` is `@MainActor` and
unreadable from there.

```swift
import SwiftUI
import UIKit

nonisolated enum Palette {
    // This file is the ONLY place in the app where a colour literal may appear.
    // Look every value up in cute-pastel-style/references/tokens.md —
    // §3 for the schema, §5 (reference instance) or §6 (Home instance) for hexes.
    // Replace each 0xRRGGBB below with the value for that role.

    // Canvas — three stops, consumed by GradientCanvas in that order.
    static let canvasTop    = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)
    static let canvasMid    = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)
    static let canvasBottom = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)

    // Surface is translucent on purpose — the canvas leaks through it.
    static let surface = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB,
                                 lightAlpha: 0.85, darkAlpha: 0.85)

    // Accent family.
    static let accent     = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)
    static let accentSoft = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)
    static let accentWash = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)
    static let accentInk  = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)
    static let onAccent   = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)

    // Violet secondary action, so secondary CTAs don't spend the accent budget.
    static let secondaryInk  = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)
    static let secondarySoft = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)

    // Text on a gradient card. `ink` fails at one of the two gradient ends.
    static let promoInk = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)
    static let promoGradientStart = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)
    static let promoGradientEnd   = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)

    // Text.
    static let ink          = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)
    static let inkSecondary = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB,
                                      lightAlpha: 0.55, darkAlpha: 0.60)

    // One feature fill per content category. These double as the chipFill set
    // and as Tile circle fills. Name them after the domain, not the colour.
    static let tasks    = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)
    static let shopping = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)
    static let meals    = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)
    static let pets     = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)
    static let stock    = dynamic(light: 0xRRGGBB, dark: 0xRRGGBB)

    /// Resolves a dynamic `Color` for one scheme. Tests need this; views never do.
    static func uiColor(_ color: Color, style: UIUserInterfaceStyle) -> UIColor {
        UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    }

    private static func dynamic(light: UInt32, dark: UInt32,
                                lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? rgb(dark, alpha: darkAlpha)
                : rgb(light, alpha: lightAlpha)
        })
    }

    private static func rgb(_ hex: UInt32, alpha: CGFloat) -> UIColor {
        UIColor(red:   CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue:  CGFloat(hex & 0xFF) / 255,
                alpha: alpha)
    }
}
```

Why `UIColor { trait in … }` rather than an asset catalog: one file, greppable,
diffable, and testable without a bundle. Why `UInt32` hex rather than
`Color(red:green:blue:)` floats: the token doc is written in hex, so the code
reads as the doc.

**Naming rule.** A role is named for its job (`accent`, `chipFill`, `surface`),
never its hue (`pink`, `lilac`). Two instances ship from one schema; a
hue-named token pins one of them.

## Contrast tests (Swift Testing)

These are acceptance criteria, not aspirations — `surface` is translucent, so
`ink` measured on opaque white passes while the shipped screen fails. Test the
**composite**.

Minimums, both schemes: `ink` and `inkSecondary` on `surface` composited over
each of the three canvas stops ≥ **4.5:1**; `onAccent` on `accent` ≥ **3.0:1**.
Extend the same suite to `accentInk` on `canvasTop`/`canvasMid`/`accentWash`,
`secondaryInk` on `secondarySoft`, and `promoInk` on **both** promo gradient
ends — full table in `cute-pastel-style/references/tokens.md` §4.

```swift
import Testing
import SwiftUI
import UIKit
@testable import YourApp

@Suite("Palette") @MainActor struct PaletteTests {

    private static let canvasStops: [(String, Color)] = [
        ("canvasTop", Palette.canvasTop),
        ("canvasMid", Palette.canvasMid),
        ("canvasBottom", Palette.canvasBottom),
    ]

    @Test("text on the translucent surface stays readable over every canvas stop")
    func surfaceOverCanvasContrast() {
        let texts: [(String, Color)] = [("ink", Palette.ink),
                                        ("inkSecondary", Palette.inkSecondary)]
        for style in [UIUserInterfaceStyle.light, .dark] {
            let surface = Palette.uiColor(Palette.surface, style: style)
            for (textName, text) in texts {
                let fg = Palette.uiColor(text, style: style)
                for (stopName, stop) in Self.canvasStops {
                    let blended = Self.composite(surface, over: Palette.uiColor(stop, style: style))
                    let ratio = Self.contrastRatio(fg, blended)
                    #expect(ratio >= 4.5,
                            "\(textName) on surface over \(stopName) \(Self.name(style)): \(ratio)")
                }
            }
        }
    }

    @Test("onAccent meets 3:1 against accent in both schemes")
    func onAccentContrast() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let ratio = Self.contrastRatio(Palette.uiColor(Palette.onAccent, style: style),
                                           Palette.uiColor(Palette.accent, style: style))
            #expect(ratio >= 3.0, "\(Self.name(style)) ratio \(ratio)")
        }
    }

    @Test("every role resolves to a different colour in light and dark")
    func dynamicRoles() {
        let roles: [(String, Color)] = Self.canvasStops + [
            ("surface", Palette.surface), ("accent", Palette.accent),
            ("accentInk", Palette.accentInk), ("ink", Palette.ink),
            ("tasks", Palette.tasks), ("pets", Palette.pets),
        ]
        for (roleName, color) in roles {
            #expect(Palette.uiColor(color, style: .light) != Palette.uiColor(color, style: .dark),
                    "\(roleName) should be dynamic")
        }
    }

    @Test("feature fills stay distinct from each other in both schemes")
    func distinctFills() {
        let fills = [Palette.tasks, Palette.shopping, Palette.meals, Palette.pets, Palette.stock]
        for style in [UIUserInterfaceStyle.light, .dark] {
            #expect(Set(fills.map { Palette.uiColor($0, style: style) }).count == fills.count,
                    Self.name(style))
        }
    }

    private static func name(_ style: UIUserInterfaceStyle) -> String {
        style == .dark ? "dark" : "light"
    }

    private static func luminance(_ c: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: nil)
        func lin(_ v: CGFloat) -> CGFloat { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    private static func contrastRatio(_ a: UIColor, _ b: UIColor) -> CGFloat {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Source-over blend of a translucent `top` onto an opaque `bottom`.
    /// `luminance` is alpha-blind, so anything translucent must be blended first.
    private static func composite(_ top: UIColor, over bottom: UIColor) -> UIColor {
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        top.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        bottom.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let outA = ta + ba * (1 - ta)
        func blend(_ t: CGFloat, _ b: CGFloat) -> CGFloat {
            guard outA > 0 else { return 0 }
            return (t * ta + b * ba * (1 - ta)) / outA
        }
        return UIColor(red: blend(tr, br), green: blend(tg, bg), blue: blend(tb, bb), alpha: outA)
    }
}
```

`@MainActor` on the suite, not on `Palette`: the tests touch `UIColor` trait
resolution, which wants the main actor; the palette itself must stay reachable
from the widget.

A failing ratio is a bug in the token, not in the test. Darken the text role
until it passes — do not lower the threshold, and do not "fix" it by making the
surface opaque, which deletes the wash.
