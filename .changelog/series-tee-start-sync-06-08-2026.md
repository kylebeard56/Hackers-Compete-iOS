# Series Tee Start Sync

Date: 06-08-2026

## Scope Boundary

- Changed: Series-to-round tee sheet sync and lobby attendance rebuild planning for tee group starting holes, group counts, participants, teams, and tee-group score owners.
- Changed: Linked round configuration back-propagation is disabled so series round settings remain the source of truth.
- Changed: Live and paused linked rounds can now receive format and organization sync.
- Not touched: Game lobby rendering, live-round hole ordering, Firebase schemas, or completed-round outcome processing.

## Design Decisions

- Treat saved `SeriesRoundPlannedTeeGroup.startingHole` values as the source of truth when the commissioner syncs the tee sheet into a linked lobby round.
- Treat saved planned tee groups as the source of truth for sync membership and tee group cardinality, creating deterministic round tee groups when the series plan has grown.
- Create deterministic round team links/teams when legacy mappings are missing, so series-team organization sync can recover instead of failing preflight.
- Rebuild tee-group scoring owner documents during organization sync so scoring units reflect reshaped tee groups.
- Preserve the older freeform-lobby behavior only when the series round has no saved planned tee groups.
- Keep upward syncing for status/completion-derived work separate from settings sync; linked round settings no longer override series settings.

## Deviations

- None.

## Tradeoffs

- The sync planner now branches between planned tee schedule data and generated schedule data rather than changing the lower-level schedule helper globally, limiting impact to commissioner sync/rebuild flows.
- Organization sync now prunes non-series/removed participants from the linked round, which matches the current source-of-truth model but is intentionally stricter than ad hoc lobby editing.

## Open Questions

- Firebase verification for share code `MLQ` was blocked by expired local `gcloud` credentials.
