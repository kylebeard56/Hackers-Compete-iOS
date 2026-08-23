# Live Round Performance and Watch Sync

Date: 08-19-2026

## Scope Boundary

- Changed: Live-round probability computation and propagation, Live Activity/watch presentation state, empty-score copy, and supported watch activation/deep-link behavior.
- Not touched: Unrelated live-round scoring, series, dashboard, deployment, and asset changes already present in the working tree.

## Design Decisions

- Made the phone's companion `LiveRoundViewModel` the single probability authority for the
  iPhone-adjacent Watch and Live Activity pipelines. The separate Activity view model no longer
  starts another probability precomputation.
- Coalesced all dirty matchups into one simulator batch. A score/configuration revision now builds
  each affected player's scenarios once and runs the canonical `ScoringEngine` 1,000 times total,
  instead of 5,000 times for every matchup on every view model.
- Serialized scoring-engine evaluation on the simulator actor at utility priority and added bounded
  process-wide caches for player scenarios and completed matchup batches. Production projections do
  not retain test-only finish/hole scenario arrays.
- Added a revision-valid `publishableMatchupProbabilities` accessor. Watch and Live Activity omit
  odds while a newer revision is loading rather than publishing a retained result from an older
  score snapshot. Companion publishes also use generation checks after suspension points.
- Synchronized Gross/Net selection from Live Round to both companion surfaces and made Watch/Live
  Activity probability labels state the basis. The screenshot discrepancy was reproducible by
  construction: the iPhone screenshot selected Gross while the companion defaulted to Net.
- Replaced separate persisted Watch/Live Activity opt-ins with one greedy active-round selection.
  Entering an eligible live round or dashboard reconciliation selects both surfaces atomically;
  completion/ineligibility clears both. Removed the manual activation controls and nudge.
- Changed unscored matchup/current-hole copy to `TBD` and suppressed unready odds, with
  `No scores entered` as the supporting detail.
- Kept a single widget URL per Live Activity hierarchy. Watch deep links now wait for a matching
  hydrated snapshot, request a fresh snapshot over WatchConnectivity, and navigate once the route
  is ready; Watch destination views no longer force-unwrap cold-launch state.
- Added a one-time alerting update when a local Live Activity starts so watchOS can promote it in
  the Smart Stack. Routine scoring updates remain silent.

## Deviations

- Did not persist client-computed odds to Firestore. That would still spend CPU on a participant's
  phone, introduce conflicting writers, and lacks a trusted server implementation of the app's
  scoring engine. A later backend job should publish one canonical, revisioned odds envelope.
- Did not add ActivityKit remote push updates in this client-only change. A Live Activity cannot
  keep the iPhone process executing after suspension; reliable background start/update needs APNs,
  token registration, push-to-start handling, and a server source of canonical round state.
- watchOS does not provide an API for an iPhone app to force a general Watch app into the
  foreground. The supported behavior implemented here is automatic Live Activity prominence plus
  opening the native Watch app after the user taps the activity.

## Tradeoffs

- Live simulations use 1,000 deterministic runs rather than 5,000. This materially bounds latency
  and battery/thermal cost while preserving stable results for an identical revision. The existing
  simulator API retains its 5,000-run default for explicit analytical/test callers.
- Matchup scoring is deliberately serialized instead of using all active cores. A batch may take
  longer in isolation than an eight-core burst, but it avoids UI starvation and prevents three
  callers from multiplying that burst concurrently.
- The first Live Activity update can alert the user when a round becomes live. This is intentional
  for the greedy live-round product invariant; subsequent updates do not alert.

## Open Questions

- Backend phase: define and authorize a canonical envelope containing round ID, matchup ID, score
  basis, source revision, generated timestamp, algorithm version, and left/tie/right probabilities.
- Backend phase: add ActivityKit activity/push-to-start token upload and participant-specific APNs
  updates so the Live Activity stays current while iOS suspends the app.

## Verification

- `Sandbox` generic iOS device build succeeded with code signing disabled.
- `Hackers Watch App - Sandbox` generic watchOS Simulator build succeeded with code signing disabled.
- 21 focused Live Round companion contract tests passed, covering greedy selection, empty-state
  presentation, deep-link parsing, and Watch/Activity payload compatibility.
- 15 focused projection tests passed, covering deterministic scenarios, gross/net parity,
  scoring-engine matchup evaluation, and production scenario retention.
- The repository's normal simulator test action still has an unrelated target-layout validation
  issue: its iOS Simulator host embeds a watchOS-device product. Tests were executed from the same
  compiled bundle after temporarily removing that generated embed; no source/project behavior was
  changed for the workaround.
