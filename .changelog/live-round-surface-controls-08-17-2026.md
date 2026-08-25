# Live Round Surface Controls

Date: 08-17-2026

## Scope Boundary

- Changed: Moved Apple Watch activation off the dashboard and into Live Round settings, compacted settings labels, added an in-round Watch activation nudge, and made Live Activities start when a live round opens.
- Not touched: Live Activity visual templates, Watch scoring and leaderboard layouts, or production distribution settings.

## Design Decisions

- Live Activity and Apple Watch selection remain independent controls.
- Live Activity starts automatically whenever a live round opens; a player may disable it for the current visit, but reopening the round starts it again.
- Apple Watch activation remains explicit because users may have multiple live rounds. A compact, dismissible prompt appears near the Live Round header only when a paired, installed Watch app is available and the current round is not selected.
- Selecting the current Watch round republishes its snapshot, so activation also recovers when the Watch app was installed after an earlier selection.

## Deviations

- The focused unit test target could not start because Xcode exhausted the available disk while resolving package manifests. Source compilation was instead verified through successful Sandbox builds for physical iOS and watchOS Simulator.
- The aggregate iOS Simulator scheme still fails final validation because it embeds a device-watchOS product. This is an existing target-platform-filter issue; the standalone Watch simulator build succeeds and the physical-iOS package validates successfully.

## Tradeoffs

- The Watch prompt is contextual rather than a modal popup, avoiding an interruption every time a round opens.
- Dashboard reconciliation only clears invalid Watch selections; it no longer silently selects the sole live round.

## Open Questions

None.

## Verification

- Sandbox physical-iOS build: passed with Xcode 27 beta 5.
- Sandbox Watch app build for watchOS Simulator: passed with Xcode 27 beta 5.
- Project file validation and `git diff --check`: passed.
