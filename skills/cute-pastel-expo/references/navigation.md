# FloatingTabBar — pill bar with a raised centre action

A pure white pill, radius 999, inset 16 from the screen edges, floating 8 above
the bottom safe-area inset, card shadow. Five items with 22 pt glyphs and
**10 pt labels**. The centre item is a raised 44 pt `accent` circle whose centre
breaks the pill's top edge — and it is a **button that opens a modal, not a
tab**.

## Wiring

```tsx
// app/(tabs)/_layout.tsx
import { Tabs } from 'expo-router';

import { FloatingTabBar } from '../../components/FloatingTabBar';

export default function TabsLayout() {
  return (
    <Tabs
      tabBar={(props) => <FloatingTabBar {...props} />}
      screenOptions={{ headerTransparent: true, sceneStyle: { backgroundColor: 'transparent' } }}
    >
      <Tabs.Screen name="index" options={{ title: 'Hoy' }} />
      <Tabs.Screen name="calendar" options={{ title: 'Calendario' }} />
      <Tabs.Screen name="insights" options={{ title: 'Datos' }} />
      <Tabs.Screen name="profile" options={{ title: 'Perfil' }} />
    </Tabs>
  );
}
```

Four routes, five slots: the centre action is **not a route**. The modal lives
in the root stack, outside the tabs group:

```tsx
// app/_layout.tsx (inside the Stack)
<Stack.Screen name="log" options={{ presentation: 'modal', title: 'Registrar' }} />
```

## The bar

```tsx
// components/FloatingTabBar.tsx
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';
import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { Presets } from 'react-native-pulsar';
import { Pressable, Text, View } from 'react-native';
import Animated, {
  ReduceMotion,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { layout } from '../theme/layout';
import { makeStyles, useTokens } from '../theme/tokens';

const GLYPHS: Record<string, keyof typeof Ionicons.glyphMap> = {
  index: 'heart-outline',
  calendar: 'calendar-outline',
  insights: 'stats-chart-outline',
  profile: 'person-outline',
};

/** Slot index the centre action occupies in the five-slot pill. */
const CENTRE_SLOT = 2;
const spring = { ...layout.spring, reduceMotion: ReduceMotion.System };

export function FloatingTabBar({ state, descriptors, navigation }: BottomTabBarProps) {
  const t = useTokens();
  const styles = useStyles();
  const insets = useSafeAreaInsets();

  const items = state.routes.map((route, index) => {
    const { options } = descriptors[route.key];
    const focused = state.index === index;
    const label =
      typeof options.title === 'string' ? options.title : route.name;

    return (
      <Pressable
        key={route.key}
        onPress={() => {
          const event = navigation.emit({
            type: 'tabPress',
            target: route.key,
            canPreventDefault: true,
          });
          if (!focused && !event.defaultPrevented) {
            navigation.navigate(route.name);
          }
        }}
        style={styles.item}
        hitSlop={8}
        accessibilityRole="tab"
        accessibilityState={{ selected: focused }}
        accessibilityLabel={label}
      >
        <View style={[styles.itemInner, focused && styles.itemInnerSelected]}>
          <Ionicons
            name={GLYPHS[route.name] ?? 'ellipse-outline'}
            size={22}
            color={focused ? t.accent : t.inkSecondary}
          />
          <Text style={[styles.label, focused && styles.labelSelected]} numberOfLines={1}>
            {label}
          </Text>
        </View>
      </Pressable>
    );
  });

  const slots = [...items];
  slots.splice(CENTRE_SLOT, 0, <CentreAction key="centre" />);

  return (
    <View
      pointerEvents="box-none"
      style={[styles.wrapper, { bottom: insets.bottom + layout.space.sm }]}
    >
      <View style={styles.pill}>{slots}</View>
    </View>
  );
}

function CentreAction() {
  const styles = useStyles();
  const t = useTokens();
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
        Presets.System.impactLight();
        router.push('/log');
      }}
      style={styles.item}
      hitSlop={8}
      // A button, not a tab: it opens a sheet, it does not select a page.
      accessibilityRole="button"
      accessibilityLabel="Registrar"
    >
      <View style={styles.centreColumn}>
        <Animated.View
          style={[
            styles.centreCircle,
            {
              backgroundColor: t.accent,
              shadowColor: t.accent,
              shadowOpacity: 0.3,
              shadowRadius: 10,
              shadowOffset: { width: 0, height: 4 },
              elevation: 6,
            },
            animatedStyle,
          ]}
        >
          <Ionicons name="add" size={20} color={t.onAccent} />
        </Animated.View>
        <Text style={styles.label}>Registrar</Text>
      </View>
    </Pressable>
  );
}

export const FLOATING_TAB_BAR_HEIGHT = 64;

const useStyles = makeStyles((t) => ({
  wrapper: {
    position: 'absolute',
    left: layout.space.gutter,
    right: layout.space.gutter,
  },
  pill: {
    flexDirection: 'row',
    alignItems: 'center',
    height: FLOATING_TAB_BAR_HEIGHT,
    paddingHorizontal: layout.space.sm,
    borderRadius: layout.radius.pill,
    // Opaque white, not `surface`: the bar must read as an object floating
    // over the gradient. A blurred/material bar breaks rule 2.
    backgroundColor: '#FFFFFF',
    ...layout.shadow.card,
  },
  item: { flex: 1 },
  itemInner: {
    alignItems: 'center',
    gap: 2,
    paddingVertical: 6,
    borderRadius: layout.radius.pill,
  },
  itemInnerSelected: { backgroundColor: t.accentWash },
  label: { ...layout.type.tab, color: t.inkSecondary, textAlign: 'center' },
  labelSelected: { color: t.accent },
  centreColumn: { alignItems: 'center', gap: 2 },
  centreCircle: {
    width: layout.size.tabAction,
    height: layout.size.tabAction,
    borderRadius: layout.size.tabAction / 2,
    alignItems: 'center',
    justifyContent: 'center',
    // Lift it so its centre breaks the pill's top edge.
    marginTop: -layout.size.tabAction / 2,
  },
}));
```

