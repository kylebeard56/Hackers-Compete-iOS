# Series Phase 3: Versioned Policies And Guardrails

Date: 07-09-2026

## Scope Boundary

- Changed: Round-default boundaries, optional versioned standings policies, round policy binding, compatibility classification, and lifecycle mutation guardrails.
- Not touched: Canonical round-result ingestion, scoring-average calculation, tiebreak ordering, or existing standings projection behavior.

## Design Decisions

- Existing Series settings keys remain the persistence authority for round defaults; `SeriesRoundDefaults` is a typed boundary over those legacy-compatible fields.
- A policy revision is an immutable, self-contained snapshot. A round binding carries the full revision so historical resolution never depends on current mutable league settings.
- Rounds without a binding resolve through `.legacySnapshot`, preserving existing eligibility and standings behavior without a migration.
- Score-contract changes are rejected before persistence once a round is live or complete. Descriptive metadata remains editable.

## Deviations

None.

## Tradeoffs

- Phase 3 introduces the policy infrastructure without exposing policy authoring in the league UI; activation remains explicit and can be layered into the later standings work.
- Fingerprints protect against malformed or stale policy bindings, but they are not intended as security signatures.

## Validation

- Generic Sandbox iOS build: passed.
- Phase 3 policy and lifecycle tests: 14 passed, 0 failed.
- Combined Phase 0-3 Series regression suite: 183 passed, 0 failed.
- Large-league standings performance measurement: passed within the existing Phase 0 gate.
- `git diff --check`: passed.
- Build iOS Apps isolated build: package cache could not resolve third-party modules; native Xcode builds and tests passed.
- Build iOS Apps Sandbox runtime smoke: launched the freshly installed Sandbox app, captured the dashboard UI, and stopped without interaction or writes.

## Open Questions

- None.
