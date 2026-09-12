# tokens.ts — typed roles, both schemes

One module per app, alongside `layout.ts`. The theme module is the only place
in the codebase allowed to contain a colour literal.

**The values are not here.** Roles are typed here; the palette, its derivation
rules and the binding contrast criteria live in the `cute-pastel-style` skill
(`references/tokens.md` — §1–2 derivation, §3 schema, §4 contrast, §5
Instance A, §6 Instance B, §7 dark). Copy the instance you need
from there, or derive a new one from §1–2 and re-run §4 in **both** schemes
before shipping.

## 1. Types

```ts
// theme/tokens.ts
import { useMemo } from 'react';
import { StyleSheet, useColorScheme } from 'react-native';

/** One pastel per content category — chips, tiles, list glyph circles. */
export type FeatureKey = 'tasks' | 'shopping' | 'meals' | 'pets' | 'stock';

export type Tokens = {
  /** Canvas gradient, stops 0 / 0.45 / 1. */
  canvasTop: string;
  canvasMid: string;
  canvasBottom: string;
  /** Cards, rows, sheets — flat, carries its own 0.85 alpha. Never material. */
  surface: string;
  /** Hero numeral, FAB, centre tab action, selected-chip stroke, one CTA. */
  accent: string;
  /** Legacy/saturated accent tint: chip-selected fill, tinted button. */
  accentSoft: string;
  /** Accent-hue wash (L ≈ 94 %): twin button, selected-tab pill. */
  accentWash: string;
  /** Accent-coloured *text* on the canvas. Never `accent` itself. */
  accentInk: string;
  /** Label or glyph on an accent fill — large/bold or glyph only. */
  onAccent: string;
  /** Violet secondary action, so secondary CTAs don't spend the accent budget. */
  secondaryInk: string;
  secondarySoft: string;
  /** Text on a gradient card — must clear 4.5:1 on *both* gradient ends. */
  promoInk: string;
  promoGradientStart: string;
  promoGradientEnd: string;
  ink: string;
  inkSecondary: string;
  /** Chip background, keyed by category. The fill survives selection. */
  chipFill: Record<FeatureKey, string>;
  /** Tile / list-row glyph circle — one step deeper than `chipFill`. */
  tileFill: string;
};
```

`Record<FeatureKey, string>` is the point: a chip takes a `FeatureKey`, not a
colour, so a new category is a compile error until its fill exists.

## 2. Instances

Below is **Instance A, copied verbatim from the `cute-pastel-style` skill
(`references/tokens.md`, §3/§5)** as a filled-in example of the shape. It is
not the authority — that skill is, and it is where you check a value or pick
Instance B (Home peach/coral).

```ts
const light: Tokens = {
  canvasTop: '#E6DDF4',
  canvasMid: '#F4E5F5',
  canvasBottom: '#FFEEF0',
  surface: 'rgba(252, 249, 250, 0.85)', // #FCF9FA @ 85 %
  accent: '#FF4476',
  accentSoft: '#FDE1E8',
  accentWash: '#FDE1E8',
  accentInk: '#BE0B51',
  onAccent: '#FFFFFF',
  secondaryInk: '#6D5196',
  secondarySoft: '#E0DFFE',
  promoInk: '#2A0E5C',
  promoGradientStart: '#C1B5E7',
  promoGradientEnd: '#FEC8DC',
  ink: '#2A2430',
  inkSecondary: '#645C6D',
  chipFill: {
    tasks: '#ECE3F8',
    shopping: '#E7F5E9',
    meals: '#FFF0E8',
    pets: '#FFE9F1',
    stock: '#FFD1DF',
  },
  tileFill: '#FFE2E9',
};

const dark: Tokens = {
  canvasTop: '#1A1626',
  canvasMid: '#221823',
  canvasBottom: '#121212',
  surface: 'rgba(30, 30, 30, 0.85)', // #1E1E1E @ 85 %
  accent: '#FF7D9E',
  accentSoft: '#3A2430',
  accentWash: '#3A2430',
  accentInk: '#FF9FB8',
  onAccent: '#1A1626',
  secondaryInk: '#C4B0E4',
  secondarySoft: '#2A2740',
  promoInk: '#F0EAFA',
  promoGradientStart: '#3B3357',
  promoGradientEnd: '#5A3648',
  ink: '#F4EFF6',
  inkSecondary: '#B4AABF',
  chipFill: {
    tasks: '#2A2740',
    shopping: '#1F2B22',
    meals: '#332A22',
    pets: '#2E2330',
    stock: '#3A2430',
  },
  tileFill: '#33262D',
};
```

Instance A ships light-only in the reference; the dark column is **derived, not
measured** (style §7). Re-run the §4 contrast checks against your real
composites before shipping dark — `surface` is translucent, so the canvas leaks
through and `ink`-on-opaque-white passes while the shipped screen fails.

