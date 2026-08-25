# 03 - Heavy Per-Page Rendering Work Is Duplicated Across Hole Pages

- Category: UI Performance, Architecture
- Severity: Critical
- Score: 90/100
- Confidence: Medium-High

## Problem Finding

Each hole page renders multiple heavy sections (detail tiles, tee-group score rows, leaderboard). This repeats expensive work across pages in the horizontal pager.

## Evidence / Proof

- Per-page composition in pager content:
  - `holeDetailsCard`, `teeGroupScorecard`, and `leaderboardSection` rendered for each page in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound+Scoring.swift:51](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound+Scoring.swift:51)
- `leaderboardSection` itself is non-trivial and recalculates ranking displays in multiple modes.

## Why This Is A Problem

Even with lazy containers, adjacent pages are realized and re-rendered as state changes. Duplicating leaderboard and player lists per page increases body computation and layout cost, which can manifest as swipe/paging lag.

## Assumptions / Validation Notes

- Assumes lag report is tied to rendering overhead (consistent with user report).
- Runtime profiling is still recommended to quantify exact contribution.

## Recommended Fix

1. Keep per-hole content only where hole-specific data is needed.
2. Move non-hole-specific heavy blocks (leaderboard) outside each page.
3. Memoize derived leaderboard rows/sections where possible.

## Implementation Options

- Option A: Render leaderboard once below pager and keep hole card + rows in page.
- Option B: Split view model into smaller observable slices so unrelated updates do not invalidate full page trees.
- Option C: Gate offscreen subtrees with lightweight placeholders until page approaches visibility.

## Implementation Steps

- Extract `leaderboardSection` to a sibling of `PagedHoleScrollView`.
- Keep scrolling behavior intact with shared vertical scroll only where needed.
- Re-test scroll smoothness and compare frame pacing.
