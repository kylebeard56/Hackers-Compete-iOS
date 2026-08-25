# Handoff: User Testing Feedback Plan

## Context

You're continuing work on the **User Testing Feedback Fixes** plan. Stages 1–2 are done. Dynamic layout (content-driven sizing with `@ScaledMetric`) has been applied to key components.

## Completed

- **Stage 1:** Round sync bugs (onReceive for status, replacingCurrent nav, round.players fix, loadRounds after join)
- **Stage 2:** Glass effect capability, accessibility (ScaledFont, PlayerScoringRow)
- **Dynamic layout:** `@ScaledMetric` added to:
  - `PlayerScoringRow` – pill, dots, button padding
  - `LeaderboardRowView` – place, team dot, score, thru, star
  - `LiveRound` – leaderboard header, skeleton rows
  - `LiveHoleScoringView` – player circles, badge, score input height, handicap dots
  - `GameLobby` – player avatar size (36)

## Plan file

Full plan: [.cursor/plans/user_testing_feedback_fixes_013c9878.plan.md](.cursor/plans/user_testing_feedback_fixes_013c9878.plan.md)

## How to continue (new session)

1. **Start a new chat** to avoid context limits.
2. **Reference this file:** `@HANDOFF.md` or “continue user testing feedback plan”.
3. **Specify the stage:** e.g. “Implement Stage 3” or “Do Stage 4 leaderboard changes”.

## Remaining stages (summary)

| Stage | Focus | Key files |
|-------|-------|-----------|
| 3 | Live round layout, hole tab in nav, hero card for hole details, tee box toggle | LiveRound.swift, LiveRound+Scoring.swift |
| 4 | Course name at bottom, name display, skeleton alignment | LiveRound+Scoring.swift, PlayerScoringRow |
| 5 | Settings menu (edit, share, preferences, finish round) | LiveRound.swift |
| 6 | Scorecard tap-to-edit, visibility toggle | FullScorecardView.swift |
| 7 | Scoring flow, CTAs, auto-navigate | LiveHoleScoringView.swift |
| 8 | Score chip D/T/Q Bogey, hole tab styling | LiveRoundViewModel, HoleWindowSelector |
| 9 | Spectator mode | Join flow, round state |

## Other hardcoded dimensions (optional)

If you want more dynamic layout, consider:

- `FullScorecardView.swift` – row heights, cell widths
- `ScorecardHoleCell.swift` – 34x34 cells
- `CarouselNumberPicker` – item dimensions
- `ScorecardSheet.swift` – column widths
