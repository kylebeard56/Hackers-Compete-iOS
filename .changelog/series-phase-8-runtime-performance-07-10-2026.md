# Series Phase 8: Runtime Performance

Date: 07-10-2026

## Scope Boundary

- Changed: Realtime listener ownership, active-round subscription policy, Series-round invalidation, attendance deltas, handicap projection, and completed-round UI fallbacks.
- Not touched: Firestore schema, standings calculation semantics, migration activation rules, or automatic production writes.

## Design Decisions

- Ordinary Series loading subscribes only to linked rounds whose persisted Series status is planned, lobby, or live.
- Completed and canceled rounds use persisted Series status and derived score data; full historical snapshots remain available through the existing on-demand snapshot repository.
- Listener cost is bounded by `2 + canonical listeners + active linked rounds`, independent of completed history length.
- Firestore registrations live in `SeriesRealtimeSourceStore`; `SeriesViewModel` receives decoded domain updates and remains the observable coordinator.
- Series-round snapshots are reduced to semantic runtime state so timestamp-only listener emissions do not publish the rounds array or trigger downstream work.
- Attendance reloads only newly eligible rounds and evicts rounds that are no longer RSVP eligible.
- Handicap calculation is a pure grouped projection, changing score preparation from repeated member-by-score scans to one score grouping pass.
- Legacy handicap metadata backfill no longer walks historical snapshots during ordinary load; it remains part of the explicit commissioner handicap-settings save.

## Compatibility

- Existing Firestore documents decode unchanged and no migration is required.
- Completed-round navigation falls back to persisted Series status when a root is not resident.
- Completed-round score badges fall back to persisted Series handicap score rows; detailed results still hydrate the historical snapshot on demand.
- Commissioner correction, export, migration, and insight workflows retain their explicit snapshot reload paths.

## Tradeoffs

- A completed round whose persisted Series status is stale will not keep a permanent root listener. Completion processing remains responsible for persisting the lifecycle transition before the listener is released.
- Historical player participation without a persisted score is not inferred during ordinary list rendering; opening results hydrates the authoritative snapshot.

## Validation

- Phase 8 runtime architecture tests: 8 passed under Address Sanitizer.
- Full Sandbox unit suite: 646 passed, 0 failed, 0 skipped.
- Generic iOS Sandbox build: succeeded.
- XcodeBuildMCP build was attempted first but its isolated workspace cache lacked existing third-party Swift package artifacts; the established native Xcode build path succeeded.
- XcodeBuildMCP launch-only smoke succeeded; the initial dashboard produced a 110-element accessibility snapshot and the app was stopped without interaction or data writes.
- Thread Sanitizer was attempted, but the Sandbox scheme forces Address Sanitizer into Swift package targets and Xcode rejected the combined ASan/TSan build before tests launched.

## Open Questions

- Production ETTrace baselines should be captured after this client reaches a representative long-running league; the current simulator account overlay prevents a repeatable Series navigation trace.
