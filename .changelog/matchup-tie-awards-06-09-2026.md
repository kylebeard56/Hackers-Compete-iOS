# Matchup Tie Awards

Date: 06-09-2026

## Scope Boundary

- Changed: matchup tie detection for automatic series awards, live projected awards, and team schedule status.
- Changed: automatic award engine version so old finalized automatic awards are recognized as stale.
- Changed: commissioner Team Standings refresh action now appears above the list with scoring update copy.
- Not touched: score entry persistence, round result presentation layout, and Firebase schemas.

## Design Decisions

- Treat matchup totals within the existing Round Awards display tolerance as the same outcome for WLT award generation.
- Prefer saved award metadata (`tieGroupSize` and `placement`) over point totals when rendering team status.
- Reuse the existing finalized-awards refresh path by bumping the engine version from 2 to 3.

## Deviations

- None.

## Tradeoffs

- Kept the fix local to matchup outcome/award interpretation instead of changing all scoring totals away from `Double`, because scoring profiles support fractional points.

## Open Questions

- None.
