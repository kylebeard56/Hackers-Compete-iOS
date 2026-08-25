# Series Tee Start Sync

Date: 06-08-2026

## Scope Boundary

- Changed: Series-to-round tee sheet sync and lobby attendance rebuild planning for tee group starting holes, group counts, participants, teams, and tee-group score owners.
- Changed: Linked round configuration back-propagation is disabled so series round settings remain the source of truth.
- Changed: Live and paused linked rounds can now receive format and organization sync.
- Changed: Saving linked lobby-affecting series round settings now pushes a full series-to-round sync into the linked lobby round.
- Changed: Manual sync resolves the latest `SeriesRound` from `SeriesViewModel.rounds` before writing, avoiding stale sheet-captured max score or planned tee group values.
- Changed: `SeriesViewModel` now listens realtime to the series root document and series rounds subcollection so source settings and planned tee groups stay current before sync.
- Changed: Sync applies the league default max score when present, so existing linked rounds follow league-level max-score changes.
- Changed: Lobby organization sync now applies a full reconciliation plan: source-derived round config, tee groups, teams, participants, scoring groups, mappings, and segment replace the stale linked lobby shape.
- Changed: Game lobby tee group display now respects persisted tee-group index order from the round/series plan instead of sorting cards by starting hole.
- Not touched: Live-round hole ordering, Firebase schemas, or completed-round outcome processing.

## Design Decisions

- Treat saved `SeriesRoundPlannedTeeGroup.startingHole` values as the source of truth when the commissioner syncs the tee sheet into a linked lobby round.
- Treat saved planned tee groups as the source of truth for sync membership and tee group cardinality, creating deterministic round tee groups when the series plan has grown.
- Create deterministic round team links/teams when legacy mappings are missing, so series-team organization sync can recover instead of failing preflight.
- Rebuild tee-group scoring owner documents during organization sync so scoring units reflect reshaped tee groups.
- Use the lobby reconciliation path when the linked round is still in the lobby and organization sync is selected, because that is the state where tee groups, teams, and lobby participants can be safely torn down and rebuilt from the series round.
- Trigger the linked lobby sync from the series round save path, not only from the manual Sync Round sheet or RSVP rebuild flow.
- Preserve the older freeform-lobby behavior only when the series round has no saved planned tee groups.
- Keep upward syncing for status/completion-derived work separate from settings sync; linked round settings no longer override series settings.

## Deviations

- None.

## Tradeoffs

- The sync planner now branches between planned tee schedule data and generated schedule data rather than changing the lower-level schedule helper globally, limiting impact to commissioner sync/rebuild flows.
- Organization sync now prunes non-series/removed participants from the linked round, which matches the current source-of-truth model but is intentionally stricter than ad hoc lobby editing.
- Global League Settings defaults are still stored separately from existing series round docs; sync resolves max score from the league default before writing to the linked round.
- The linked round session already listens realtime to the round document and subcollections; this change adds realtime source listeners for the commissioner series root and rounds but keeps the sync-time linked round snapshot read so reconciliation has the current linked shape before writing.
- Production read-only verification for share code `MLQ` showed the source series round and linked round tee groups now match by persisted index (`2,3,4,5,6,7,8,9,1,1`), while the lobby was still visually ordering by starting hole (`1A,1B,2...`). The fix therefore moved to the lobby display ordering rather than the sync writer.

## Open Questions

- None.
