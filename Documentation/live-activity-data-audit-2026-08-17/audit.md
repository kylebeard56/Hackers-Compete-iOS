# Live Activity Data Hierarchy Audit

Date: 08-17-2026

## Audit Scope

- Surface: iPhone Lock Screen Live Activity.
- Evidence: `01-current-live-activity.png`.
- State: Hole 8, Par 4, +3 gross, Net +3, Sarah Beard, T5 of 8, Down 5, 5% win probability, seven of nine holes complete.
- User goal: understand current scoring and competitive position in one glance without opening the app.

## Step 1 — Read the Live Activity

General health: good foundation, but one hierarchy pass away from excellent.

### Strengths

- Gross and net are easy to compare because value, color, and proximity work together.
- Hole and par are immediately legible.
- The radial progress loader is compact and avoids per-hole dots.
- Rank, match standing, and win probability are all available without interaction.

### UX Risks

- The card has four competing focal points: score, player name, rank, and match context. Nothing clearly answers “what changed most recently?”
- `THRU 7 OF 9` duplicates the radial loader while consuming a full footer slot.
- `5% CHANCE TO WIN` is longer than needed; `5% WIN` communicates the same result at glance speed.
- `T5` and `OF 8` consume two stacked rows even though `T5 of 8` is one concept.
- Sarah’s name is visually louder than the match state. That is only warranted when the phone may be tracking multiple players.

### Accessibility Risks

- The gray supporting text appears relatively low contrast against the olive-black background; exact contrast requires measuring the rendered colors.
- Green is doing several jobs—net score, match standing, odds, and progress. Text labels prevent color-only meaning, but reducing the number of green elements would improve scanning.
- VoiceOver order should follow hole/score, match result/odds, then identity/rank/progress. Screenshot evidence cannot confirm the implemented reading order.

## Recommended Composition

Keep every important fact, but collapse it into three glance groups:

1. Primary left: radial progress, `Hole 8 · Par 4`, `+3  Net +3`.
2. Primary right: large `DOWN 5`, smaller `5% WIN`.
3. Footer: `Sarah Beard · T5 of 8` on the left and `2 HOLES LEFT` on the right.

This removes no decision-useful data. It combines rank and field size, converts redundant elapsed progress into actionable remaining progress, shortens the probability label, and demotes identity from headline to context.

## Implementation Priorities

1. Promote `DOWN 5` to the main right-side value and place `5% WIN` directly beneath it.
2. Move `Sarah Beard · T5 of 8` into one footer label.
3. Replace `THRU 7 OF 9` with `2 HOLES LEFT`.
4. Remove the vertical divider if spacing alone still separates the two main groups.
5. Reduce card height after the large name row is removed.

## Evidence Limits

- This is a single-state screenshot audit. It does not verify Dynamic Type, Always-On dimming, long names, missing odds, tied matches, completed rounds, or VoiceOver behavior.
