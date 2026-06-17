# Live Round Sync Regression

Date: 06-17-2026

## Scope Boundary

- Changed: Series linked-round status resolution, linked round root-write status preservation, and tee group schedule sync safeguards for live rounds.
- Not touched: Firebase schema, lobby creation flow, score entry, and broader live-round UI layout.

## Design Decisions

- Treat a linked round reporting lobby as an invalid downgrade once the series round is already live.
- Preserve existing linked-round tee starting holes while the linked round is live or paused unless the series round has an explicit planned tee schedule.
- Re-read the linked round status before series sync writes the root round document so stale lobby snapshots do not overwrite active statuses.

## Deviations

- None.

## Tradeoffs

- Live organization sync can still repair memberships and scoring groups, and explicit planned tee schedules still apply. Generated sequential schedules no longer overwrite existing live tee start holes.

## Open Questions

- None.
