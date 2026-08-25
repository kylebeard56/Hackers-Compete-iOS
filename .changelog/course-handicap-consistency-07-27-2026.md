# Course Handicap Consistency

Date: 07-27-2026

## Scope Boundary

- Changed: Series Course HCP resolution and round snapshots, commissioner correction publication safety, and guarded GBB repair tooling.
- Not touched: The underlying league handicap-index formula, unrelated round formats, or production data without an explicit repair command.

## Design Decisions

- The roster Course HCP and series round creation share one resolver and participant-specific tee validation.
- Round participants retain an optional, auditable handicap-input snapshot while legacy rows continue using their persisted scoring allowance.
- A completed round keeps its frozen Course HCP; its gross score can affect only later handicap projections.
- Commissioner score changes are written as one revision-guarded batch and recomputed once.
- Total-gross correction is limited to pure participant stroke totals; hole-dependent formats require real hole scores.
- Aggregate stroke-play matchups are total-only when they sum each participant per round and apply only a terminal stroke-difference comparison; GBB meets this rule.
- Round awards are marked finalized only after handicap, award, canonical and standings publication succeeds.
- GBB repair defaults to dry-run and requires an explicit write flag plus source-revision preconditions.

## Deviations

- Handicap and award replacements are independently atomic Firestore batches. Canonical publication retains its existing generation/state transaction, then standings publish as a series-wide follow-up. The round remains pending until all stages succeed, so a failed stage cannot replace the last valid leaderboard.

## Tradeoffs

- Legacy and explicitly configured stroke-entry rounds retain the low-level calculator fallback; new Course HCP series rounds fail preflight instead of silently changing modes.
- A correction source batch is all-or-nothing, so the UI reports the batch failure instead of exposing per-player partial-write retry state.

## Open Questions

- Official front-nine rating/slope values for every tee used by GBB must be supplied before GBB can count toward future handicap calculations.

## GBB Read-Only Verification

- Production target: GE League 2026 / Week 11 / GBB at The Preserve at Verdae, front nine.
- Confirmed 33 participant documents, 297 score documents, nine scores per participant, and zero pickups.
- Confirmed all gross totals match the supplied Excel screenshot.
- Confirmed Karis is currently `red_male` with 17 strokes; the repair manifest sets `red_female` and the authoritative Course HCP of 14.
- Created a Git-ignored local manifest with current round, series-round and canonical revision guards.
