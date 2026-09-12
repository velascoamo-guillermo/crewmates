---
name: cute-pastel-expo
description: Use when building or restyling an Expo or React Native screen in the cute-pastel look — gradient canvas, huge animated hero numeral, pastel pill chips with spring press and selection haptics, floating pill tab bar with a raised centre action in Expo Router, pastel tile grid, pressable pastel cards — or when an RN project needs typed pastel light/dark token objects, expo-linear-gradient setup, or Reanimated worklet press feedback for those components.
---

# Cute Pastel — Expo / React Native

Building the cute-pastel components in Expo. **Tokens and rules live in the
`cute-pastel-style` skill** — read its `SKILL.md`, `references/tokens.md` and
`references/layout.md` first. It restates no hex: roles here, values there.

## Packages

```
pnpm expo install expo-linear-gradient react-native-reanimated react-native-worklets \
  react-native-gesture-handler react-native-safe-area-context react-native-pulsar
```

Respect the project's lockfile (`bun.lock` → `bun expo install`). Always
`expo install` — it pins to the SDK.

`babel-preset-expo` wires the worklets plugin: do **not** add
`react-native-reanimated/plugin` to `babel.config.js`. Wrap the root layout in
`GestureHandlerRootView` + `SafeAreaProvider`.

## Non-negotiables

1. **Haptics are `react-native-pulsar`, never `expo-haptics`** (see
   `rn-haptics`). This overrides the haptics row in `animate-expo`, which
   predates the rule. "It's the standard Expo module" is not a reason, nor is
   "no repo convention was given".
2. **All motion is Reanimated on the UI runtime** — shared values + worklets,
   or Reanimated CSS transitions. No RN `Animated`, no `LayoutAnimation`, no
   per-frame state update. Springs take `{ duration, dampingRatio }`; scales
   come from the `cute-pastel-style` skill (`references/layout.md`): 0.97,
   chips 0.96. Never invent 0.9.
3. **Read the current docs before writing Pulsar or Expo Router calls** —
   docs.swmansion.com/pulsar, docs.expo.dev/router. Both changed after training
   cutoff; check installed types, not memory.
4. **Strict TS.** Export a `Props` type per component. No implicit `any`, no
   `as unknown as` cast to make `animatedProps` typecheck.
5. **Colour comes from `useTokens()`** as a named role at every call site —
   never a literal hex, not even `'#FFFFFF'`.

## Adoption order

tokens → canvas → chips → hero → tab bar → tiles & cards.

## File map

| Need | Read |
|---|---|
| `tokens.ts`, `useTokens`, `makeStyles`, `layout` | `references/tokens.md` |
| Full-bleed gradient under an Expo Router header | `references/canvas.md` |
| Hero numeral that animates on change | `references/hero.md` |
| Chip, chip group, selection haptic | `references/chips.md` |
| Floating tab bar, centre action, native+FAB | `references/navigation.md` |
| Tile grid, pressable card | `references/tiles-cards.md` |
