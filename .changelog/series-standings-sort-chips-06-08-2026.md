# Series Standings Sort Chips

Date: 06-08-2026

## Scope Boundary

- Changed: Individual stats controls and local sort behavior in the series leaderboard.
- Not touched: Team standings, placement standings scoring, Firestore schemas, and persisted user preferences.

## Design Decisions

- Kept the selected sort as view-local state with Avg Diff as the default to preserve current behavior.
- Used menu button labels with `Label` plus an optional second `Text`, matching the dashboard plus menu construction.
- Shortened menu subtitles and made the handicap index copy read the configured games-used and rolling-pool values.

## Deviations

- None.

## Tradeoffs

- Sorting stays in the view because it is presentation-only and avoids widening `SeriesViewModel` APIs.

## Open Questions

- None.
