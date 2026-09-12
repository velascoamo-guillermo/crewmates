# Do / Don't

The WHY column is the point. A rule without its reason gets negotiated down to
"a subtle version of the thing" — which is still the thing.

| Don't | Do instead | Why |
|---|---|---|
| Frosted glass / material / blur on a card over the gradient | Flat `surface` at 85 % opacity, radius 20, card shadow | Blur samples the canvas and re-renders it as a smear. The gradient is already the soft layer; blurring it twice muddies both. Translucency at a *fixed* 85 % gives the same "sitting on the wash" read, deterministically, at no GPU cost. |
| Accent as a card, sheet or chip background | `surface`, or the category `chipFill`; spend the accent on the numeral, one CTA, the selected stroke, the FAB | Accent ≤ 10 % of visible surface. A card-sized accent fill is 30–60 % on its own, and it forces body text onto a colour that only clears 3:1. |
| A gradient on a plain card, at any opacity | A flat fill. If the card must stand out, promote it to a **gradient card** — promo or status variant, max two per screen, both reusing the one `promoGradient` pair | Gradients with no consistent light direction do not read as depth. "Subtle, same-hue, 15 %" is still a gradient. |
| Selected chip swaps its fill to the accent | Add a 2 pt `accent` stroke and a 14 pt trailing accent check badge. Fill unchanged | The fill encodes *category*. Overwriting it on selection deletes that information exactly when the user is acting on it, and blows the accent budget once several chips are selected. |
| Emoji or icon used as the whole label ("icon-only tab bar") | Glyph **leads** a 10–15 pt text label | The glyph set is playful and ambiguous; the label is what makes it usable and what screen readers get. Icon-only is a density optimisation this language does not need. |
| `#000000` text, `#FFFFFF` text | `ink` / `inkSecondary`, which carry a trace of the base hue | Pure black on pastel reads as a hole punched in the wash. Every neutral is tinted toward the canvas hue. |
| Card shadow above 8 % opacity, or a tinted card shadow | `black 6 %, r6, y2` | Heavier shadows grey out the pastel. Accent-tinted shadow is reserved for the FAB so exactly one element glows. |
| Decorative illustration left visible to assistive tech | `accessibilityHidden` / `aria-hidden` | It is mood, not content. Announcing it buries the hero value. |
| Hard-coded hexes at call sites | Named role tokens (`accent`, `chipFill`, `surface`) | Two instances ship from the same schema (see `tokens.md` §5–6). A literal hex silently pins one instance and breaks the other, and breaks dark mode entirely. |
| Dark values asserted without checking | Run the §4 contrast rules against the real composite in both schemes | `surface` is translucent — the canvas leaks through. Testing `ink` on opaque white passes while the shipped screen fails. |
| Four or two canvas gradient stops | Three stops at 0 / 0.45 / 1 | Two read as a flat wash; four read as a rainbow. |
| Two twin buttons in the same hue | `accentSoft`+`accentInk` on the left, `secondarySoft`+`secondaryInk` on the right | Twin buttons are peers. A same-hue pair reads as one enabled and one disabled, which is the opposite of the intent. |
| A status card with an `×`, or a promo card with a `→` | Match the affordance to the variant: promo dismisses, status navigates | The affordance is the only thing telling the user whether the card will still be there tomorrow. |
| `ink` on a gradient card | `promoInk`, verified against **both** gradient ends | A gradient has two extremes; text that passes at the light end can fail at the other. |

## Red flags — stop

If you are about to write or approve any of these, stop and re-read the rule:

- Accent used as a large fill.
- A gradient on a plain card, or a third gradient anywhere.
- `material` / `blur` / `backdrop-filter` / `BlurView` / `.ultraThinMaterial`
  anywhere on a pastel surface.
- An emoji standing in for a label.
- `#000` or `#FFF` as a text colour.
- A card shadow over 8 %.
- A selected chip whose fill changed.
- A decorative illustration that is not accessibility-hidden.
- A hex literal at a call site.
- "Subtle", "low-opacity", "just a sheen", "same-hue" attached to any of the
  above. Lowering the opacity of a banned treatment does not un-ban it —
  the rule names the treatment, not its intensity.

## The one thing agents get wrong most

Asked whether they can blur a card, tint it with the accent, and add an inner
gradient, the instinct is to say "yes, but subtly" and prescribe a five-layer
stack. The correct answer is three no's and one alternative:

> No glass — flat `surface` at 85 %, radius 20, card shadow `black 6 %, r6, y2`.
> No accent fill — accent is capped at ~10 % of visible surface; use `surface`
> or the category `chipFill`, and spend the accent on the hero numeral, the FAB
> and the selected stroke.
> No gradient on this card — the canvas owns the screen's gradient. If it
> genuinely needs to stand out, promote it to a **gradient card**
> (`promoGradientStart → promoGradientEnd`; promo if dismissible, status if it
> reports state) and give up the other two asks. Max two per screen, and they
> share that one pair.
