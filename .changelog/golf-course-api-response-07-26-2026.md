# Golf Course API Response Compatibility

Date: 07-26-2026

## Scope Boundary

- Changed: GolfCourseAPI by-ID decoding for omitted location coordinates and tee bogey ratings, plus focused repository response coverage.
- Not touched: Round creation, series synchronization, API credentials, or bulk course import behavior.

## Design Decisions

- Treat provider coordinates and bogey ratings as optional because the live by-ID response omits them.
- Do not persist missing coordinates as a `0,0` Firestore location or geohash.
- Preserve support for both top-level and `{ "course": ... }` by-ID response shapes.
- Surface decoding failures for a present wrapped course instead of silently converting them into an empty response.

## Deviations

None.

## Tradeoffs

- The raw API DTO uses `0,0` internally as the missing-coordinate sentinel to minimize changes to existing search consumers; canonical cached courses omit the location entirely when that sentinel is present.
- Bogey rating remains available when supplied but is nil when omitted; it is not used by round scoring.

## Open Questions

None.
