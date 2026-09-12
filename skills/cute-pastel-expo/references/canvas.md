# GradientCanvas — the full-bleed pastel gradient

The canvas owns the screen's only gradient: three stops at 0 / 0.45 / 1, running
under the status bar, the header and the home indicator. Two stops read as a
flat wash, four read as a rainbow.

## The component

```tsx
// components/GradientCanvas.tsx
import { LinearGradient } from 'expo-linear-gradient';
import type { ReactNode } from 'react';
import { StyleSheet, View } from 'react-native';

import { useTokens } from '../theme/tokens';

export type GradientCanvasProps = {
  children: ReactNode;
};

export function GradientCanvas({ children }: GradientCanvasProps) {
  const t = useTokens();
  return (
    <View style={styles.root}>
      <LinearGradient
        colors={[t.canvasTop, t.canvasMid, t.canvasBottom]}
        locations={[0, 0.45, 1]}
        style={StyleSheet.absoluteFill}
        pointerEvents="none"
      />
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
});
```

**Typing `colors`.** `expo-linear-gradient` types it as
`readonly [string, string, ...string[]]`, so a plain `string[]` fails strict TS.
Building the array inline from three token reads satisfies it; if you hoist it,
type the local as `readonly [string, string, string]` — do **not** reach for
`as any`.

`pointerEvents="none"` keeps the gradient out of the touch path. The default
`start`/`end` is top-to-bottom, which is what the language wants; don't pass an
angle.

Any decorative illustration layered between the gradient and the content is
mood, not content: `accessibilityElementsHidden` +
`importantForAccessibility="no-hide-descendants"`.

## Expo Router placement

Put it once, in the layout — not per screen. Re-mounting the gradient on every
navigation is a visible flash.

```tsx
// app/_layout.tsx
import { Stack } from 'expo-router';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';

import { GradientCanvas } from '../components/GradientCanvas';

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <GradientCanvas>
          <StatusBar style="auto" />
          <Stack
            screenOptions={{
              headerTransparent: true,
              headerShadowVisible: false,
              headerStyle: { backgroundColor: 'transparent' },
              contentStyle: { backgroundColor: 'transparent' },
            }}
          />
        </GradientCanvas>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
```

Four options, four different ways the gradient gets clipped if you skip one:

| Option | Without it |
|---|---|
| `headerTransparent: true` | An opaque bar cuts the top of the gradient off |
| `headerStyle: { backgroundColor: 'transparent' }` | A translucent-but-tinted bar on Android |
| `headerShadowVisible: false` | A hairline/elevation line across the wash |
| `contentStyle: { backgroundColor: 'transparent' }` | The screen paints its own white (or `#000` in dark) over everything |

Per-screen overrides go through `<Stack.Screen options={{ ... }} />` inside the
screen, which is also where you set the title. Don't repeat the gradient there.

**Large titles.** A large title plus `headerTransparent` is the one header
combination with real platform quirks — the large-title area gets its own
background and can paint over the wash, and it is iOS-only. Follow the
`rn-headers` skill for the header config itself, and change two things here:

- `contentInsetAdjustmentBehavior="automatic"` on the scroll view, **not**
  `"never"` — the native stack drives the large-title collapse through content
  insets, so `"never"` freezes the title expanded.
- Drop the manual `paddingTop` with it. `"automatic"` already inserts the
  header inset; adding `useHeaderHeight()` on top double-pads the first row.
  Keep `paddingBottom` and the horizontal gutter.

Two conflicts with `rn-headers` that are only apparent conflicts:

- It gates `headerTransparent` to iOS because on Android a transparent header
  breaks the *large-title* pattern. Outside that pattern, a fully transparent
  header on Android is exactly what the canvas wants — so keep the root
  `headerTransparent: true` and gate it to iOS only on the screens that opt
  into large titles.
- `headerBlurEffect` is native header chrome rendered by the OS, not an
  app-drawn pastel surface, so it is outside rule 2's ban on blur and glass.
  Keep it iOS-version-guarded as `rn-headers` says. Rule 2 still forbids a
  `BlurView` you draw yourself, header-shaped or not.

Verify the top of the gradient and the collapse on an iOS device before
assuming the four options above are enough.

## Content inset — insets, never a magic number

A transparent header does not reserve layout space, so the first row lands under
the title. Get the real numbers; `paddingTop: 100` is wrong on every device.

```tsx
import { useHeaderHeight } from '@react-navigation/elements';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { ScrollView } from 'react-native';

import { layout } from '../theme/layout';

export default function HomeScreen() {
  const insets = useSafeAreaInsets();
  const headerHeight = useHeaderHeight(); // 0 when headerShown is false

  return (
    <ScrollView
      style={styles.scroll}
      contentContainerStyle={{
        paddingTop: headerHeight + layout.space.md,
        paddingBottom: insets.bottom + layout.space.section,
        paddingHorizontal: layout.space.gutter,
      }}
      // "never" for a plain transparent header; "automatic" with a large
      // title — see Large titles below.
      contentInsetAdjustmentBehavior="never"
    >
      {/* ... */}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  // A scroll view over the canvas MUST be transparent, or the gradient
  // stops at the first row.
  scroll: { flex: 1, backgroundColor: 'transparent' },
});
```

- `useSafeAreaInsets` from `react-native-safe-area-context`. **Not** RN's
  `SafeAreaView`, which is iOS-only, deprecated, and — being a view with
  padding — would also clip the gradient if it wrapped it.
- `SafeAreaView` from `react-native-safe-area-context` is acceptable for
  *content*, never around the gradient itself.
- With a floating tab bar, add its height to `paddingBottom` too — see
  `references/navigation.md`.

## Gradient cards are a different component

The canvas gradient is the screen's only one. A card may carry a gradient only
as the promo or status variant, both reusing the `promoGradientStart/End` pair,
max two per screen — see the `cute-pastel-style` skill
(`references/components.md`). A
gradient on a plain card is banned at any opacity.

## Common mistakes

| Mistake | Fix |
|---|---|
| `react-native-linear-gradient` | `expo-linear-gradient` — first-party, `expo install`ed, no native config |
| Two colours, or no `locations` | Three token stops, `locations={[0, 0.45, 1]}` |
| Gradient per screen | Once in `app/_layout.tsx` |
| `paddingTop: 100` | `useHeaderHeight()` + `useSafeAreaInsets()` |
| RN `SafeAreaView` | `useSafeAreaInsets` from safe-area-context |
| Default (opaque) `contentStyle` | `backgroundColor: 'transparent'` |
| `BlurView` over the canvas | Flat `surface` at 85 % — rule 2 |
