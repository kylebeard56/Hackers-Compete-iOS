# 02 - Score Lookup Is Linear In Hot Paths

- Category: Performance, Scaling
- Severity: Critical
- Score: 95/100
- Confidence: High

## Problem Finding

`scoreEntry` performs a linear scan of `snapshot.scoring` and is repeatedly called inside loops and computed properties that feed rendering.

## Evidence / Proof

- Linear lookup:
  - `scoreEntry(for:holeNumber:)` uses `first(where:)` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:365](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:365)
- Called from hot aggregate paths:
  - `holesPlayedCount` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:379](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:379)
  - `holeCompletionProgress` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:386](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:386)
  - `scoreToPar` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:422](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:422)
- These feed large UI sections (`leaderboardRows`, scorecard views), multiplying cost.

## Why This Is A Problem

Complexity trends toward O(participants * holes * scoringEntries). As rounds or participants grow, compute overhead increases sharply and can cause visible UI lag during updates/scrolling.

## Assumptions / Validation Notes

- Assumes non-trivial `snapshot.scoring` size and frequent recomputation under SwiftUI invalidation.
- Confidence high due to deterministic complexity and repeated call graph.

## Recommended Fix

1. Build a score index whenever snapshot changes.
2. Replace linear scans with O(1) dictionary reads.
3. Use that index consistently in all lookup helpers.

## Suggested Design

- Create cached map keyed by `(participantID, holeNumber)` or a compact string key.
- Rebuild once on snapshot update in `bind` sink.
- Keep existing APIs but route through index internally.

## Implementation Steps

- Add `private var scoreIndex: [ScoreKey: ScoreEntry]`.
- Populate in a `rebuildIndexes()` method called on snapshot update.
- Refactor `scoreEntry`, `grossStrokes`, `pickedUp`, and aggregate methods to use index.
- Add sanity checks in debug build to catch key collisions.
