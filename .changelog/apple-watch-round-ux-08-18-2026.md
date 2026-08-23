# Apple Watch Round UX

Date: 08-18-2026

## Scope Boundary

- Changed: Apple Watch round overview, hole scoring navigation, score summaries, field leaderboard grouping and row details, matchup layout, score-entry progression clarity, and Live Activity launch configuration.
- Follow-up: restore the Leaderboard action when player-level projection rows are unavailable and compact the score editor footer for physical Watch layouts.
- Not touched: iPhone LiveRound interaction design, score persistence rules, competition scoring formulas, or WatchConnectivity transport semantics.

## Design Decisions

- The round overview prioritizes the current golfer's gross and net round state; hole navigation stays in the score-entry flow where it has task context.
- Partial-round totals are shown relative to par; completed-round totals are shown as absolute stroke totals.
- Leaderboard grouping mirrors the LiveRound availability rules and uses compact Solo/Team/Group chips.
- Field standings fall back to direct per-player stroke projection when matchup-scoped scoring cannot produce individual-contribution rows, and the overview keeps the Leaderboard destination visible during projection or sync gaps.
- The score editor keeps its full-width touch target while insetting the visible save/update capsule from the Watch screen edges.

## Deviations

- None.

## Tradeoffs

- Leaderboard rows favor compact gross/net/handicap context over longer secondary player or team descriptions on the smallest Watch displays.

## Validation

- 46 mm watchOS simulator build and visual comparison completed for overview, scoring, leaderboard, matchup, and score editor.
- Follow-up Watch target build succeeded on the 46 mm watchOS simulator after the leaderboard fallback and score-button inset changes.
- Live Activity extension target builds with the lock-screen/Smart Stack deep link applied.
- Focused companion contract suite passes, including partial `+11` gross / `+5` net normalization and per-player leaderboard grouping context.
- Added a matchup-scope leaderboard regression test; Xcode compiled the test target, but Xcode 27 simulator execution is blocked by the existing Sandbox scheme embedding a watchOS-device app inside its iOS-simulator bundle.
- Final source diff passes whitespace/error checks.

## Open Questions

- Physical-device verification is still required for Apple Watch Smart Stack Live Activity launch behavior.
