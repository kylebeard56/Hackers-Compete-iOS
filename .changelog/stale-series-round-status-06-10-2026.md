# Stale Series Round Status

Date: 06-10-2026

## Scope Boundary

- Changed: Series view-model linked round freshness, linked round listeners, and focused regression tests.
- Not touched: Firestore schema, Cloud Functions, and round activation writes.

## Design Decisions

- Treat top-level round documents as the client-side source of truth for linked series round status.
- Gate series subdocument status writes behind a fresh linked-round fetch or committed listener snapshot.

## Deviations

- None.

## Tradeoffs

- Added per-linked-round listeners while a series view model is active instead of backend status mirroring, matching the requested client hotfix scope.

## Open Questions

- None.
