# 07 - Unnecessary Writes On Golfer Switch

- Category: Performance, Data Churn
- Severity: High
- Score: 76/100
- Confidence: High

## Problem Finding

Switching golfers in `LiveHoleScoringView` commits a score write unconditionally, even when no change occurred.

## Evidence / Proof

- In `jumpToPlayer`, write occurs every time:
  - `await viewModel.setQuickScore(participant: golfer, strokes: score)` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LiveHoleScoringView.swift:420](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LiveHoleScoringView.swift:420)
- No guard against unchanged draft vs saved score in this path.

## Why This Is A Problem

This increases network writes, local snapshot churn, and UI invalidations. In weak network conditions or larger groups, this can amplify lag and contention.

## Assumptions / Validation Notes

- Assumes `setQuickScore` leads to optimistic snapshot update + backend write (confirmed in view model write flow).
- Behavior is deterministic from code path.

## Recommended Fix

1. Use `shouldCommitScore` logic before writing on player switch.
2. Commit only when draft differs from saved score.
3. Optionally batch or debounce commits during rapid player switching.

## Implementation Steps

- In `jumpToPlayer`, compute `needsSave` before `Task`.
- Call write only when `needsSave == true`.
- Add smoke test:
  - switch golfers without changing picker value and verify no write call.
