# Components

Every component: **Anatomy** (ordered parts with measurements) · **States** ·
**Accessibility** · **Frame** (which reference image in `../assets/` shows it).

All measurements are points (pt ≡ dp ≡ CSS px at 1×). They are exact values, not
ranges — two engineers on two platforms must land on the same pixels.

1. [Canvas](#canvas) · 2. [Hero header](#hero-header) · 3. [Card](#card) ·
4. [Gradient cards — promo and status](#gradient-cards--promo-and-status) ·
5. [Chip](#chip) · 6. [Chip group](#chip-group) ·
7. [Floating tab bar](#floating-tab-bar) · 8. [Native bar + FAB fallback](#native-bar--fab-fallback) ·
9. [Tile grid](#tile-grid) · 10. [List row](#list-row) · 11. [Full-screen sheet](#full-screen-sheet) ·
12. [Pill segmented control](#pill-segmented-control) · 13. [Twin buttons](#twin-buttons) ·
14. [Primary pill button](#primary-pill-button) ·
15. [Circular header button](#circular-header-button) · 16. [Selected card](#selected-card)

---

## Canvas

**Anatomy**
1. A 3-stop vertical linear gradient: `canvasTop` at 0, `canvasMid` at 0.45,
   `canvasBottom` at 1.
2. Full-bleed — it runs under the status bar, the home indicator and any
   navigation chrome.
3. Nothing else. The canvas carries no texture, no blur, no card.

**States** — none. It does not change with scroll, selection or tab.

**Accessibility** — if a decorative illustration layer sits between the gradient
and the content, it must be hidden from assistive tech (`accessibilityHidden` /
`importantForAccessibility="no"` / `aria-hidden`). It is never informative.

**Frame** — `../assets/1.png`, visible behind everything.

> The canvas owns the screen's gradient (rule 1); only the two gradient-card
> variants may carry one, and they share its token pair. A scroll view over it
> must have a transparent background, or the gradient stops at the first row.

---

## Hero header

**Anatomy** (centred, 12 pt vertical padding, stacked with 2 pt between lines)
1. Caption — 13 pt, `accentInk`. A short state label ("Período").
2. Numeral — 56 pt, **rounded**, bold, `accent`. Optionally followed by a unit at
   20 pt, baseline-aligned to the numeral, same colour.
3. Subline — 15 pt, `inkSecondary`. One line, never two.

**States**
- Value change: animate digit-wise, not as a crossfade of the whole string.
- Empty: keep the three-slot structure — caption, an em dash at 56 pt in
  `inkSecondary`, subline explaining what to log. Do not collapse the block, or
  the screen reflows every time data arrives.

**Accessibility** — the three lines are one accessibility element with a combined
label ("Período, día 1, ovulación en 18 días"). Announcing "1" alone is useless.
Use tabular/lining figures so the numeral does not reflow as digits change.

**Frame** — `../assets/1.png`, top third.

---

## Card

**Anatomy**
1. Fill `surface`, corner radius **20**.
2. 16 pt gutter from the screen edges; 12 pt gap between stacked cards.
3. 18 pt inner padding on all sides.
4. Shadow `black 6 %, radius 6, y +2`. One shadow, never two.
5. Optional title — 17 pt semibold `ink`, then 12 pt before the content.

**States** — press: spring `response 0.3, damping 0.7`, scale 0.97. Only if the
whole card is a tap target.

**Accessibility** — a tappable card is one button element with a label that
summarises its content, not a container of separately-focusable text.

**Frame** — `../assets/2.png` (list card), `../assets/4.png` (chip-group cards).

> The card is flat `surface`. Not material, not blur, not a gradient, not accent.
> If you want it to stand out, that is what the gradient cards are for.

---

## Gradient cards — promo and status

The gradient card is the **only** surface family allowed a gradient fill (rule 1's
exception). It has two variants, and `../assets/1.png` shows both stacked on one
screen — so the cap is **two gradient cards per screen**, not one, and both must
reuse the same `promoGradientStart` → `promoGradientEnd` pair. A third gradient, or
a different gradient pair on the second card, breaks rule 1.

Shared by both variants:
1. Card geometry — radius 20, 16 gutter, 18 inner padding, card shadow.
2. Fill: diagonal linear gradient `promoGradientStart` → `promoGradientEnd`,
   top-leading to bottom-trailing.
3. All text and glyphs in `promoInk` — a deep indigo, **not** `ink`. It must clear
   4.5:1 against *both* gradient ends, not just the lighter one.

### Variant A — promo card (dismissible)

An opt-in offer. Transient: the user can make it go away.

**Anatomy**
1. Shared geometry and fill.
2. Content: an illustration or avatar row, then a 2-line message, 15 pt,
   `promoInk`, centred.
3. Trailing dismiss affordance: a `×` glyph, 14 pt, `inkSecondary`, in the
   top-trailing corner with a 44 pt hit target.

**States** — dismissed: the card is removed and the stack closes up; it does not
leave a gap.

**Accessibility** — the `×` needs its own label ("Descartar"). The card body and
the dismiss button are two elements.

**Frame** — `../assets/1.png`, the lower card ("Sincroniza tu ritmo…"). Sampled
fill `#C3BEF1` → `#E5B6E4`; its `×` samples `#7C797D`.

### Variant B — status card (persistent, navigational)

Reports current state and pushes to the detail for it. **No `×`** — it is content,
not an offer, so it never dismisses.

**Anatomy**
1. Shared geometry and fill.
2. Title — 17 pt bold, **ALL CAPS**, `promoInk`, leading-aligned.
3. Body — one or two lines, 15 pt, `promoInk`, leading-aligned, wrapping to ~60 %
   of the card width so it clears the numeral block.
4. Trailing affordance: a `→` arrow glyph, 17 pt, `promoInk`, top-trailing corner.
   An arrow, never a chevron, and never a `×`.
5. Numeral block, trailing edge, bottom-aligned: a large numeral (28 pt bold,
   `promoInk`) over a 10 pt bold ALL-CAPS caption ("DÍA DEL CICLO").
6. Optional decorative panel: a soft `#FDC6DB` rounded shape inset behind the
   numeral block, clipped to the card. Decorative only.

**States** — press scale 0.97, whole card. It is one tap target.

**Accessibility** — one button. Label combines title, body and numeral block
("Etapa corporal, primera fase de tu ciclo, día 1 del ciclo"); the arrow and the
decorative panel are both hidden.

**Frame** — `../assets/1.png`, the upper card ("ETAPA CORPORAL"). Sampled fill
`#C3BAE9` → `#F8C1D8`; title samples `#19004C`, numeral `#26003A`.

> Choosing between them: can the user make it go away? Promo. Does it report
> state the screen is about? Status. A status card with an `×`, or a promo card
> with an arrow, is the wrong variant.

---

## Chip

**Anatomy**
1. Capsule, radius 999. Horizontal padding 14, vertical padding 9 → ≈ 36 pt tall.
   Hit slop expands the touch target to **44**; the visual height stays 36.
2. Leading glyph — 18 pt emoji or icon.
3. 6 pt gap.
4. Label — 15 pt medium, `ink`.
5. Fill — the `chipFill` for that content category.

**States**

| State | What changes |
|---|---|
| Default | as above |
| Pressed | scale 0.96, spring `response 0.3, damping 0.7` |
| **Selected** | **a 2 pt `accent` stroke is added, and a 14 pt `accent` check badge appears trailing the label. The fill does not change.** |
| Disabled | fill and label at 40 % opacity; no stroke |

The selected rule is the one most often got wrong. Swapping the fill to the
accent breaks rule 3 (accent budget) and destroys the category colour-coding —
the fill is what tells you *which group* a chip belongs to, so it must survive
selection. Selection is additive: stroke + badge, nothing removed.

**Accessibility** — selection must be exposed as a trait/state
(`.isSelected` / `role="checkbox" aria-checked`), never colour alone; the stroke
and badge are the visual redundancy that makes it pass without colour vision.
Label includes the glyph's meaning, not the glyph.

**Frame** — `../assets/4.png` ("Mucho" is selected), `../assets/5.png` (category
fills across Energía / Piel y cabello).

---

## Chip group

**Anatomy**
1. A wrapping flow layout, 8 pt spacing on **both** axes.
2. Grouped under a section title inside a single card — the card is the group
   boundary, not a divider.
3. Title 17 pt semibold `ink`, 12 pt above the first chip row.
4. Optional trailing inline action on the title row — 15 pt, the secondary link
   colour, never `accent`.

**States** — single- or multi-select is a property of the group; the chip's
selected treatment is identical either way.

**Accessibility** — the card is a group with the title as its label, so a
screen-reader user hears "Vida sexual, group" before the chips.

**Frame** — `../assets/4.png`, `../assets/5.png`.

---

## Floating tab bar

**Anatomy**
1. A pure `#FFFFFF` pill — radius 999 — inset 16 pt from the screen edges,
   floating 8 pt above the safe-area bottom inset. Card shadow.
2. Five items, evenly distributed.
3. Each item: 22 pt glyph, 2 pt gap, **10 pt label**. The label is never dropped —
   rule 5.
4. Inactive: glyph and label `inkSecondary`.
5. The centre item is the primary action: a raised **44 pt `accent` circle** with
   a 20 pt `+` in `onAccent`, its centre lifted so it breaks the pill's top edge,
   with its own 10 pt label below.

**States** — selected (non-centre): the glyph and label turn `accent` and sit on
a tinted `accentSoft`-at-low-opacity pill behind them. The bar itself never
changes.

**Accessibility** — each item is a tab with a selected state. The centre item is a
**button**, not a tab — it opens a sheet, it does not select a page; labelling it
as a tab makes assistive navigation lie.

**Frame** — `../assets/1.png`, `../assets/2.png`, `../assets/6.png`.

> The bar is opaque white. A blurred/material bar is the single most common
> drift in this language and it breaks rule 2.

---

## Native bar + FAB fallback

Use when the platform's own tab bar is worth keeping (iOS 26 search-role tabs,
Android predictive back, per-tab state restoration).

**Anatomy**
1. The platform tab bar, untouched.
2. A **56 pt `accent` circle** FAB overlaid bottom-trailing: 20 pt from the
   trailing edge, 16 pt above the tab bar's top edge.
3. Glyph 22 pt `onAccent`.
4. Shadow `accent 30 %, radius 10, y +4` — the only place an accent-tinted shadow
   is allowed.

**States** — press scale 0.96. Hidden while a sheet is presented.

**Accessibility** — icon-only, so it requires an explicit label. It must be
reachable in the focus order after the content, before the tab bar.

**Frame** — no reference frame; this is the documented alternative to
`../assets/1.png`'s custom bar.

---

## Tile grid

**Anatomy**
1. Inside a white card (radius 20), never directly on the canvas.
2. 3 columns, 16 pt spacing both axes.
3. Each tile: a **64 pt `tileFill` circle** containing a 26 pt glyph, then 8 pt,
   then a label — 13 pt, `ink`, up to 2 lines, centred.
4. Tile corner radius is therefore 32 (half of 64) — the circle *is* the radius.

**States** — press scale 0.97 on the whole tile, circle and label together.

**Accessibility** — circle + label are one button; the label is the accessible
name. The glyph is decorative.

**Frame** — `../assets/6.png`.

---

## List row

**Anatomy**
1. Fill `surface`, radius **16**. 10 pt between stacked rows.
2. Leading: a glyph circle (`tileFill`) with the emoji/icon inside.
3. Title 17 pt `ink`; optional subtitle 13 pt `inkSecondary`.
4. Trailing chevron, 13 pt, `inkSecondary`.
5. Inner padding 14 pt.

**States** — press scale 0.97; no highlight fill change.

**Accessibility** — one button per row, label = title + subtitle. The chevron is
decorative and must be hidden.

**Frame** — `../assets/2.png`.

---

## Full-screen sheet

**Anatomy**
1. Full-screen, canvas gradient behind (the sheet does **not** introduce a second
   gradient — it reuses the canvas).
2. Close control: a **36 pt white circle** with a 16 pt `×`, top-**leading**,
   card shadow.
3. Centred title, 17 pt semibold `ink`, on the same row as the close control.
4. A week strip pinned below the header, not scrolled with the content: weekday
   initials 13 pt `inkSecondary` over day numbers 17 pt `ink`.
5. Today: an `accent`-filled circle, 36 pt, with the number in `onAccent`.
6. Content: chip-group cards, 16 gutter, 12 gap.
7. Sheet corner radius 24 where the platform shows one.

**States** — the pinned strip gains the card shadow once content scrolls beneath
it; before that it is flush.

**Accessibility** — the close control needs a label. Focus moves into the sheet on
present and returns to the invoking control on dismiss.

**Frame** — `../assets/4.png`, `../assets/5.png`.

---

## Pill segmented control

**Anatomy**
1. Track: a capsule in `surface` at a slightly lower opacity than a card, 4 pt
   inner padding.
2. Thumb: a white capsule with the card shadow, sized to the selected segment.
3. Labels 15 pt medium — selected `ink`, unselected `inkSecondary`.

**States** — the thumb slides with spring `response 0.3, damping 0.7`. Labels
crossfade; they do not slide.

**Accessibility** — expose as a single tab list / segmented control with a
selected state, not as N independent buttons.

**Frame** — `../assets/2.png` ("Sept / Año").

---

## Twin buttons

Two peer actions on one row — *not* a primary and a secondary. They are
distinguished by **hue**, not by weight, which is what signals that either is a
reasonable choice.

**Anatomy**
1. Two equal-width capsules filling the row: 16 pt gutter each side, 12 pt gap
   between them, radius 999, height 36 (hit slop to 44).
2. Label centred, 15 pt medium. No glyph.
3. Left button — fill `accentSoft`, label `accentInk`.
4. Right button — fill `secondarySoft`, label `secondaryInk`.

Measured off `../assets/2.png`: the left fill samples `#FDE1E8` with a rose label,
the right `#E0DFFE` with a violet label. Each pill is 175 × 32 in a 390 pt-wide
frame, gutter 14, gap 14.

**States** — press scale 0.96 (they are pills, so they follow the chip curve).
Neither gets a shadow; the fills already separate them from `surface`.

**Accessibility** — two buttons, no grouping. Both fills clear 4.5:1 against their
own label colour (`tokens.md` §4); neither label may use the lighter rose the
reference ships, which is only 3.2:1.

> They do **not** count against the one-primary-pill-button rule — no accent fill,
> no accent-on-white. But do not use two `accentSoft` pills: a same-hue pair reads
> as one disabled and one enabled.

---

## Primary pill button

**One per screen.** Two variants, chosen by what is behind it:

| Behind it | Fill | Label |
|---|---|---|
| The canvas gradient | pure `#FFFFFF` capsule, card shadow | `accent`, 17 pt semibold |
| A `surface` card | `accent` capsule | `onAccent`, 17 pt semibold |

**Anatomy** — radius 999, height 48, horizontal padding 24.

**States** — press scale 0.97. Disabled: 40 % opacity, no shadow.

**Accessibility** — 48 pt height already clears the 44 pt minimum; keep it.

**Frame** — `../assets/1.png` ("Fin del período", white-on-gradient variant). The
pair in `../assets/2.png` is the separate **Twin buttons** component below, not
this one.

---

## Circular header button

**Anatomy** — a 36 pt pure `#FFFFFF` circle, 16 pt glyph in `ink`, card shadow.
Placed at the screen's leading or trailing edge on the header row, 16 pt gutter.

**States** — press scale 0.96.

**Accessibility** — icon-only: always needs an explicit label. Hit target padded
to 44 even though the circle is 36.

**Frame** — `../assets/1.png` (settings, top-leading), `../assets/2.png`,
`../assets/3.png` (back).

---

## Selected card

How a whole card shows selection — the card-scale analogue of the chip rule, and
identical in principle: **additive, fill unchanged**.

**Anatomy**
1. The card keeps its own fill and radius.
2. A 2 pt `accent` stroke is added, inset so it does not clip the content.
3. A 28 pt `accent` circle badge with an `onAccent` check sits at the
   top-trailing corner, overlapping the card's edge.

**States** — deselect removes both; nothing else moves.

**Accessibility** — selected trait on the card element; the badge is decorative
once the trait is set.

**Frame** — `../assets/3.png` (theme and mascot pickers).
