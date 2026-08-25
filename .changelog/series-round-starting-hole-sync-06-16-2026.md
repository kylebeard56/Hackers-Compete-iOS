# Series Round Starting Hole Sync

Date: 06-16-2026

## Scope Boundary

- Changed: Series-to-live-round creation/sync flow for linked lobby rounds, focused on preserving series planned tee group starting holes in the game lobby.
- Not touched: Firebase production data repair, scoring calculations, live-round score entry, or unrelated substitute planning changes already present in the worktree.

## Design Decisions

- Treat a missing `linkedRounds` cache entry as recoverable by fetching the linked Round before sync, so series edits can still push tee sheet changes into lobby state.
- Run a post-create lobby reconciliation for newly created series rounds to force the live Round tee groups back to the saved series plan before the lobby is shown.
- Treat SeriesRound "Shotgun start" as an initial tee-sheet helper only: it staggers planned tee groups in SeriesRound, while linked live Rounds store those authored starts with their own sequential generator disabled.
- Guard the manual Round shotgun toggle so rehydrating an already-enabled value does not resequence tee groups again.
- Rebuild live/lobby RoundSession listeners on every activation instead of reusing a warm same-round session, and load a server-backed RoundSnapshot before attaching realtime listeners.
- Ignore cache-only Firestore listener snapshots so stale local listener data cannot overwrite the fresh server-backed RoundSnapshot.
- Firestore check for NSB showed `planned_tee_groups` saved correctly on the SeriesRound while the linked Round `tee-groups` subcollection still held sequential starts.

## Deviations

- None.

## Tradeoffs

- The post-create reconciliation may repeat some writes that creation already performed, but it keeps creation and later linked-lobby edits on the same repair path.

## Open Questions

- NSB was repaired in production before this note was updated; Firestore now has the authored tee-group starts and `sequential_tee_starts_enabled` is false on the linked Round.
