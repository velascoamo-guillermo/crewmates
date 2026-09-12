---
name: cute-pastel-style
description: Use when a mobile UI should look cute, soft or pastel — gradient canvas, huge hero number, pastel pill chips, floating tab bar with a centre +, pastel tile grid — or when a request references a period-tracker, kawaii, candy, playful or "soft girl" app look, asks to match a pastel reference screenshot or video, or asks for the colour tokens, radii, spacing, shadow or accent rules behind that look. Platform-agnostic; pair with cute-pastel-swiftui or cute-pastel-expo.
---

# Cute Pastel

One soft vertical gradient owns the screen. Everything on it is flat pastel —
never blurred, never a second gradient — with one saturated accent spent
sparingly.

## The five rules

1. **One gradient system per screen.** The canvas owns it. Only the two gradient
   cards (promo, status) may carry one; both reuse the `promoGradient` pair, max
   two per screen. Never a third gradient.
2. **Surfaces are flat** white (dark `#1E1E1E`) at 85 %. Never material, glass,
   blur or backdrop-filter.
3. **Accent ≤ 10 % of visible surface** — hero numeral, one CTA, selected-chip
   stroke, FAB, centre tab action. Nothing else.
4. **Every interactive surface is a pill** (r999) or 16–24 radius rect.
5. **Emoji/icon leads a label**, never replaces it.

Prohibitions, not preferences — lower opacity still breaks it; see
`references/do-dont.md`.

## Reference frames

- `assets/1.png` hero, gradient cards, floating tab bar
- `assets/2.png` segmented, week strip, twin buttons
- `assets/3.png` selected-card treatment
- `assets/4.png` chip sheet, selected chip
- `assets/5.png` category chip fills, inset field
- `assets/6.png` tile grid in a card

## Tokens

Measured, not invented.

- `canvasTop` `#E6DDF4` · `canvasMid` `#F4E5F5` · `canvasBottom` `#FFEEF0` —
  stops 0/0.45/1
- `accent` `#FF4476` — numeral, FAB, selected stroke
- `accentInk` `#BE0B51` — accent *text*; `accentSoft` `#FDE1E8` — tinted fill
- `secondaryInk` `#6D5196` · `secondarySoft` `#E0DFFE` — violet secondary
- `surface` `#FCF9FA` @85 % — cards, rows, sheets
- `ink` `#2A2430` · `inkSecondary` `#645C6D` — text, sublines
- `chipFill` `#FFE9F1` — chip/tile fill per category

Dark values, derivation, contrast, Home instance: `references/tokens.md`.

## Components

`references/components.md` — per component: canvas, hero, card, chip, chip
group, floating tab bar, native-bar+FAB, tile grid, list row, sheet, segmented,
twin buttons, pill button, header button.

## Metrics

`references/layout.md`. Spacing 4/8/12/16/20/24, gutter 16. Radii 20 card, 16
row, 999 chip, 32 tile, 24 sheet. Shadow `black 6 %, r6, y2`; FAB `accent 30 %,
r10, y4`. Type 56 hero → 10 tab label. Touch ≥ 44.
Press spring `0.3/0.7`, scale 0.97 / 0.96 chips.

## Don't

- Accent as a large fill (card, sheet, chip).
- A third gradient, or a gradient on a plain card.
- Material, blur or glass on a pastel surface.
- A selected chip that swaps fill instead of gaining stroke+badge.

## Adoption order

tokens → canvas → surfaces/cards → chips → hero → nav+FAB → tile grid.

## Platform recipes

SwiftUI: `cute-pastel-swiftui`. Expo / React Native: `cute-pastel-expo`. A
tokens/rules-only ask opens neither — ask the platform; the repo's stack is
not the user naming it.
