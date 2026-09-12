# HeroHeader — the big numeral

Three lines, centred, and the block never collapses: caption 13 pt `accentInk`,
numeral 56 pt bold rounded `accent` (+ optional 20 pt unit, baseline-aligned),
subline 15 pt `inkSecondary`. Empty state keeps all three slots with an em dash
in `inkSecondary`, so the screen doesn't reflow when data arrives.

## Default — spring scale-pop on change

```tsx
// components/HeroHeader.tsx
import { useEffect } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  ReduceMotion,
  useAnimatedStyle,
  useReducedMotion,
  useSharedValue,
  withSequence,
  withSpring,
} from 'react-native-reanimated';

import { layout } from '../theme/layout';
import { makeStyles } from '../theme/tokens';

export type HeroHeaderProps = {
  /** Short state label above the numeral, e.g. "Día del ciclo". */
  label: string;
  /** `null` renders the em-dash empty state without collapsing the block. */
  value: number | null;
  /** Optional unit, baseline-aligned to the numeral. */
  unit?: string;
  /** One line. Never two. */
  subline?: string;
  /** Full sentence for assistive tech; the three lines are one element. */
  accessibilityLabel: string;
};

export function HeroHeader({
  label,
  value,
  unit,
  subline,
  accessibilityLabel,
}: HeroHeaderProps) {
  const styles = useStyles();
  const reduced = useReducedMotion();
  const scale = useSharedValue(1);

  useEffect(() => {
    if (value === null || reduced) return;
    scale.value = withSequence(
      withSpring(1.06, { ...layout.spring, reduceMotion: ReduceMotion.System }),
      withSpring(1, { ...layout.spring, reduceMotion: ReduceMotion.System }),
    );
  }, [value, reduced, scale]);

  const pop = useAnimatedStyle(() => ({ transform: [{ scale: scale.value }] }));

  return (
    <View
      style={styles.root}
      accessible
      accessibilityRole="header"
      accessibilityLabel={accessibilityLabel}
    >
      <Text style={styles.caption}>{label}</Text>
      <Animated.View style={[styles.numeralRow, pop]}>
        <Text style={styles.numeral} allowFontScaling={false}>
          {value === null ? '—' : value}
        </Text>
        {unit !== undefined && value !== null ? (
          <Text style={styles.unit}>{unit}</Text>
        ) : null}
      </Animated.View>
      {subline !== undefined ? <Text style={styles.subline}>{subline}</Text> : null}
    </View>
  );
}

const useStyles = makeStyles((t) => ({
  root: { alignItems: 'center', paddingVertical: layout.pad.hero, gap: 2 },
  caption: { ...layout.type.caption, color: t.accentInk },
  numeralRow: { flexDirection: 'row', alignItems: 'baseline', gap: 4 },
  numeral: { ...layout.type.hero, color: t.accent },
  unit: { ...layout.type.heroUnit, color: t.accent },
  subline: { ...layout.type.body, color: t.inkSecondary },
}));
```

Notes that matter:

- **`fontVariant: ['tabular-nums']`** comes in via `layout.type.hero`. Without
  it the numeral's width jumps between values and the row jitters.
- **Rounded face.** `fontFamily: 'SF Pro Rounded'` on iOS; ship Nunito (or
  another rounded face) via `expo-font` for Android parity and set it in
  `layout.type.hero` once.
- **`allowFontScaling={false}` only on the 56 pt numeral** — it is already far
  above body size and a 200 % scale breaks the layout. Every other line scales.
- **The three lines are one accessibility element.** Announcing "1" alone is
  useless; pass the whole sentence. `accessible` on the parent collapses the
  children.
- Scale-pop is the *default* because it is one transform on the UI runtime and
  survives any value shape (numbers, `—`, formatted strings).

## Variant — digit-wise animation

The style language asks for a digit-wise numeric transition rather than a
crossfade of the whole string. Drive the native `text` prop from the UI runtime
so no React render happens per frame:

```tsx
import { TextInput, type TextInputProps } from 'react-native';
import Animated, { useAnimatedProps } from 'react-native-reanimated';

const AnimatedTextInput = Animated.createAnimatedComponent(TextInput);

const animated = useSharedValue(value ?? 0);
useEffect(() => {
  animated.value = withSpring(value ?? 0, layout.spring);
}, [value, animated]);

const animatedProps = useAnimatedProps<TextInputProps>(() => ({
  text: String(Math.round(animated.value)),
}));

<AnimatedTextInput
  editable={false}
  caretHidden
  defaultValue={String(value ?? 0)}
  animatedProps={animatedProps}
  style={styles.numeral}
  accessibilityElementsHidden // the parent View carries the label
/>;
```

- Type the hook as `useAnimatedProps<TextInputProps>` and the `text` key
  typechecks. If you find yourself writing `as unknown as { text: string }`,
  the generic is missing.
- `text` is whitelisted for `TextInput` out of the box in Reanimated 3/4 —
  `addWhitelistedNativeProps` is legacy; don't call it.
- Cost: an interpolated counter is not digit-wise per se — it rolls through
  intermediate values. Use it when the value is a continuous quantity
  (weight, minutes, a total). For a day counter that steps by 1, the scale-pop
  default is the better read.

## Reduced motion

`useReducedMotion()` guards the effect and `ReduceMotion.System` guards each
spring — belt and braces, because the hook value is captured at render while
the flag can change. Reduced motion means **gentler, not absent**: the value
still changes colour and content, only the scale is dropped.

## Common mistakes

| Mistake | Fix |
|---|---|
| 64 pt (or "roughly 60") | 56, from `layout.type.hero` |
| No tabular figures | `fontVariant: ['tabular-nums']` |
| Crossfading the whole string | Scale-pop, or the `animatedProps` counter |
| Collapsing the block when empty | Em dash at 56 pt in `inkSecondary` |
| Announcing the bare number | One combined `accessibilityLabel` on the parent |
| `addWhitelistedNativeProps({ text: true })` | Not needed; drop it |
| A spring in `{ damping, stiffness, mass }` form | `{ duration, dampingRatio }` from `layout.spring` |
