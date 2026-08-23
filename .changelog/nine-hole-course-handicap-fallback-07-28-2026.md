# Nine-Hole Course Handicap Fallback

Date: 07-28-2026

## Scope Boundary

- Changed: Shared tee rating/slope resolution for front- and back-nine Course Handicap calculations, plus focused regression coverage.
- Not touched: The league Handicap Index formula, score-pool selection rules, existing exact nine-hole tee metadata, or production Firestore data.

## Design Decisions

- Exact front/back Course Rating and Slope Rating remain authoritative when present.
- An 18-hole tee missing segment metadata falls back to half its full Course Rating and its unchanged full Slope Rating.
- A native nine-hole tee uses its full Course Rating unchanged for the front nine so it is not divided twice.
- Back-nine fallback remains unavailable for tee data representing fewer than 18 holes.

## Deviations

None.

## Tradeoffs

- The fallback is an approximation rather than an official nine-hole rating. It keeps league Course HCP and score normalization available when the provider supplies only full-round values.

## Open Questions

- Exact front/back ratings should replace the fallback whenever an authoritative source becomes available.
