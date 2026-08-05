---
name: rn-headers
description: Use whenever adding, changing, or reviewing header/navigation bar configuration in an Expo Router app — large header titles, transparent headers, blur effects, header back buttons, header styling. Enforces the large-title config as the default for all headers. Make sure to use this skill any time the user mentions headers, navigation bars, headerLargeTitle, headerTransparent, headerBlurEffect, title styling, or navigation options on a screen, even if they don't ask for it explicitly.
---

# RN Headers — Expo Router

Headers in Expo Router use the native `Stack` (native-stack) navigator. The
default header configuration for any screen is the **large title** pattern —
a large title that collapses into a compact, blurred title as the user scrolls.
Apply it to every screen unless the user explicitly overrides it.

## Default configuration

Reference: https://amanhimself.dev/blog/large-header-title-in-expo-router/

Set these `options` on every `Stack.Screen`:

```tsx
import { Stack } from 'expo-router';
import { Platform } from 'react-native';

function getIOSVersion(): number {
  if (Platform.OS !== 'ios') return 0;
  return parseInt(Platform.Version as string, 10);
}

function isIOS26OrLater(): boolean {
  return getIOSVersion() >= 26;
}

export default function HomeLayout() {
  return (
    <Stack>
      <Stack.Screen
        name="index"
        options={{
          title: 'Home',
          headerLargeTitle: true,
          headerTransparent: Platform.OS === 'ios',
          headerBlurEffect: isIOS26OrLater() ? undefined : 'regular',
        }}
      />
    </Stack>
  );
}
```

Why each piece:

- `headerLargeTitle: true` — enables the large-title pattern (Settings app
  behavior). Without it you get a plain compact header.
- `headerTransparent: Platform.OS === 'ios'` — keeps the header transparent so
  the blur + collapse reads correctly on iOS. On Android it makes the header
  fully transparent (broken); always gate it on iOS.
- `headerBlurEffect: isIOS26OrLater() ? undefined : 'regular'` — iOS 26+
  applies the blur automatically; pre-iOS 26 needs the explicit effect. Always
  keep the version guard so both behave correctly.

## Scrollable content

For the collapse + blur to work, the scrollable (ScrollView, FlatList,
SectionList) must adjust its content insets for the navigation bar:

```tsx
<ScrollView contentInsetAdjustmentBehavior="automatic" ... />
```

Use the same prop on `FlatList`/`SectionList` when applicable. Without it the
content is hidden behind the transparent header.

## Conventions

- Default config goes on the screen's `_layout.tsx` `Stack.Screen` — not on the
  screen component itself. `Screen` props set once per route, in the layout.
- Use `headerLargeTitle` with native-stack `Stack`; it has no effect on
  `Tabs`/`Drawer` headers or JS-based stacks.
- Large titles are an iOS pattern — don't force them on Android; keep
  `headerTransparent` and blur iOS-gated as above.
- Only override these defaults when the user explicitly requests otherwise
  (e.g. a custom `headerShown: false`, a custom title style, or a plain compact
  header).
- If you encounter `headerBlurEffect` not collapsing correctly on a new iOS
  version, prefer the version-guard approach above over removing the blur.
