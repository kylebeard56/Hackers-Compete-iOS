# Live Activity Responsive Layout Design QA

Date: 08-17-2026

## Comparison Target

- Source visual truth: `/tmp/codex-remote-attachments/01a01181-9a62-7800-bc29-5f15dba49cad/DFD84728-C7AE-4A31-BA21-F327786BCC7A/1-Pasted-Image-1.jpg` and `/tmp/codex-remote-attachments/01a01181-9a62-7800-bc29-5f15dba49cad/DFD84728-C7AE-4A31-BA21-F327786BCC7A/2-Photo-2.jpg`.
- Latest implementation screenshot: `/Users/kylebeard/Developer/Hackers-Compete-iOS/Documentation/live-activity-visual-audit-2026-08-17/38-counting-pill.png`. Earlier responsive phone/watch evidence remains in `29-progress-odds-iphone-clean.png`, `30-watch-simplified-clean.png`, and `37-figure-golf-counting-context.png`.
- Combined comparisons: `/Users/kylebeard/Developer/Hackers-Compete-iOS/Documentation/live-activity-visual-audit-2026-08-17/35-phone-feedback-comparison.png` and `/Users/kylebeard/Developer/Hackers-Compete-iOS/Documentation/live-activity-visual-audit-2026-08-17/36-watch-feedback-comparison.png`.
- Viewport: iPhone 17 Pro simulator, 402 × 874 points at 3× density. The watch supplemental family was rendered at its intended 184 × 96-point content size within the same native SwiftUI harness.
- Source pixels: iPhone 1206 × 516; watch 410 × 504. Focused source crops: iPhone 1130 × 435; watch 345 × 120.
- Implementation pixels: 1206 × 2622. Focused implementation crops: iPhone 1146 × 450; watch 556 × 292.
- Density normalization: each focused source and implementation crop was independently resampled to 720 pixels wide for side-by-side comparison; geometry was judged within each platform family rather than across phone and watch sizes.
- State: dark appearance, Sarah Beard, Hole 8, Par 4, +3 gross, Net +3, T5 of 8, Down 5, 5% win probability, seven of nine holes complete.

## Findings

No actionable P0, P1, or P2 differences remain.

- Fonts and typography: The iPhone keeps the established native San Francisco hierarchy. `DOWN 5` and `5% WIN` occupy separate lines with no ellipsis. The watch uses fewer, smaller roles and retains clear gross-versus-net color contrast without wrapped numbers.
- Spacing and layout rhythm: The phone card keeps the screenshot-3 geometry while removing both the redundant player name and progress footer. `T5 of 8` sits directly beneath gross/net; the right side is reserved for matchup context. The watch removes the divider and participant name, leaving enough horizontal room for hole/par, scores, holes left, and the optional short standing.
- Colors and visual tokens: Both surfaces preserve the restrained olive-black background, white primary hierarchy, gray supporting text, and lime status color. Contrast remains legible in the clean simulator capture.
- Image and icon fidelity: The only visible graphic is the native `figure.golf` SF Symbol inside the single-color radial progress indicator. The simulator render confirms that the golfer and ball remain recognizable at Live Activity size. No placeholder or code-drawn asset substitutes are present.
- Copy and content: Hole progress is not duplicated on the medium card. Gross and net remain adjacent, field position appears immediately below, and a solid green `COUNTING` capsule appears above the matchup differential only when the scoring engine reports that the personal score counts. Match standing and odds remain user-relative. The watch intentionally omits win odds and leaderboard rank; it shows `2 LEFT` and, when space permits, `DOWN 5`.

## Comparison History

1. Source feedback identified two P1 problems: the phone truncated `DOWN 5 · 5%...` and repeated hole progress; the watch truncated the hole, score, match standing, and completion count.
   - Fixes: separated match standing from odds, consolidated progress into one label, added responsive long/short odds variants, and created a dedicated small-family hierarchy.
   - First phone evidence: `26-progress-odds-iphone.png`. The layout passed, but the simulator account modal dimmed the capture.
2. The first watch revision still had P1 truncation because it attempted full gross/net labels and retained a trailing divider.
   - Fixes: removed the divider and gross prefix, abbreviated net to `N +3`, shortened remaining progress to `2 LEFT`, and tightened padding to the 8-point grid.
   - Pre-fix evidence: `27-watch-simplified.png`. Post-fix evidence: `28-watch-simplified-revised.png`.
3. Both surfaces were recaptured on a clean iPhone 17 Pro simulator with no account modal or dimming.
   - Post-fix evidence: `29-progress-odds-iphone-clean.png`, `30-watch-simplified-clean.png`, `35-phone-feedback-comparison.png`, and `36-watch-feedback-comparison.png`.
4. The approved final hierarchy removed the player name and medium-card footer, moved field position beneath gross/net, added an engine-backed counting checkmark, and changed the flag to `figure.golf`.
   - Final evidence: `37-figure-golf-counting-context.png`. `DOWN 5`, `5% WIN`, `T5 of 8`, both score values, and the symbol all render without truncation.
5. The ambiguous counting checkmark was replaced with a labeled capsule above the matchup differential.
   - Final evidence: `38-counting-pill.png`. `COUNTING` fits in the 96-point trailing column with no scale factor, and `DOWN 5` plus `5% WIN` remain fully visible.

## Focused Region Comparison

Focused comparisons isolate the complete Live Activity surfaces because truncation, wrapping, score hierarchy, progress copy, and radial-loader geometry are all legible there. The surrounding lock-screen wallpaper and watch system chrome are not app-owned and were excluded from fidelity judgments.

## Follow-up Polish

- P3: Confirm the actual watchOS supplemental Activity family on a physical 40–42 mm watch, where system margins may differ slightly from the 184 × 96-point harness.

## Final Result

final result: passed
