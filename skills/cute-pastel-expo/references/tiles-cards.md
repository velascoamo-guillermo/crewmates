# TileGrid and PressableCard

## Tile

A 64 pt `tileFill` circle with a 26 pt glyph, 8 pt gap, then a 13 pt `ink`
label up to two lines, centred. The circle *is* the radius (32 = 64 / 2).
Circle and label are one button; the glyph is decorative.

```tsx
// components/Tile.tsx
import { Text, View } from 'react-native';
import Animated, {
  ReduceMotion,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
} from 'react-native-reanimated';
import { Pressable } from 'react-native';

import { layout } from '../theme/layout';
import { makeStyles } from '../theme/tokens';

export type TileProps = {
  label: string;
  glyph: string;
  onPress: () => void;
};

const spring = { ...layout.spring, reduceMotion: ReduceMotion.System };

export function Tile({ label, glyph, onPress }: TileProps) {
  const styles = useStyles();
  const scale = useSharedValue(1);
  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return (
    <Pressable
      onPressIn={() => {
        scale.value = withSpring(layout.pressScale.surface, spring);
      }}
      onPressOut={() => {
        scale.value = withSpring(1, spring);
      }}
      onPress={onPress}
      style={styles.slot}
      accessibilityRole="button"
      accessibilityLabel={label}
    >
      {/* Circle and label scale together, as one object. */}
      <Animated.View style={[styles.inner, animatedStyle]}>
        <View style={styles.circle}>
          <Text style={styles.glyph} accessibilityElementsHidden>
            {glyph}
          </Text>
        </View>
        <Text style={styles.label} numberOfLines={2}>
          {label}
        </Text>
      </Animated.View>
    </Pressable>
  );
}

const useStyles = makeStyles((t) => ({
  slot: { flexBasis: '31%', flexGrow: 0 },
  inner: { alignItems: 'center', gap: layout.space.sm },
  circle: {
    width: layout.size.tile,
    height: layout.size.tile,
    borderRadius: layout.radius.tile,
    backgroundColor: t.tileFill,
    alignItems: 'center',
    justifyContent: 'center',
  },
  glyph: { fontSize: 26 },
  label: { ...layout.type.caption, color: t.ink, textAlign: 'center' },
}));
```

## TileGrid

Always **inside a white card**, never directly on the canvas. Three columns,
16 pt both axes.

```tsx
// components/TileGrid.tsx
import { View } from 'react-native';

import { Tile, type TileProps } from './Tile';
import { layout } from '../theme/layout';
import { makeStyles } from '../theme/tokens';

export type TileGridProps = {
  tiles: readonly TileProps[];
};

export function TileGrid({ tiles }: TileGridProps) {
  const styles = useStyles();
  return (
    <View style={styles.card}>
      <View style={styles.grid}>
        {tiles.map((tile) => (
          <Tile key={tile.label} {...tile} />
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
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: layout.gap.tiles,
    justifyContent: 'flex-start',
  },
}));
```

`flexBasis: '31%'` + `gap: 16` gives three per row with the gaps absorbed, and —
unlike `width: '33.33%'` — a short last row stays left-aligned instead of
stretching. `space-between` would scatter a row of two.

**Escape hatch:** a grid of dozens of tiles belongs in a
`FlatList numColumns={3}` with `columnWrapperStyle={{ gap: layout.gap.tiles }}`
so it virtualises. For the handful this language shows in a card, `flexWrap`
is lighter and avoids nesting a list inside a scroll view.

## PressableCard

```tsx
// components/PressableCard.tsx
import type { ReactNode } from 'react';
import { Platform, Pressable } from 'react-native';
import Animated, {
  ReduceMotion,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
} from 'react-native-reanimated';

import { layout } from '../theme/layout';
import { makeStyles } from '../theme/tokens';

export type PressableCardProps = {
  children: ReactNode;
  onPress: () => void;
  accessibilityLabel: string;
};

const spring = { ...layout.spring, reduceMotion: ReduceMotion.System };

export function PressableCard({
  children,
  onPress,
  accessibilityLabel,
}: PressableCardProps) {
  const styles = useStyles();
  const scale = useSharedValue(1);
  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return (
    <Pressable
      onPressIn={() => {
        scale.value = withSpring(layout.pressScale.surface, spring);
      }}
      onPressOut={() => {
        scale.value = withSpring(1, spring);
      }}
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
    >
      <Animated.View style={[styles.card, animatedStyle]}>{children}</Animated.View>
    </Pressable>
  );
}

const useStyles = makeStyles((t) => ({
  card: {
    backgroundColor: t.surface,
    borderRadius: layout.radius.card,
    padding: layout.pad.card,
    ...Platform.select({
      // elevation alone renders a black shadow heavier than 6 %.
      android: { elevation: 2, shadowColor: '#000000' },
      default: layout.shadow.card,
    }),
  },
}));
```

- **Scale the card, never its shadow.** Animating `elevation` or `shadowRadius`
  re-renders the shadow every frame; a transform is free.
- A card shadow above 8 % greys out the pastel, and the card shadow is never
  tinted — the accent-tinted glow belongs to the one FAB / centre action.
- `overflow: 'hidden'` only if a child image needs clipping; it costs a layer.

## Common mistakes

| Mistake | Fix |
|---|---|
| Tile grid directly on the canvas | Inside a `surface` card, radius 20 |
| `width: '33.33%'` or `space-between` | `flexBasis: '31%'` + `gap: 16` |
| Separate buttons for circle and label | One `Pressable`, label is the name |
| Glyph announced by the screen reader | `accessibilityElementsHidden` |
| Press scale on the circle only | Scale the whole tile |
| Animating `elevation` / `shadowRadius` | Animate `transform` |
| `elevation` with no `shadowColor` on Android | Set both |
| A gradient on the card | The canvas owns the gradient |
