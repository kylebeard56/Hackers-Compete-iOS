# 01 - Split Hole State Can Write Scores To Wrong Hole

- Category: Correctness, State Management
- Severity: Critical
- Score: 98/100
- Confidence: High

## Problem Finding

Hole state is currently split between UI paging state (`scoringPageHole`) and ViewModel state (`currentHoleIndex`/`currentHoleNumber`). Mutations still depend on `currentHoleNumber`, which can drift from what the user is actually viewing.

## Evidence / Proof

- UI display source:
  - `@State var scoringPageHole: Int?` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound.swift:68](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound.swift:68)
- ViewModel source:
  - `@Published var currentHoleIndex` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:33](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:33)
  - `currentHoleNumber` derived from `currentHoleIndex` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:120](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:120)
- Sync direction is one-way:
  - `viewModel.currentHoleNumber -> scoringPageHole` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound.swift:168](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound.swift:168)
- Mutations still use implicit current hole:
  - `setQuickScore -> setScore(participant:strokes:) -> currentHoleNumber` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:793](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:793)
  - `clearScore(participant:) -> currentHoleNumber` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:797](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:797)

## Why This Is A Problem

A user can page to Hole N while writes still target Hole M. This is a silent correctness bug that can corrupt score entry without obvious immediate UI errors.

## Assumptions / Validation Notes

- Assumes the pager can change visible hole without always updating `currentHoleIndex`.
- Assumption is supported by comments in code that explicitly separate these concepts.

## Recommended Fix

1. Make all score mutations hole-explicit (pass hole number at call site).
2. Add reverse sync guard: when `scoringPageHole` changes, call `viewModel.selectHole(_:)`.
3. Deprecate implicit mutation APIs that depend on `currentHoleNumber`.
4. Keep one source of truth for display (`scoringPageHole`) and one for business intent only if absolutely necessary.

## Implementation Steps

- Add:
  - `setQuickScore(participant:strokes,holeNumber:)`
  - use existing `clearScore(participant:holeNumber:)`
- Migrate call sites in:
  - `LiveHoleScoringView`
  - `ScorecardPopupView`
  - any other scoring UI
- Add a short regression test plan:
  - page to different holes, enter score, verify correct `ScoreEntry.holeNumber`.
