# Series Phase 1: Correctness And Immediate Performance

Date: 07-09-2026

## Purpose

Phase 1 makes the existing Series pipeline safer and faster without changing the Firestore schema, scoring rules, ranking order, or user-facing configuration model. It establishes reliable ingestion and publication boundaries before configurable tiebreakers are added in a later phase.

## Snapshot Ingestion

`SeriesRoundSnapshotRepository` is the single loading boundary for the seven independent linked-round components: round, participants, teams, tee groups, segments, scores, and scoring groups.

- Components for one round load concurrently.
- Bulk refreshes process at most three rounds concurrently by default.
- Concurrent callers for the same round share one in-flight task.
- Successful snapshots are cached until the relevant round is invalidated.
- A component failure identifies the exact component and does not yield a partial snapshot.

The controlled 20 ms latency fixture loaded all seven components in about 31 ms. A serial implementation would require at least 140 ms of injected latency.

## Derived Data Publication

Point awards and standings are compared semantically before writing. Generated timestamps do not make otherwise identical rows appear changed.

- Repeating the same refresh produces zero award and standings writes.
- Standings are materialized once after all refreshed rounds have been processed.
- Existing `createdAt` values survive updates.
- Award and standings replacements use one atomic Firestore batch each.
- A failed read or write leaves the previously published in-memory and Firestore standings intact.
- A failed award read or write cannot mark automatic awards finalized.

Firestore batches are limited to 500 operations. Phase 1 fails publication before writing when an award or standings diff exceeds that limit. Supporting larger publications requires the generation-based schema planned for a later phase; splitting the current replacement across batches would allow partially published standings.

## Configuration Safety

- Mapping reads are shared across a refresh instead of repeated per round.
- Mapping read failures no longer masquerade as empty mappings.
- Linked-round matchup plans and lobby attendance are preserved when authoritative mappings cannot be loaded.
- Touched async workflows resolve collection positions by stable IDs after suspension rather than retaining array indices across `await`.
- Linked-round back-propagation uses a field-level three-way merge so concurrent commissioner edits are not overwritten.

## Backward Compatibility

- Existing documents decode without migration.
- Existing array-returning Firebase methods remain available for callers outside the critical publication paths.
- Scoring, point awards, standings ranking, and Series UI output remain unchanged.
- The current standings authority chain remains: linked-round snapshot to point awards to materialized standings.

## Gate Results

Environment: Sandbox Debug, iPhone 17 Pro simulator, iOS 26.4.1, Address Sanitizer enabled.

- Phase 1 pipeline tests cover every snapshot component failure, concurrency limits, in-flight deduplication, invalidation races, atomic publication failure, idempotency, finalization safety, and concurrent-edit merging.
- Phase 0 golden fixtures and existing Series Codable, award aggregation, round sync, and round creation mapping suites remain the output-parity gate.
- The 40-round, 16-team, 640-award projection averaged about 3.0 ms across five runs after replacing per-award timestamp creation with one rebuild timestamp. Phase 0 recorded 166 ms in the same simulator configuration.
- The Sandbox app builds successfully with the repository package cache.

## Phase 1 Acceptance

- One standings materialization occurs after a multi-round automatic refresh.
- Failed critical reads and writes preserve published standings and configuration.
- Repeated equivalent refreshes issue no writes.
- Existing fixture outputs remain unchanged.
- Snapshot latency is reduced through concurrent component loading with bounded bulk pressure.
- The Phase 0 standings projection has no performance regression.
