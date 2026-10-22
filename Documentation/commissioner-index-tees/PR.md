# Fix commissioner Index editing and independent Series tee selection

Commissioners can save a league Handicap Index while the keyboard is open, open the same editor directly from Handicap Details, and choose each Series player's tee regardless of calculated or overridden Index source.

- Move Save override into the persistent footer, separate keyboard dismissal/cancellation, retain drafts on failure, and report saved values or actionable errors. Validate commissioner permissions and use an atomic version check to reject stale writes.
- Always show each Start Round player's tee selector. Persist tee choices separately from round-only handicap inputs, retaining Series source/provenance through draft reload, participant creation, and lobby sync.
- Recalculate an unstarted lobby player's tee-dependent Course HCP while preserving the Index and intentional manual strokes. Keep started/completed snapshots locked.
- Add authorized Edit Index directly to Handicap Details, including missing Indexes and zero-score offline/registered members, reusing the existing member editor.

Tickets: [Hidden Save](https://app.clickup.com/t/wdx6zf77zq), [Series per-player tees](https://app.clickup.com/t/wdx6zf77zr), [Override/tee independence](https://app.clickup.com/t/wdx6zf77zt), [Edit Index](https://app.clickup.com/t/wdx6zf6vm2).

This PR targets `codex/consolidated-rc-2026-10-21` (#18), which contains overlapping work from #14–#17. The normal-priority Fixed Handicap settings ticket is excluded.

Validation:
- Full available test target: 1,180 passed, 0 failed, 5 existing opt-in skips; successful Xcode result bundle.
- iPhone SE / iOS 26.3: all 59 commissioner-suite tests passed with Address Sanitizer retained. The Save regression verifies a nonzero software-keyboard frame and the Save button above it.
- Simulator compilation and `git diff --check` passed. Ten new regressions cover keyboard/save/failure/cancel/reopen, mixed tees across eight players, override sources, registered/offline members, full/front/back segments, manual strokes, stale writes, planned persistence, started locks, and the production creation/net-scoring workflow.
- The inherited legacy `HackersTests` scheme reference is unavailable; its explicit run attempt is documented. All available tests ran without disabling tests.

Physical-device and authenticated Firebase save/reload/concurrency acceptance remain manual. Fixture persistence is injected/serialized; no production/customer data, backend deployment, or TestFlight upload is included.

Root causes, changed files, commands, result metadata, and screenshots: [implementation report](Documentation/commissioner-index-tees/README.md).
