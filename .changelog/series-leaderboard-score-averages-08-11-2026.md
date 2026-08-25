# Series Leaderboard Score Averages

Date: 08-11-2026

## Scope Boundary

- Changed: Individual series leaderboard statistics aggregation, display, sorting, focused unit coverage, and production build increment to `2026.08.11.3` for TestFlight publication.
- Not touched: Team standings, placement standings, round scoring, handicap-index computation, or persisted series data.

## Design Decisions

- Gross average uses every recorded score from completed series rounds, regardless of whether that score counts toward the player's handicap index.
- Net average is the all-round gross average minus the player's current effective series handicap index; it is unavailable when no current index exists.
- Existing statistics remain first in the table and the new columns are appended in a horizontally scrollable layout so the current default view and sort remain stable.
- Fastlane successfully published build `1.0.0 (2026.8.11.3)` to App Store Connect and distributed it to the external `Beta Testers` group.

## Deviations

None.

## Tradeoffs

- Using the current effective handicap keeps the enhancement compatible with legacy completed-round records, which do not persist the exact course handicap used in each historical round.

## Open Questions

None.
