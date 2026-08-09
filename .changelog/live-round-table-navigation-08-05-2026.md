# Live Round Table Navigation

Date: 08-05-2026

## Scope Boundary

- Changed: Live-round tab navigation, embedded score table presentation, leaderboard row layout, and Player Insights favorite/individual-scorecard presentation.
- Not touched: Round/Firebase document schemas, scoring-engine rules, Series models, and completed-round listener behavior.

## Design Decisions

- The existing Scorecard tab remains the hole-entry surface and keeps its inline leaderboard.
- The existing multi-player full scorecard becomes the dedicated Table tab rather than a second leaderboard implementation.
- Table score editing defaults to View mode and requires an explicit Edit-mode selection when the viewer has permission.
- Table-specific display controls share the existing settings surface; scoring-basis and edit state remain visible because they change how the grid should be interpreted.
- Player favorites retain the existing current-round pin semantics and move into Player Insights.
- Secret-scoring rows open the protected Player Insights shell so identity and follow remain available while score details stay hidden.

## Deviations

- None.

## Tradeoffs

- Reusing scorecard content across embedded and modal contexts requires presentation-specific chrome while keeping one calculation and grid implementation.

## Open Questions

- None.

## Verification

- Sandbox iOS app target builds successfully.
- `RoundResumeStoreTests`: 5 passed, covering legacy scoring values, Table round trips, routing, and explicit Table edit mode.
