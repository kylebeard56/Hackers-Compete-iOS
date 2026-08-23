# Series and Round V2

Date: 07-19-2026

## Scope Boundary

- Changed: Added an isolated V2 persistence/domain path, server command boundary, migration tooling, and compatibility adapters while preserving V1 collections and behavior.
- Not touched: Existing V1 Series/Round schemas, V1 synchronization behavior, and live score-entry latency path.

## Design Decisions

- V2 uses separate `series-v2` and `rounds-v2` collections.
- Every Series round is one real `RoundV2` created in lobby state with an optional `SeriesContextV2`; there is no second mutable Series-round document.
- Structural and lifecycle mutations use idempotent callable functions. Score writes remain direct Firestore writes.
- Series tile planning state is derived independently from the playable round lifecycle.
- New V2 creation is opt-in; existing creation and reads continue through V1 unless version routing selects V2.
- Swift actor APIs perform immutable command calls and sequential aggregate reads, avoiding detached work and unchecked sendability.
- Migrated Series use a server-owned `series-routing-v2` phase and revision. Lists, IDs, share codes, and linked-round resolution select one logical version from the same route.
- `ready` V2 copies remain hidden; only an atomic commissioner command can activate or roll them back.

## Deviations

- Existing UI continues on V1 until its route explicitly selects V2.
- Migration validates a lossless semantic copy. V2 result-engine recomputation and route cutover remain explicit release gates.
- The migration CLI now requires an explicit Firebase project even for dry runs.

## Tradeoffs

- Separate collections require dual-version routing but provide clean rollback and prevent V2 decoding or writes from changing V1 behavior.
- Provisioning is recoverable and idempotent rather than claiming cross-batch atomicity beyond Firestore limits.
- The repository had no authoritative Firestore rules file, so indexes are included but the deployed rules are not replaced.
- Combined Series loading performs extra point reads for staged counterparts and routes. This favors fail-safe deduplication over minimizing reads during the migration window.

## Deployment Gates

- Merge participant/commissioner V2 score permissions into the authoritative deployed Firestore rules.
- Move the current V1-only Series dashboard/detail screens onto `SeriesRecord` selection before activating a migrated route.
- Enforce the route's minimum client version and deny V1 writes for active routes so older clients cannot mutate the hidden legacy copy.
- Recompute migrated canonical results through the V2 processor and compare semantic hashes before route cutover.
