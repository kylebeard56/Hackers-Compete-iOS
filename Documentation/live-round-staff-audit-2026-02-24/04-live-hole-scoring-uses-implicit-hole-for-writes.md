# 04 - LiveHoleScoringView Uses Implicit Current Hole For Writes

- Category: Correctness
- Severity: High
- Score: 86/100
- Confidence: High

## Problem Finding

`LiveHoleScoringView` receives an explicit `holeNumber`, but score mutation paths call view-model helpers that default to `currentHoleNumber` (implicit hole).

## Evidence / Proof

- Explicit hole parameter in view:
  - `let holeNumber: Int` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LiveHoleScoringView.swift:20](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LiveHoleScoringView.swift:20)
- Mutations using implicit helper:
  - `clearScore()` calls `viewModel.clearScore(participant:)` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LiveHoleScoringView.swift:447](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LiveHoleScoringView.swift:447)
  - Multiple `setQuickScore(participant:strokes:)` calls in same file (e.g. lines 420, 461, 470, 480)
- Implicit helper routes to `currentHoleNumber` in ViewModel:
  - [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:797](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:797)

## Why This Is A Problem

If the view model current hole drifts from the sheet hole, score writes land on the wrong hole. This is a direct correctness bug with high user trust impact.

## Assumptions / Validation Notes

- No assumptions required for the bug shape; the call graph is explicit.
- Assumes drift can occur (confirmed by split-state architecture).

## Recommended Fix

1. Replace all implicit writes in `LiveHoleScoringView` with explicit-hole methods.
2. Use `viewModel.setScore(participant:holeNumber:strokes:)` and `viewModel.clearScore(participant:holeNumber:)` for this surface.
3. Optionally remove implicit APIs from ViewModel to prevent future misuse.

## Implementation Steps

- Introduce `setQuickScore(participant:strokes,holeNumber:)`.
- Update all score/clear call sites in this view.
- Add a manual test case: open sheet on Hole X while `currentHoleIndex` is Y and verify writes to X.
