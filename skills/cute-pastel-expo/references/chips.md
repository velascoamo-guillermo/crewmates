# Chip and ChipGroup

A chip is a 36 pt pill (padding 14 / 9) whose fill is the **category** colour.
Selection is **additive**: a 2 pt `accent` stroke plus a 14 pt trailing check
badge. **The fill does not change.**

> This is the rule agents break most. Swapping the fill to the accent deletes
> the category information exactly when the user acts on it, and blows the
> accent budget the moment two chips are selected. Lowering the opacity of the
> accent fill does not un-break it.

## Chip

```tsx
// components/Chip.tsx
import { Presets } from 'react-native-pulsar';
import { Pressable, Text, View } from 'react-native';
import Animated, {
  ReduceMotion,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
} from 'react-native-reanimated';

import { layout } from '../theme/layout';
import { makeStyles, useTokens, type FeatureKey } from '../theme/tokens';

export type ChipProps = {
  label: string;
  /** Selects the `chipFill` — the fill is the category, so this is required. */
  category: FeatureKey;
  /** Emoji or icon that *leads* the label; it never replaces it. */
  glyph?: string;
  selected: boolean;
  disabled?: boolean;
  onPress: () => void;
};

const spring = { ...layout.spring, reduceMotion: ReduceMotion.System };

export function Chip({
  label,
  category,
  glyph,
  selected,
  disabled = false,
  onPress,
}: ChipProps) {
  const t = useTokens();
  const styles = useStyles();
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return (
    <Pressable
      onPressIn={() => {
        scale.value = withSpring(layout.pressScale.chip, spring);
      }}
      onPressOut={() => {
        scale.value = withSpring(1, spring);
      }}
      onPress={() => {
        // Fire at the causal moment, in the press handler on the RN runtime.
        Presets.System.selection();
        onPress();
      }}
      disabled={disabled}
      hitSlop={4} // 36 pt visual + 4 top/bottom = 44 pt target
      accessibilityRole="button"
      accessibilityState={{ selected, disabled }}
      accessibilityLabel={label}
    >
      <Animated.View
        style={[
          styles.chip,
          { backgroundColor: t.chipFill[category] },
          selected && styles.chipSelected,
          disabled && styles.chipDisabled,
          animatedStyle,
        ]}
      >
        {glyph !== undefined ? (
          <Text style={styles.glyph} accessibilityElementsHidden>
            {glyph}
          </Text>
        ) : null}
        <Text style={styles.label}>{label}</Text>
        {selected ? (
          <View style={styles.badge}>
            <Text style={styles.badgeGlyph}>✓</Text>
          </View>
        ) : null}
      </Animated.View>
    </Pressable>
  );
}

const useStyles = makeStyles((t) => ({
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 14,
    paddingVertical: 9,
    borderRadius: layout.radius.pill,
    // Reserve the stroke in both states so selecting doesn't resize the chip.
    borderWidth: 2,
    borderColor: 'transparent',
  },
  chipSelected: { borderColor: t.accent },
  chipDisabled: { opacity: 0.4 },
  glyph: { fontSize: 18 },
  label: { ...layout.type.chip, color: t.ink },
  badge: { width: 14, height: 14, alignItems: 'center', justifyContent: 'center' },
  badgeGlyph: { fontSize: 12, lineHeight: 14, color: t.accent },
}));
```

Why each piece is the way it is:

- **`borderWidth: 2` with a transparent colour in both states.** Adding the
  border only when selected changes the chip's size and reflows the whole
  wrapping group.
- **`hitSlop`, not padding.** The 36 pt visual height is part of the look; the
  44 pt minimum is met by expanding the touch target.
- **`accessibilityState={{ selected }}`** is mandatory — the stroke and badge
  are the visual redundancy, the state is the programmatic one. Colour alone
  never carries selection.
- **The glyph is decorative**: hide it, and make sure the label carries its
  meaning ("Mucha energía", not "⚡").
- **Haptic in `onPress`,** once per action, never in `onPressIn` as well.
  Pulsar presets are worklets, so they can also be called from inside a
  worklet — but a chip's selection is a JS-side event, so the press handler is
  the right place. Check the current preset names in the installed types or at
  docs.swmansion.com/pulsar before writing them; `Presets.System.selection` is
  the shape at the time of writing, not a frozen API.
