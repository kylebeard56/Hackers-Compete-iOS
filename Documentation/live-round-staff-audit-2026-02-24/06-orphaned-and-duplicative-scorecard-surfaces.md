# 06 - Orphaned And Duplicative Scorecard Surfaces

- Category: Maintainability, Product Surface Coherence
- Severity: High
- Score: 80/100
- Confidence: High

## Problem Finding

Multiple scorecard-related surfaces overlap in purpose, and at least two are currently orphaned/unwired from production flow.

## Evidence / Proof

- `ScorecardPopupView` appears disconnected from `LiveRound` flow:
  - hookup is commented in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound.swift:157](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound.swift:157)
  - usage appears only in preview in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/ScorecardPopupView.swift:846](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/ScorecardPopupView.swift:846)
- `ScorecardSheet` usage appears only in preview:
  - [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/ScorecardSheet.swift:616](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/ScorecardSheet.swift:616)
- Unused helper artifact:
  - `ScrollOffsetKey` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/ScrollOffsetKey.swift:10](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/ScrollOffsetKey.swift:10)

## Why This Is A Problem

Orphaned and duplicated pathways create drift in business logic and UX behavior, increase bug surface area, and slow future changes because developers must reason about dead or semi-dead code.

## Assumptions / Validation Notes

- Assumes no external dynamic wiring not visible in source.
- Confidence high due to repository-wide reference search.

## Recommended Fix

1. Choose one canonical score-entry/scorecard surface per use case.
2. Remove or archive orphaned implementations.
3. Centralize shared UI primitives and scoring logic.

## Implementation Steps

- Decision doc: keep `LiveHoleScoringView` + `FullScorecardView` (or alternate).
- Remove disconnected surface files once verified not needed.
- If retained for future use, move to a clearly marked experimental module with compile flags.
