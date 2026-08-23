# 08 - Hide-All Visibility Can Be Overwritten

- Category: State Persistence, UX Correctness
- Severity: High
- Score: 71/100
- Confidence: High

## Problem Finding

Selecting "hide all" participants can be overridden by snapshot update logic that repopulates empty visibility to all participants.

## Evidence / Proof

- Auto-fill behavior when `visibleParticipantIDs` is empty:
  - in bind sink: [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:91](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:91)
  - in `set(snapshot:)`: [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:105](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:105)
- UI explicitly allows clearing all:
  - `draftVisibleIDs = []` flow in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/ScorecardVisibilitySheet.swift:268](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/ScorecardVisibilitySheet.swift:268)

## Why This Is A Problem

User intent is not preserved. The app can appear to ignore explicit visibility settings after data refresh.

## Assumptions / Validation Notes

- Assumes empty set is a valid intentional state (supported by UI offering "Clear all").

## Recommended Fix

1. Distinguish "never configured" from "configured empty".
2. Only auto-populate on first initialization, not every empty-state snapshot update.

## Implementation Steps

- Add `hasInitializedVisibilitySelection` bool.
- Auto-fill only when false.
- Set true after first initialization or explicit user apply.
- Keep `lastAppliedVisibleParticipantIDs` logic consistent with this flag.