- The haptic is never the only feedback: it is off system-wide for many users
  and silent on much Android hardware.

**Press feedback alternative.** On Reanimated 4 a two-state press scale can be
a CSS transition (`transitionProperty: 'transform'`) instead of a shared value,
which is cheaper and shorter. Either is fine; RN `Animated` is not.

## ChipGroup

Generic over the option's value so a selection is typed, not stringly-typed.

```tsx
// components/ChipGroup.tsx
import { Text, View } from 'react-native';

import { Chip } from './Chip';
import { layout } from '../theme/layout';
import { makeStyles, type FeatureKey } from '../theme/tokens';

export type ChipOption<T> = {
  value: T;
  label: string;
  glyph?: string;
  category: FeatureKey;
};

export type ChipGroupProps<T> = {
  title: string;
  options: readonly ChipOption<T>[];
  selected: readonly T[];
  /** `single` clears the others; `multiple` toggles. */
  mode?: 'single' | 'multiple';
  onChange: (next: readonly T[]) => void;
};

export function ChipGroup<T extends string | number>({
  title,
  options,
  selected,
  mode = 'single',
  onChange,
}: ChipGroupProps<T>) {
  const styles = useStyles();

  const toggle = (value: T): void => {
    if (mode === 'single') {
      onChange(selected.includes(value) ? [] : [value]);
      return;
    }
    onChange(
      selected.includes(value)
        ? selected.filter((v) => v !== value)
        : [...selected, value],
    );
  };

  return (
    <View
      style={styles.card}
      // `role`, not `accessibilityRole`: RN's AccessibilityRole union has no
      // 'group' member (it is ARIA-only) and 'group' there is a type error.
      role={mode === 'single' ? 'radiogroup' : 'group'}
      accessibilityLabel={title}
    >
      <Text style={styles.title}>{title}</Text>
      <View style={styles.wrap}>
        {options.map((option) => (
          <Chip
            key={String(option.value)}
            label={option.label}
            glyph={option.glyph}
            category={option.category}
            selected={selected.includes(option.value)}
            onPress={() => toggle(option.value)}
          />
        ))}
      </View>
    </View>
  );
}

const useStyles = makeStyles((t) => ({
  card: {
    backgroundColor: t.surface,
    borderRadius: layout.radius.card,
    padding: layout.pad.card,
    ...layout.shadow.card,
  },
  title: { ...layout.type.section, color: t.ink, marginBottom: layout.space.md },
  wrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: layout.gap.chips, // both axes, 8
  },
}));
```

- **`flexWrap: 'wrap'` + `gap`.** Chips wrap; they never live in a horizontal
  `ScrollView` (that hides options and fights the page scroll), and spacing is
  `gap`, not `marginRight`/`marginBottom` — margins leave a trailing gutter on
  the last row.
- **The card is the group boundary**, with the title as its accessible label,
  so a screen reader announces the group before the chips. Set it via the
  `role` prop — `'radiogroup'` for `single`, `'group'` for `multiple`.
  `accessibilityRole` accepts `'radiogroup'` but **not** `'group'`, so mixing
  the two props is what forces an `as any`. Verified against
  `react-native`'s `AccessibilityRole` / `Role` types.
- Keep selection state in the parent (or a form library). The chip is
  presentational.

## Common mistakes

| Mistake | Fix |
|---|---|
| Selected chip changes `backgroundColor` | Keep `chipFill`; add stroke + badge |
| Border added only when selected | `borderWidth: 2` always, colour `transparent` |
| `expo-haptics` | `react-native-pulsar` |
| Haptic in `onPressIn` *and* `onPress` | Once, in `onPress` |
| Press scale 0.9 / 0.92 | `layout.pressScale.chip` = 0.96 |
| Horizontal scrolling chip row | `flexWrap: 'wrap'` |
| `marginRight` + `marginBottom` | `gap: 8` |
| No `accessibilityState` | `{{ selected, disabled }}` |
| `accessibilityRole="group"` on the group | Not a valid RN role — use `role="group"` |
| Emoji as the whole chip | Glyph leads a 15 pt label |
