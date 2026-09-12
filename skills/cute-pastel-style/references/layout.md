# Layout, type and motion

Points (pt ≡ dp ≡ CSS px at 1×). Exact values, not ranges.

1. [Spacing](#spacing) · 2. [Radii](#radii) · 3. [Shadow](#shadow) ·
4. [Type](#type) · 5. [Touch targets](#touch-targets) · 6. [Motion](#motion)

---

## Spacing

Scale: **4 · 8 · 12 · 16 · 20 · 24**. Nothing between, nothing above 24 except
whole-screen offsets.

| Use | Value |
|---|---|
| Screen gutter (both edges) | 16 |
| Gap between stacked cards | 12 |
| Gap between list rows | 10 |
| Chip spacing, both axes | 8 |
| Section gap (between titled groups) | 24 |
| Card inner padding | 18 |
| List-row inner padding | 14 |
| Hero block vertical padding | 12 |

18 and 14 are inner paddings only — they are not scale steps and never appear as
gaps between siblings.

## Radii

| Element | Radius |
|---|---|
| Card, gradient cards (promo + status) | 20 |
| List row | 16 |
| Chip, pill button, segmented track/thumb, tab bar | 999 |
| Tile (a 64 pt circle) | 32 |
| Sheet | 24 |
| Inset text field | 12 |

Nothing in the language is square. A 0-radius rect signals "this was not styled".

## Shadow

Two shadows exist. There is no third, and no element gets both.

| Shadow | Value | Used by |
|---|---|---|
| Card | `black 6 %, radius 6, y +2` | Cards, list rows, tab bar, white pill buttons, circular header buttons, segmented thumb, pinned sheet header |
| FAB | `accent 30 %, radius 10, y +4` | The FAB / centre tab action **only** |

Card shadow above 8 % opacity turns the pastel muddy — the surfaces are meant to
float a millimetre, not hover. Never tint the card shadow; the accent-tinted glow
is reserved for the one FAB so it reads as the single primary action.

Platform mapping: CSS `box-shadow: 0 2px 6px rgba(0,0,0,0.06)`; iOS
`shadowColor .black, shadowOpacity 0.06, shadowRadius 6, shadowOffset (0, 2)`;
Android `elevation 2` **plus** `spotShadowColor`/`ambientShadowColor` set — the
default Android shadow is black and heavier than 6 %.

## Type

Rounded face for the hero numeral (SF Pro Rounded / Nunito / system rounded);
the system face everywhere else.

| Role | Size | Weight |
|---|---|---|
| Hero numeral | 56 | bold, rounded |
| Hero unit | 20 | bold, rounded, baseline-aligned |
| Screen / sheet title | 22 | semibold |
| Section & card title | 17 | semibold |
| Body, list title, button label | 15–17 | regular / medium |
| Chip label | 15 | medium |
| Caption, subtitle, hero caption | 13 | regular |
| Tab label | 10 | medium |

The hero numeral uses tabular/lining figures so its width does not jump between
values. Text colours are `ink` and `inkSecondary` — never `#000000`.

## Touch targets

Minimum **44** in both axes, always. Where the visual is smaller — a 36 pt chip,
a 36 pt circular header button, a 14 pt dismiss `×` — expand the target with hit
slop or transparent padding. Do not grow the visual to meet the minimum; the
36 pt chip height is part of the look.

## Motion

| Interaction | Spec |
|---|---|
| Press (card, tile, row, button) | spring `response 0.3, damping 0.7`, scale **0.97** |
| Press (chip) | same spring, scale **0.96** |
| Chip select | the stroke and badge spring in on the same curve; the fill does not animate, because it does not change |
| Hero value change | digit-wise numeric transition, not a crossfade of the whole string |
| Segmented thumb | same spring, position only; labels crossfade |

There is no entrance animation for cards, no staggered list reveal, no parallax
on the canvas. The gradient does not move.

**React Native:** every one of these runs on the UI thread as a Reanimated
worklet. A JS-driven `Animated` spring on a press is a bug in this language — the
whole point is that the surface answers the finger instantly.

**Reduced motion:** drop the scale, keep the opacity/colour change. Never remove
the feedback entirely — the press must still be visible, and the selected chip
must still gain its stroke and badge.
