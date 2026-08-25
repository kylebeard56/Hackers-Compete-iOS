# Series Phase 0 Baseline

Date: 07-09-2026

## Purpose

Phase 0 locks existing Series behavior before configuration, ingestion, and standings are re-architected. It adds characterization fixtures and diagnostics only; it does not change scoring, award, standings, sync, or UI decisions.

## Current Authority Contract

- `SeriesSettings.defaultRoundConfig` seeds newly created Series rounds.
- Each `SeriesRound.roundConfig` is a persisted snapshot and is the current Series-side source of truth.
- Series edits may push a complete configuration into a linked lobby round.
- Linked-round configuration is not adopted back into the Series because `shouldUseLinkedRoundConfiguration` currently resolves to `false`.
- Completed-round point awards are the persisted inputs to standings.
- Standings rank by points descending, wins descending, best placement ascending, then name.

## Locked Fixture Scenarios

- Best-two, per-round, nine-hole team scoring with gross scores.
- Team and individual standings enabled together.
- Dynamic handicaps, substitute scoring, attendance, pods, recurring weekday, and tee-time defaults.
- Three-round team standings with equal points resolved by wins.
- Individual standings isolated from team standings.
- Large projection fixture: 40 rounds, 16 teams, 640 point awards.

Fixtures live in `HackersUnitTests/Fixtures/SeriesBehaviorFixtures.swift`. Golden behavior and the projection benchmark live in `HackersUnitTests/SeriesPhase0BehaviorTests.swift`.

## Runtime Diagnostics

`SeriesPerformanceRecorder` retains the latest 200 samples in memory and emits unified logs in the `SeriesPerformance` category. No analytics event or UI is added.

Instrumented operations:

- Core and fully enriched Series loading.
- Linked-round root loading and active listener count.
- Attendance preload.
- Full linked-round snapshot loading.
- Series-to-round synchronization.
- Automatic awards refresh.
- Standings rebuild reads and writes.
- Team insight loading.

`logicalReadCount` and `logicalWriteCount` count explicitly instrumented repository operations initiated by the measured boundary, not Firestore documents returned or billed. Nested operations with their own instrumentation emit separate samples.

## Benchmark Protocol

1. Run `SeriesPhase0BehaviorTests/testLargeLeagueStandingsProjectionBaseline` in the same simulator and Debug configuration used for comparisons.
2. Capture the XCTest wall-clock average and peak memory result.
3. Exercise a representative small league and large league while collecting `SeriesPerformance` unified logs.
4. Record core load, full load, snapshot load, automatic refresh, standings rebuild, listener count, logical reads, and logical writes.
5. Compare future phases against the same fixture sizes and simulator runtime.

Performance tests are observational in Phase 0. Hard budgets should be set in Phase 1 after several stable local and CI samples establish variance.

### Initial Local Observation

Environment: Sandbox Debug tests, iPhone 17 Pro simulator on iOS 26.4.1, Address Sanitizer enabled.

| Fixture | Clock average | Peak physical memory | Physical memory delta |
| --- | ---: | ---: | ---: |
| 40 rounds, 16 teams, 640 awards | 166 ms | 358,951 kB | 1,933 kB |

The clock metric had 2.96% relative standard deviation across five samples. The physical-memory delta had 29.06% relative standard deviation, so it is recorded for context but is not suitable for a regression threshold yet. Peak memory includes the host app and sanitizer overhead rather than only standings computation.

## Phase Gate

- The existing Series test suites pass.
- New settings and round configuration round trips preserve every selected fixture value.
- Golden standings exactly match current ranking behavior.
- The large projection benchmark completes with 16 standings from 640 awards.
- The app builds without adding a diagnostic surface or changing user-visible behavior.