Three things use pure `#FFFFFF` rather than `surface`, in both schemes: the
floating tab-bar pill, the primary pill button on the canvas, and the circular
header button. Give that its own role if you use it more than once.

## 3. `useTokens()`

```ts
export function useTokens(): Tokens {
  return useColorScheme() === 'dark' ? dark : light;
}
```

`useColorScheme` from `react-native` (not from `react-native-appearance`, not a
context you hand-roll) — it re-renders on a system theme change. Module-level
`light` / `dark` means the returned object identity is stable, which is what
makes the memoisation below a two-entry cache instead of a leak.

Do not add a `ThemeProvider` unless the app genuinely needs a
user-overridable theme; if it does, keep `useTokens()` as the single read
point and swap its body.

## 4. `makeStyles` — memoised, scheme-aware

`StyleSheet.create` inside a component body runs every render. Hoisting it out
loses the tokens. This pattern gives you both:

```ts
type Factory<T> = (t: Tokens) => T;

export function makeStyles<T extends StyleSheet.NamedStyles<T>>(
  factory: Factory<T>,
): () => T {
  const cache = new WeakMap<Tokens, T>();
  return function useThemedStyles(): T {
    const t = useTokens();
    return useMemo(() => {
      const hit = cache.get(t);
      if (hit) return hit;
      const created = StyleSheet.create(factory(t));
      cache.set(t, created);
      return created;
    }, [t]);
  };
}
```

Call site:

```ts
const useStyles = makeStyles((t) => ({
  card: {
    backgroundColor: t.surface,
    borderRadius: layout.radius.card,
    padding: layout.pad.card,
    ...layout.shadow.card,
  },
}));

// in the component
const styles = useStyles();
const t = useTokens(); // only for props that aren't styles (gradient colours, icon tint)
```

## 5. `layout` — the numbers, typed

Mirrors the `cute-pastel-style` skill (`references/layout.md`). pt ≡ dp ≡ RN
unit.

```ts
// theme/layout.ts
import type { TextStyle, ViewStyle } from 'react-native';

export const layout = {
  space: { xs: 4, sm: 8, md: 12, gutter: 16, lg: 20, section: 24 },
  /** Inner paddings only — never a gap between siblings. */
  pad: { card: 18, row: 14, hero: 12 },
  gap: { cards: 12, rows: 10, chips: 8, tiles: 16 },
  radius: { card: 20, row: 16, pill: 999, tile: 32, sheet: 24, field: 12 },
  size: { tile: 64, tabAction: 44, fab: 56, minTouch: 44 },
  type: {
    hero: { fontSize: 56, fontWeight: '700', fontVariant: ['tabular-nums'] },
    heroUnit: { fontSize: 20, fontWeight: '700' },
    title: { fontSize: 22, fontWeight: '600' },
    section: { fontSize: 17, fontWeight: '600' },
    body: { fontSize: 15, fontWeight: '400' },
    chip: { fontSize: 15, fontWeight: '500' },
    caption: { fontSize: 13, fontWeight: '400' },
    tab: { fontSize: 10, fontWeight: '500' },
  },
  shadow: {
    /** black 6 %, r6, y2 — cards, rows, tab bar, white pills, segmented thumb. */
    card: {
      shadowColor: '#000000',
      shadowOpacity: 0.06,
      shadowRadius: 6,
      shadowOffset: { width: 0, height: 2 },
      elevation: 2,
    },
  },
  /** Reanimated spring ≈ response 0.3 / damping 0.7. */
  spring: { duration: 300, dampingRatio: 0.7 },
  pressScale: { surface: 0.97, chip: 0.96 },
} as const satisfies {
  type: Record<string, TextStyle>;
  shadow: Record<string, ViewStyle>;
  [k: string]: unknown;
};
```

The FAB / centre-action shadow is the one accent-tinted shadow in the language
and needs a token, so it lives with the component that owns it
(`references/navigation.md`) — `shadowColor: t.accent, shadowOpacity: 0.3,
shadowRadius: 10, y +4`.

**Android shadows.** `elevation` alone renders a black, heavier shadow than
6 %. Set `shadowColor` **and** on API 28+ the tint props:

```ts
Platform.select({
  android: { elevation: 2, shadowColor: '#000000' },
  default: layout.shadow.card,
});
```

`fontVariant: ['tabular-nums']` on the hero is not optional — without it the
numeral's width jumps as digits change and the whole block reflows.

## Common mistakes

| Mistake | Fix |
|---|---|
| Tokens named by hue (`pinkLight`, `lavender`, `sky`) | Name the **role**. A call site must not be able to pick a hue. |
| Light-only token object | `light` + `dark` + `useTokens()`, from day one. A retrofit touches every file. |
| `chipFill` as a single string | `Record<FeatureKey, string>` — the fill encodes category. |
| A hex at a call site, `'#FFFFFF'` included | Add the role. |
| `as const` on the token objects | Type them `Tokens`, so a missing role is an error and the values stay `string`. |
| `StyleSheet.create` in the component body | `makeStyles` |
