# Plural Commissioner Round Authority

Date: 08-05-2026

## Scope Boundary

- Changed: Derived round-manager permissions, commissioner handicap overrides, related callable-function authorization, and focused regression coverage.
- Not touched: The persisted single-host model, commissioner roster schema, scoring/completion ownership rules, or unrelated working-tree changes.

## Design Decisions

- Keep `is_host` singular and derive operational authority from the host plus every active Series commissioner.
- A lobby handicap override changes only the round participant's `adjustedHandicap`; the league baseline, index, and handicap snapshot remain intact.
- Creator-only archive/delete and current-host-only ownership transfer remain distinct from operational commissioner authority.

## Deviations

None.

## Tradeoffs

- Commissioner authority is resolved from current Series membership instead of copied onto round participants, avoiding stale role data at the cost of requiring Series access resolution.

## Open Questions

None.

## Verification

- Backend lifecycle authorization tests: 10 passed.
- Focused iOS resolver, handicap, lobby/live-round, synchronization, lifecycle, and handicap-computation tests: 118 passed with no failures.
- Full generic iOS build: succeeded.
