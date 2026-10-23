# Handicap normalization consistency

The canonical leaderboard already normalized field handicaps, but the live scorecard's net cells and stroke dots, Stableford summaries, player projections, and lobby preview used separate allowance paths. For players with allowances 4 and 12, normalization correctly produced 0 and 8 in the engine while these views still allocated 4 and 12. Projection revisions also missed changes to the baseline player.

Shared-score formats had a second mismatch: their labels and dots could reuse a saved team allowance while the engine recomputed it from normalized members. A two-player scramble example showed 3.2 instead of the normalized 1.2, both before and after scores existed.

Use one eligible-player scoring view for the field leaderboard, lobby, individual scorecards, Stableford, and projections. Shared-score labels and dots recompute playing allowances from those members when normalization is enabled. Projection revisions include the playing allowance so changes to the field baseline invalidate stale estimates. Saved participants, Indexes, manual overrides, and shared allowance snapshots are not rewritten. Matchup normalization remains scoped to each pairing.

Ten new regression tests cover 18 holes/front nine/back nine, plus handicaps, one-time legacy stroke scaling, toggling normalization, gross/net consistency, attendance and substitute exclusions, separate matchup baselines, manual overrides, projection invalidation, and shared scramble allowances before/after scoring. The five initial individual/projection cases and the later shared-score case were demonstrated failing before their respective fixes. The new suite is included in CI.

The full optimized Production unit suite passed with nine normalization tests: **1,197 passed, 0 failed, 5 existing opt-in skips** (1,202 total). A final focused run passed **all 10 normalization tests** after adding the reported four-player example: **4, 12, 14, 18 → 0, 8, 10, 14**, verified across 18 holes, front nine, and back nine. Application code was unchanged between these two passing runs. See [validation.json](validation.json) for receipts and artifact paths.

No new TestFlight upload was performed. The available Sandbox build **2026.10.22.3** predates these normalization changes. Production remains held.
