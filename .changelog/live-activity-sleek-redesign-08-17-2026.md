# Live Activity Sleek Redesign

Date: 08-17-2026

## Scope Boundary

- Changed: Lock Screen, Dynamic Island, and supplemental Apple Watch information hierarchy, progress treatment, participant identity, leaderboard context, and matchup context.
- Not touched: Activity lifecycle, deep links, push delivery, score computation, or prediction computation.

## Design Decisions

- Ground the redesign in the compact solo card from reference screenshot 3: current hole and personal score remain primary; leaderboard or matchup context sits in a narrow trailing summary.
- Omit the current participant's display name on the Lock Screen and expanded Island because the activity already represents the signed-in player.
- Use one solid-color progress treatment throughout rather than per-hole dots or multicolor gradients.
- Use the radial hole indicator as the primary completion loader on Lock Screen cards; keep the textual `17 / 18` count and remove the visually dominant full-width bar.
- Match screenshot 3's compact hierarchy with larger score/context type, deliberate internal spacing, and a softer olive-black surface.
- Align the hole, score, and leaderboard stack beside the radial progress mark so the card remains quickly scannable without an identity row.
- Restore screenshot 3's two-score treatment: gross score is the large white value and net score is the adjacent green `Net +2` value. Both scores now come from the live scoring state.
- Compact Dynamic Island content is limited to the current score and one adaptive context value: match standing, field position, or current hole.
- Matchup rounds show user-relative standing and win probability; field rounds show rank and field size when available.
- Matchup rounds also derive Kyle's individual stroke-play field position when scored leaderboard rows are available, allowing the screenshot-3 hierarchy to show `T3`, `OF 24`, and `UP 4 · 80% WIN` together.
- Remove the redundant progress footer from the medium card. Individual position now occupies the space beneath gross/net, while win odds have a dedicated line beneath match standing in the trailing column.
- Treat the small supplemental Activity family as a watch-specific hierarchy: hole/par, gross/net, holes left, and an optional short match standing. Participant name and win odds are intentionally omitted.
- Remove the redundant player name from the medium Live Activity. Place individual position beneath gross/net, reserve the trailing column for user-relative matchup standing and win odds, and show a green checkmark only when the scoring engine reports that the personal score is counting.
- Replace the flag glyph with the native `figure.golf` SF Symbol across Lock Screen, watch supplemental, and expanded Dynamic Island presentations.
- Replace the ambiguous counting checkmark with a conditional `COUNTING` capsule above the matchup differential on the medium card and expanded Dynamic Island. Use black text on the bright green fill for consistent contrast; omit the capsule entirely when the personal score is not counting.

## Deviations

- iOS controls the Dynamic Island capsule's outer size. The implementation minimizes the requested width by shortening both compact regions rather than setting a fixed capsule width.

## Tradeoffs

- The combined leaderboard/match treatment uses the ordinary individual stroke leaderboard for rank while preserving the active head-to-head result as the secondary context.
- The watch layout preserves the progress ring and a terse match standing when space permits, but removes leaderboard position because hole, score, and remaining-hole context are more useful at glance size.
- `COUNTING` is slightly wider than `SCORING`, but it is the clearer description and still fits the existing 96-point matchup column without scaling or truncation.
- ActivityKit does not provide wallpaper translucency controls for the Live Activity surface, so the reference's glassy olive character is approximated with an opaque olive-black system tint.

## Open Questions

- Confirm on a physical Dynamic Island device that the compact score/context pair has the preferred breathing room at the largest accessibility text sizes supported by Live Activities.

## Verification

- The `HackersLiveActivity` target builds successfully for iPhone Simulator.
- The complete Sandbox scheme builds successfully for a generic iPhone device, including the app-side state builder and shared ActivityKit contract.
- Matchup, individual, and team fixtures were rendered in a native iPhone Simulator harness at 368 × 800 points and visually checked for hierarchy, clipping, contrast, and progress-bar fit.
- The final individual, combined matchup, and team states were recaptured on a clean iPhone 17 Pro simulator at 402 × 874 points; the individual card passed a normalized side-by-side comparison against screenshot 3.
- The latest Sarah Beard matchup state was recaptured on a clean iPhone 17 Pro simulator. The iPhone card shows `DOWN 5` and `5% CHANCE TO WIN` on separate lines, while the small supplemental family shows `H8 · P4`, gross/net, `2 LEFT`, and `DOWN 5` without truncation.
- Both feedback states passed normalized side-by-side visual comparisons recorded in `Documentation/live-activity-visual-audit-2026-08-17/design-qa.md`.
- The `HackersLiveActivity` simulator target and complete generic-device Sandbox scheme build successfully after the responsive layout changes.
- The approved no-name hierarchy was rendered again on a clean iPhone 17 Pro simulator. The production SwiftUI card shows `figure.golf`, `+3` / `Net +3`, `T5 of 8` with a counting checkmark, `DOWN 5`, and `5% WIN` without clipping.
- The counting checkmark replacement was rendered on a clean iPhone 17 Pro simulator. `COUNTING` fits above `DOWN 5` in the existing trailing column, uses high-contrast black text on green, and leaves `5% WIN` untruncated. The extension target builds successfully with the same pill in expanded Dynamic Island.
- The normal iPhone Simulator host build remains blocked by the existing project configuration embedding a watchOS-device app in an iOS Simulator host; the extension-only simulator build is unaffected.
