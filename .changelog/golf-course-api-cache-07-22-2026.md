# Golf Course API Cache

Date: 07-22-2026

## Scope Boundary

- Changed: GolfCourseAPI detail and search consumers now use a Firebase-backed cache-first/write-through repository.
- Not touched: No scheduled bulk mirror job is included in the iOS client change.

## Design Decisions

- API-backed courses use the GolfCourseAPI numeric ID as the Firebase document ID, allowing direct document reads before a paid API request.
- The numeric identity mapping and canonical API-course conversion are centralized on `Course`; random UUIDs remain reserved for locally created courses.
- Cache read and write failures fall back to the remote API or returned remote result so Firebase availability cannot block course selection.
- Search results are also cached after a successful response to grow coverage organically.
- Course and club-name prefix searches read the cache first via the existing normalized Firestore search fields, and only call GolfCourseAPI when no cached match exists.

## Deviations

- None.

## Tradeoffs

- Cached records do not expire automatically, prioritizing request-cost reduction. A future administrative refresh path can update stale records deliberately.
- A deterministic external ID couples the cache document to GolfCourseAPI. If another provider is added later, introduce a provider namespace rather than random UUID cache IDs.
- The cache-first text search supports normalized prefix/token matching, not typo tolerance. A dedicated search service would be needed for full fuzzy matching.

## Open Questions

- Confirm directly with GolfCourseAPI that bulk replication is permitted before scheduling an ID-range mirror job; the public pricing page and API reference do not publish storage or redistribution terms.
