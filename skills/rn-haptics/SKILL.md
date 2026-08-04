---
name: rn-haptics
description: Use when adding or changing haptic feedback in a React Native or Expo app — button presses, gesture confirmations, success/error vibration, or choosing a haptics library. Enforces react-native-pulsar over alternatives.
---

# RN Haptics — Pulsar

Haptics in React Native = `react-native-pulsar` (Software Mansion). Do not use
`expo-haptics` or `react-native-haptic-feedback` in new code; if you find them
in an existing project, flag the migration as tech debt — don't mix libraries.

- Docs: https://docs.swmansion.com/pulsar/
- Repo: https://github.com/software-mansion/pulsar
- npm: `react-native-pulsar`

## Before writing code

Read the current docs (link above) or the package's TypeScript types before
using the API — do not write Pulsar calls from memory. The library is newer
than most training data; hallucinated APIs are likely.

## Conventions

- Install with `bunx expo install react-native-pulsar` (respects SDK version
  compat) in Expo projects.
- Haptic triggers belong at the interaction layer (press handlers, gesture
  callbacks) — not inside business logic or reducers.
- Semantic mapping: success/error/warning feedback for outcomes; light impact
  for selections and toggles. Don't fire haptics on every list item press.
- Gate haptics behind the user's system settings; never force vibration when
  the OS reports it disabled.