`#FFFFFF` at that one call site is the exception the `cute-pastel-style` skill
names (the
tab-bar pill, the primary pill button, the circular header button). If it
appears twice, promote it to a token.

## Content inset

A custom `tabBar` is absolutely positioned, so nothing reserves space for it.
Every scrollable screen inside the group pads for it:

```tsx
const insets = useSafeAreaInsets();
const bottomPad =
  insets.bottom + layout.space.sm + FLOATING_TAB_BAR_HEIGHT + layout.space.md;
```

## Variant — five routes with a prevented default

Use this only when the centre action must be deep-linkable or the analytics
layer keys off a route. Add a placeholder route and stop it navigating:

```tsx
<Tabs.Screen
  name="log-placeholder"
  options={{ title: 'Registrar' }}
  listeners={{
    tabPress: (e) => {
      e.preventDefault();
      router.push('/log');
    },
  }}
/>
```

Trade-off: the phantom route file must exist and will render if anything
navigates to it directly, and `state.routes` now has five entries so the bar's
slot maths changes. The four-route version above has no phantom state.

## Alternative — native tab bar + FAB

The platform's own bar, untouched, with a 56 pt `accent` circle FAB overlaid
bottom-trailing (20 from the trailing edge, 16 above the bar's top edge, glyph
22 pt `onAccent`, accent shadow 30 % / r10 / y4 — the only accent-tinted shadow
in the language).

```tsx
import { NativeTabs } from 'expo-router/unstable-native-tabs';
```

| | Floating pill bar | Native tabs + FAB |
|---|---|---|
| Look | The reference look, exactly | Platform bar; pastel only above it |
| Per-tab state restoration, iOS 26 search-role tabs, Android predictive back | Rebuilt by hand | Free |
| Accessibility | Yours to get right (roles, states, focus order) | Platform-correct by default |
| Landscape / tablet / large text | You handle every case | Handled |
| Centre action | In the bar | A FAB, hidden while a sheet is presented |

Recommendation: ship the floating pill bar when the bar is part of the product's
identity (it is, in this language) and the app has four or five flat peer tabs.
Switch to native tabs + FAB as soon as you need the platform behaviours in row
two — the look is a small loss next to reimplementing tab state restoration.

## Common mistakes

| Mistake | Fix |
|---|---|
| Centre item registered as a tab | `accessibilityRole="button"`; it opens a modal |
| Icon-only centre button | 10 pt label below it, like every other item |
| No `accessibilityRole`/`State` on items | `"tab"` + `{{ selected }}` |
| Tinted or heavy bar shadow (`0.18`, r16) | `layout.shadow.card` — black 6 %, r6, y2 |
| 56 pt centre circle | 44 in the pill; 56 is the *FAB fallback* size |
| Bar covering the last row of content | Pad by `FLOATING_TAB_BAR_HEIGHT` + insets |
| `BlurView` bar | Opaque `#FFFFFF` |
| No mention of the native-tabs alternative | Offer it with the trade-off table |
