# Apple Watch Round UX Audit

Date: 08-18-2026

## Audit scope

Combined UX and screenshot-based accessibility audit of the active-round overview, tee-group score entry, field leaderboard, matchup summary, and supplied reference flow.

## User goal and accessibility target

Enter a tee group's scores quickly, understand personal gross/net position at a glance, review live standings, and move between holes with controls that are reliable on a small touch surface.

## Steps

1. Matchup summary (`01-matchup-truncation.png`) — Needs work. The primary state truncates and the large summary card pushes matchup detail below the initial viewport.
2. Field leaderboard (`02-leaderboard-truncation.png`) — Needs work. The current-user summary dominates the screen, standings truncate, and no grouping choice is exposed.
3. Round overview (`03-round-overview.png`) — Needs work. Hole navigation occupies the primary card even though entry, leaderboard, and matchups are the screen's main destinations.
4. Tee-group score entry (`04-score-entry.png`) — Mixed. The current hole and entered scores are clear, but chevrons have small visible targets and cumulative scoring exposes gross only.
5. Reference flow (`05-reference-flow.png`) — Healthy direction. It establishes a clear score-entry sequence, compact leaderboard controls, and task-specific hole navigation.

## Strengths

- Green is used consistently for active/progress state.
- Score rows have a predictable hierarchy: hole value, player, and cumulative value.
- The supplied reference keeps the most common scoring action prominent and moves secondary views into clear destinations.

## UX and accessibility risks

- The hole chevrons appear substantially smaller than the surrounding row, making missed taps likely.
- Truncated matchup and leaderboard text hides the user's current state instead of progressively reducing secondary detail.
- The round overview duplicates navigation that already belongs in score entry and does not answer the first glance question: "How am I scoring?"
- Gross-only cumulative values make handicap-adjusted progress difficult to understand.

## Evidence limits

- Screenshots do not prove VoiceOver labels, focus order, physical tap-target dimensions, Digital Crown behavior, or Smart Stack launch behavior. Those require implementation inspection and simulator/device checks.

## Recommendations

- Give previous/next controls a full 44-point hit region and explicit accessibility labels.
- Replace the overview hole navigator with paired gross/net score summaries and keep actions immediately below.
- Add Solo/Team/Group leaderboard chips only when the corresponding LiveRound grouping is meaningful.
- Show gross, net, and handicap context per leaderboard row using compact labels that can scale before truncating.
- Keep automatic progression to the next unscored tee-group player and expose that behavior in the save action label.
- Opt the Watch target into Live Activity launches and route the Live Activity URL into the current round's score screen.

## Implemented outcome

1. Matchup summary — Healthy. The primary state scales before truncation, probability remains secondary, and section details wrap to two lines.
2. Field leaderboard — Healthy. Solo/Team/Group chips mirror LiveRound availability; player rows carry handicap, gross, and net context.
3. Round overview — Healthy. The first card answers the personal gross/net question and leaves hole navigation inside scoring.
4. Tee-group score entry — Healthy. Previous/next controls have 44-point hit regions, the hole metadata stays on one line, and the footer switches cumulative Gross/Net values.
5. Score editor — Healthy. Saving advances to the next unscored tee-group player, and the action label announces whether the next destination is a player or hole.
6. Live Activity launch — Implementation complete. The Watch target declares Live Activity launch support and the lock-screen/Smart Stack family receives the round deep link.

## Visual comparisons

- `08-comparison-overview.png` — supplied round overview beside the score-first implementation.
- `08-comparison-scores.png` — supplied score entry beside the 44-point chevron implementation.
- `08-comparison-leaderboard.png` — supplied leaderboard beside the grouping-chip implementation.
- `08-comparison-matchups.png` — supplied truncated matchup beside the cleaned-up implementation.

## Remaining device check

- Validate a real Smart Stack or watch-face Live Activity tap on a paired physical Watch. Simulator and build checks cannot prove the system handoff path end to end.
