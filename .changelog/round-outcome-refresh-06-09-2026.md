# Round Outcome Refresh

Date: 06-09-2026

## Scope Boundary

- Changed: Round outcome opening now refreshes its one-shot round snapshot so commissioner score corrections appear immediately.
- Not touched: Live round listeners, scoring correction writes, handicap recomputation, and participant presence behavior.

## Design Decisions

- Added a small `RoundSession` refresh helper instead of changing all one-shot activation behavior globally.

## Deviations

- None.

## Tradeoffs

- Outcome view performs an extra fetch on open, which is acceptable for completed-round correctness and avoids broader listener changes.

## Open Questions

- None.
