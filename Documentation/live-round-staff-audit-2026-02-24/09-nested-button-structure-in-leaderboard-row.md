# 09 - Nested Button Structure In Leaderboard Row

- Category: UI Semantics, Accessibility, Interaction Bugs
- Severity: Medium
- Score: 64/100
- Confidence: Medium-High

## Problem Finding

`LeaderboardRowView` nests a star `Button` inside a row-level `Button`.

## Evidence / Proof

- Outer row button:
  - [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LeaderboardRowView.swift:27](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LeaderboardRowView.swift:27)
- Inner pin button:
  - [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LeaderboardRowView.swift:69](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LeaderboardRowView.swift:69)

## Why This Is A Problem

Nested controls can create ambiguous gesture routing and accessibility semantics. Users may trigger row navigation while trying to pin/unpin, depending on platform behavior and style.

## Assumptions / Validation Notes

- Assumes default SwiftUI nested button behavior without explicit containment handling.
- Exact behavior can vary by OS version and control style, but structure is broadly risky.

## Recommended Fix

1. Use a non-button container row (`HStack`) with explicit tap gesture for row open.
2. Keep star as the only `Button` in that subtree.
3. Add explicit accessibility labels and traits for row and pin control.

## Implementation Steps

- Replace outer `Button` with `contentShape(Rectangle()).onTapGesture`.
- Keep pin button and ensure it does not bubble row action.
- Validate with VoiceOver focus order and tap behavior.
