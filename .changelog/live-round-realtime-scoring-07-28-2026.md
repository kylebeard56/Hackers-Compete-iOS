# Live Round Realtime Scoring

Date: 07-28-2026

## Scope Boundary

- Changed: Firestore round-listener delivery policy and regression coverage for latency-compensated score updates.
- Not touched: Firestore schema, score write format, scoring-engine calculations, or the broad `RoundSnapshot` observation model.

## Design Decisions

- Apply pending-write and cache-backed snapshots because they contain real data changes that must reach the live-round UI.
- Explicitly exclude metadata-only listener events so server acknowledgement does not trigger a duplicate decode, snapshot publication, or scoring-engine refresh.

## Deviations

None.

## Tradeoffs

- Kept full-query decoding for delivered data changes; changing to an incremental collection reducer would be more invasive and should be driven by profiling.

## Open Questions

None.
