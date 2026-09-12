# Tokens

1. [Inputs](#1-inputs)
2. [Derivation](#2-derivation)
3. [Full schema](#3-full-schema)
4. [Contrast rules (binding)](#4-contrast-rules-binding)
5. [Instance A — reference pink/lilac](#5-instance-a--reference-pinklilac)
6. [Instance B — Home peach/coral](#6-instance-b--home-peachcoral)
7. [Dark mode is derived](#7-dark-mode-is-derived)

Never hard-code a hex at a call site. Every colour below is a named role; the
call site names the role.

---

## 1. Inputs

Three inputs generate a whole palette.

| Input | Meaning | Example |
|---|---|---|
| `baseHue` | Where the canvas sits on the lilac → peach arc | lilac `280°` (reference), peach-lilac `295°` (Home) |
| `accent` | The one saturated colour | `#FF4476` (reference), `#F0607A` (Home) |
| `featureFills[]` | One pastel per content category — chips, tiles, list glyph circles | pink, deep pink, mint, peach, lilac |

Everything else is derived. If you are tempted to add a sixth input, you are
about to break rule 3 (accent budget) or rule 1 (one gradient system).

## 2. Derivation

| Token | Derived as |
|---|---|
| `canvasTop` | `baseHue` at L ≈ 88 %, S ≈ 28 % |
| `canvasMid` | `baseHue` blended 35 % toward the accent hue, at L ≈ 93 % |
| `canvasBottom` | warm near-white, L ≈ 97–98 %, carrying a trace of the accent hue |
| `chipFill` | the feature fill lightened to L ≈ 95 % |
| `tileFill` | the feature fill lightened to L ≈ 93 % (one step deeper than `chipFill`, so a tile circle reads against a white card) |
| `accentSoft` / `accentWash` | `accent` lightened to L ≈ 94 %, S ≈ 85 % — a *wash*, not a tint. An instance carrying a legacy saturated tint keeps it as `accentSoft` and adds `accentWash` for this role (see §6) |
| `secondarySoft` | `secondaryInk` lightened to L ≈ 94 % — same recipe, violet hue |
| `promoInk` | the `baseHue` darkened to L ≈ 18 %, keeping full hue — it must clear 4.5:1 on **both** promo gradient ends |
| `accentInk` | `accent` darkened until it clears 4.5:1 on `canvasTop` — typically ≈ 25 % darker, **not** 12 % (see §4) |
| `onAccent` | white in light, `canvasTop`'s dark counterpart in dark |
| `promoGradientStart/End` | a desaturated `baseHue` → a light accent tint; the only gradient allowed on a surface, shared by both gradient-card variants |

The canvas is a 3-stop vertical linear gradient at locations 0 / 0.45 / 1. Two
stops read as a wash; four read as a rainbow.

## 3. Full schema

Values shown are Instance A (the measured reference). Dark values are derived —
see §7.

| Role | Light | Dark | Usage |
|---|---|---|---|
| `canvasTop` | `#E6DDF4` | `#1A1626` | Canvas gradient stop 0 |
| `canvasMid` | `#F4E5F5` | `#221823` | Canvas gradient stop 0.45 |
| `canvasBottom` | `#FFEEF0` | `#121212` | Canvas gradient stop 1 |
| `surface` | `#FCF9FA` @ 0.85 | `#1E1E1E` @ 0.85 | Cards, list rows, sheets. Flat — never material |
| `accent` | `#FF4476` | `#FF7D9E` | Hero numeral, FAB, centre tab action, selected-chip stroke, one CTA |
| `accentSoft` | `#FDE1E8` | `#3A2430` | Accent-hue wash: the pink twin button, tinted secondary CTA, selected-tab pill |
| `secondaryInk` | `#6D5196` | `#C4B0E4` | Violet secondary action — inline links *and* the violet twin-button label |
| `secondarySoft` | `#E0DFFE` | `#2A2740` | Violet-hue wash: the lavender twin button's fill |
| `promoInk` | `#2A0E5C` | `#F0EAFA` | Text and glyphs on a gradient card (promo, status) — deep indigo, not `ink` |
| `accentInk` | `#BE0B51` | `#FF9FB8` | Accent-coloured **text** sitting on the canvas |
| `onAccent` | `#FFFFFF` | `#1A1626` | Label/glyph on an accent fill |
| `ink` | `#2A2430` | `#F4EFF6` | Primary text. Never `#000`/`#FFF` |
| `inkSecondary` | `#645C6D` | `#B4AABF` | Sublines, captions, inactive tab labels |
| `chipFill` | `#FFE9F1` | `#2E2330` | Chip background (one per category) |
| `tileFill` | `#FFE2E9` | `#33262D` | Tile glyph circle, list-row glyph circle |
| `promoGradientStart` | `#C1B5E7` | `#3B3357` | Gradient-card fill (promo + status), diagonal start |
| `promoGradientEnd` | `#FEC8DC` | `#5A3648` | Gradient-card fill (promo + status), diagonal end |

Pure `#FFFFFF` (not `surface`, not 85 %) is used for exactly three things: the
floating tab-bar pill, the primary pill button on the canvas, and the circular
header button. They must read as fully opaque objects floating over the gradient.

## 4. Contrast rules (binding)

These are acceptance criteria, not aspirations. Check them whenever you change a
hue, and check them in **both** schemes.

| Pair | Minimum | Why |
|---|---|---|
| `ink` on `surface` composited over each of the three canvas stops | 4.5:1 | `surface` is translucent, so the canvas leaks through. Testing `ink` on opaque white passes while the shipped screen fails. |
| `inkSecondary` on the same composite | 4.5:1 | Sublines are body text, not decoration |
| `onAccent` on `accent` | 3:1 | Only ever used at ≥ 17 pt bold or as a glyph |
| `accentInk` on `canvasTop` and on `canvasMid` | 4.5:1 | The hero caption and subline are small text directly on the gradient |
| `accentInk` on `accentSoft` | 4.5:1 | The pink twin button is a small-text label on a wash |
| `secondaryInk` on `secondarySoft` | 4.5:1 | Same, for the violet twin button |
| `promoInk` on **both** promo gradient ends | 4.5:1 | A gradient fill has two extremes; passing at one end is not passing |

**How to composite:** `composite = 0.85 × surface + 0.15 × canvasStop`, per
channel. For Instance A over `canvasTop` that is `#F9F5F9`; `ink` `#2A2430` on it
is **13.9:1**.

**The accentInk trap.** The reference app's own accent text is `#EE0E65`, which
measures **3.3:1** on `canvasTop` — it fails 4.5:1 and is only admissible at
≥ 17 pt bold. Do not copy it for captions. Instance A therefore ships a derived
`accentInk` of `#BE0B51` (**4.8:1** on `canvasTop`, **5.2:1** on `canvasMid`).
When you darken an accent for text, darken until the ratio passes, not by a
fixed percentage.

`onAccent` white on `accent` `#FF4476` is **3.3:1** — passes the 3:1 bar, fails
4.5:1. That is why the accent only ever carries large bold text or a glyph, never
body copy. It is also why rule 3 exists: accent as a card or sheet fill would put
body text on it.

## 5. Instance A — reference pink/lilac

Eyedropped from the reference frames in `../assets/`. Treat as **±2 per channel**
— video compression moves flat fills by a point or two.

- Canvas `#E6DDF4` → `#F4E5F5` → `#FFEEF0`
- Accent `#FF4476`; accent text as shipped `#EE0E65` (see §4 — use `#BE0B51`)
- Surface `#FCF9FA`; pure `#FFFFFF` for the tab-bar pill, primary pill button and
  circular header buttons
- Feature fills: pink `#FFE9F1`, deep pink `#FFD1DF`, mint `#E7F5E9`,
  peach `#FFF0E8`, lilac `#ECE3F8`
- Tile glyph circle `#FFE2E9`
- Text `ink` `#2A2430`, `inkSecondary` `#645C6D`, `secondaryInk` `#6D5196`
- Twin-button fills (measured off `../assets/2.png`): pink `#FDE1E8`
  ("Editar período"), lavender `#E0DFFE` ("Notas")
- Gradient-card fill `#C1B5E7` → `#FEC8DC`; sampled `#C3BAE9` → `#F8C1D8` on the
  "ETAPA CORPORAL" status card and `#C3BEF1` → `#E5B6E4` on the "Sincroniza"
  promo card — **both gradient cards use the one pair**
- Gradient-card text `promoInk`; sampled `#19004C` (title) to `#382266` (body).
  Video compression clips the blue channel, so the schema rounds to `#2A0E5C`

`secondaryInk` `#6D5196` is a distinct role — a violet action colour, so secondary
actions do not spend the accent budget. It appears **both** as inline link text
("Notas", "Cambiar") **and** as the label of the lavender twin button, over its
own `secondarySoft` `#E0DFFE` fill.

The two twin buttons are **not** one token used twice. They are a matched pair in
two different hues — `accentSoft` + `accentInk` on the left, `secondarySoft` +
`secondaryInk` on the right — which is what marks them as peer alternatives rather
than a primary and a secondary. Verified: `accentInk` on `accentSoft` = **5.1:1**;
`secondaryInk` on `secondarySoft` = **4.9:1**; `promoInk` `#2A0E5C` on the two
gradient ends = **8.4:1** / **11.0:1**.

The reference's own pink twin-button label samples ≈ `#CF597E`, which is only
**3.2:1** on `#FDE1E8` — the same trap as `accentInk` (§4). Use `accentInk`.

## 6. Instance B — Home peach/coral

Same system, warmer hue, saturated coral accent. Feature fills come from the
app's existing palette and are unchanged.

| Role | Light | Dark |
|---|---|---|
| `canvasTop` | `#F3E6F6` | `#1B1522` |
| `canvasMid` | `#FDE3E3` | `#221820` |
| `canvasBottom` | `#FFF8F3` | `#121212` |
| `accent` | `#F0607A` | `#F58AA0` |
| `accentSoft` | `#E8A090` | `#F0B0A0` |
| `accentWash` | `#FCE4E7` | `#3A2428` |
| `accentInk` | `#B93A55` | `#F58AA0` |
| `secondaryInk` | `#6D5196` | `#C4B0E4` |
| `secondarySoft` | `#E7E0F5` | `#2A2740` |
| `promoInk` | `#2B1450` | `#F0EAFA` |
| `promoGradientStart/End` | `#D9C9EE` → `#FFD3D8` | `#3B3357` → `#5A3648` |
| `surface` | `#FFFFFF` @ 0.85 | `#1E1E1E` @ 0.85 |
| `onAccent` | `#FFFFFF` | `#1B1522` |

Feature fills (also the `chipFill` set): `tasks` `#D6E4F5`,
`shopping` `#D9EBD9`, `meals` `#FBE3CF`, `pets` `#F6D9E0`, `stock` `#E4DCF3`.

Verified: `onAccent` white on `accent` `#F0607A` = **3.2:1** (≥ 3:1, large/glyph
only). `accentInk` `#B93A55` on `canvasTop` = **4.6:1**; on `accentWash` `#FCE4E7`
= **4.6:1**. `secondaryInk` `#6D5196` on `secondarySoft` `#E7E0F5` = **5.0:1**.
`promoInk` `#2B1450` on the gradient ends = **10.3:1** / **11.8:1**. In dark,
`accentInk` `#F58AA0` on `canvasTop` `#1B1522` = **7.8:1**.

**Home's `accentSoft` is not the reference's wash.** `#E8A090` is the app's
previous accent, kept as the chip-selected / tinted-button fill, and it sits far
more saturated than the reference's L ≈ 94 % wash. Home therefore carries **both**:
`accentSoft` `#E8A090` for the legacy tint and `accentWash` `#FCE4E7` for the
twin-button role that `#FDE1E8` fills in Instance A. Do not put small text on
`accentSoft` — `accentInk` on `#E8A090` is only **2.6:1**. `secondaryInk`,
`secondarySoft` and `promoInk` are derived here, not measured: Home ships no
gradient card yet.

## 7. Dark mode is derived

The reference is light-only — every dark value in this file was derived, not
measured. That means:

- Treat dark hexes as a starting point, then **re-run §4 against your real
  composites** before shipping. A derived value that fails is a bug, not a style
  choice.
- Dark canvas stops keep the hue and drop to L ≈ 8–13 %. Do not use a neutral
  grey ramp — the wash is the whole identity.
- The accent *lightens* in dark (`#FF4476` → `#FF7D9E`); it does not stay put.
  A saturated light-mode accent on a near-black canvas glows and fails 3:1 for
  `onAccent` in the other direction.
- `chipFill` and `tileFill` in dark are not the light fills darkened uniformly —
  they are near-canvas surfaces at L ≈ 17–20 % that still differ from each other
  by category.
