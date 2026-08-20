# Apple Watch Scoring Redesign

Date: 08-17-2026

## Scope Boundary

- Changed: Watch round overview, tee-group scoring rows, score entry, leaderboard/matchup navigation, and the paired iPhone projection needed by those screens.
- Not touched: Score mutation authority, Watch Connectivity delivery, Firestore persistence, Live Activity layouts, or iPhone live-round screen design.

## Design Decisions

- Use a dedicated round overview as the Watch root while preserving direct deep links to a selected scoring hole.
- Show each tee-group row as current-hole gross score, adaptive player name, and cumulative gross total without profile imagery.
- Treat the dash as a draft clear value and require an explicit save so Crown movement never writes a score.
- Keep Crown rotation and the side-mounted minus/plus buttons synchronized through one draft value, with a bold central score as the primary focus.
- Keep leaderboard and matchups as independent destinations when both are available.
- Derive cumulative gross totals on Watch so optimistic pending scores update the total immediately.
- Persist the live-round name format so the companion projection and visible iPhone round use the same compact-name preference.
- Show each individual leaderboard row's locked round handicap allowance as its subtitle.
- Keep the optional Watch payload additions on schema v1 so already-installed Watch builds can decode snapshots sent by a newly updated iPhone app.
- Queue the latest application context until `WCSession` activates, retry it when Watch state changes, and have Watch consume `receivedApplicationContext` at activation.
- Place the Watch activation prompt in the vertically scrollable hole page immediately above the Par/Yards/HCP/Tee tiles.

## Deviations

- Reuse the iPhone scoring semantics rather than the `LiveHoleScoringView` component itself because the iPhone view depends on app-only UI and state.

## Tradeoffs

- A custom Crown-bound score readout better matches the visual reference; touch decrement/increment controls remain available for discoverability and accessibility.
- The shared Watch payload remains presentation-sized; only optional UI metadata and an additional competition collection were added.
- A simulator-only launch flag exposes the fixture round for visual QA without affecting physical-device or production behavior.

## Open Questions

- None.

## Verification

- The standalone Sandbox Watch app builds successfully for generic watchOS with code signing disabled.
- The paired Sandbox app builds successfully for generic iOS with code signing disabled.
- The Sandbox Watch app builds and runs successfully on a 46 mm Series 11 simulator; the visual pass corrected score-editor navigation overlap and verified all controls fit onscreen.
- The Watch activation compatibility/retry changes build successfully in both the standalone Watch target and paired Sandbox iOS target.
- Focused companion contract tests compile, but Xcode cancels simulator execution while validating the embedded Watch app because it was built for watchOS rather than watchOS Simulator.
- The updated legacy-schema regression test compiles in `build-for-testing`; the existing embedded-Watch simulator validation issue still prevents the test bundle from completing its host build.
- `git diff --check` passes.
