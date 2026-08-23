# Live Activity and Watch Polish

Date: 08-16-2026

## Scope Boundary

- Changed: Live Activity matchup hierarchy, user-relative match standing, optional win odds, rolling staleness, Watch Smart Stack background, and Sandbox Watch installation/identity feedback.
- Changed: Added Hackers Golf branding, format context, field/team standings, current-hole score state, and current-hole handicap strokes through configuration-aware templates.
- Changed: Recomposed the expanded Live Activity for the 160-point system height budget with adaptive light/dark presentation, and corrected Watch SDK selection for device and simulator destinations.
- Changed: Shifted the Live Activity from card-first to score-first hierarchy, moved round completion into the personal-score ring, and repurposed the footer meter for matchup win probability.
- Not touched: ActivityKit remote push delivery, backend/APNs infrastructure, production bundle identities, or the Firestore scoring model.

## Design Decisions

- Always show a valid two-sided matchup when the current player is participating; win probability enhances that presentation but is not required for it.
- Present `UP`, `DOWN`, or `TIED` from the current player's side, with the stroke or point differential and optional probability to win.
- Let ActivityKit's `staleDate` determine staleness after a rolling 20-minute window instead of marking the activity stale as soon as the app backgrounds.
- Use adaptive warm-light and deep-turf-dark palettes so the Live Activity stays branded and readable on the Lock Screen and watchOS Smart Stack without forcing one appearance.
- Name and icon the embedded Sandbox Watch app distinctly from production and expose paired/installed state in the iPhone UI.
- Keep a stable outer hierarchy—brand/course, competitive context, personal score, then progress—while selecting matchup, team, individual-field, or generic hole content for the center panel.
- Use text plus a native flag glyph for compact branding; bundling the full application image catalog into the Live Activity extension would add unnecessary weight for a small header mark.
- Treat the Live Activity as a glanceable status card: one compact brand/status row, one primary competitive statement, one personal-score pill, and a restrained progress footer.
- Keep competitive position and score understandable without relying on accent color alone.
- Keep the Watch and iPhone bundle relationship configuration-specific while allowing Xcode to select `watchos` or `watchsimulator` from the active destination.
- Answer three glance questions in order: what is live, what is my score, and how is my team doing.
- Show both matchup sides' scores and up to two currently counting player names; avoid repeating confidence, differential, or format labels when the scoreline already provides that context.

## Deviations

- Scores received while iOS grants background runtime can still update the activity, but guaranteed updates after suspension are deferred because they require ActivityKit push notifications from a server.
- Counting-player names come from the canonical scoring projection and are limited to two names per side to preserve glanceability; configurations without a resolved selection show a pending label instead of guessing.

## Tradeoffs

- The 20-minute stale window avoids an immediately broken-looking activity during normal play, but the last-known score may remain visible until that deadline when the phone app is suspended and no remote push path exists.
- Win odds remain absent when the prediction model does not support the matchup rather than displaying invented or stale probability data.
- Team and field positions only appear after a canonical scoring row exists and remain hidden during unrevealed secret scoring.
- The course name and format are no longer repeated in the matchup layout; they remain available in accessibility context and in non-matchup fallbacks where they add useful meaning.

## Open Questions

- Enable Developer Mode on the paired physical Watch, re-trust it in Xcode Device Hub, and validate installation of the newly distinguished purple `Hackers Sandbox` Watch app.
- Decide whether to add backend ActivityKit push delivery for canonical scoring updates while the iPhone app is suspended.

## Verification

- Compared the crowded reference state and the redesigned `DOWN 5` / 5% early-odds state together; the redesigned card stays inside the system height, preserves the matchup and personal score, and no longer clips its footer.
- Captured accepted light, dark, team, and individual Live Activity simulator renders in `Documentation/Simulator-Renders`.
- The Live Activity extension builds successfully for iPhone Simulator after the component split and adaptive styling pass.
- The standalone Sandbox Watch target builds successfully for Apple Watch Series 11 Simulator with destination-selected SDKs.
- The complete unsigned Sandbox device package builds successfully and validates both embedded binaries, including `Hackers.app/Watch/Hackers Watch App.app`.
- The built Sandbox Watch companion reports bundle `com.tigermindlabs.hackers.compete.sandbox.watchkitapp`, companion bundle `com.tigermindlabs.hackers.compete.sandbox`, and `WKApplication = true`.
- Physical iPhone and Watch development services are currently unavailable, so the integrity-error retest remains a device step after Developer Mode and Xcode trust are restored.
- The score-first matchup, team, and individual fixtures render without clipping in the iPhone 17 Pro simulator in both supported color appearances.
- The final Live Activity extension builds successfully for iPhone Simulator, and the complete unsigned Sandbox device package validates the embedded Live Activity and Watch binaries.
- Matchup-side decoding remains backward compatible when older activity state omits the optional counting-player field.

- The complete development-signed Sandbox package builds successfully for the connected physical iPhone and was installed as an in-place Sandbox update.
- The embedded companion resolves to `com.tigermindlabs.hackers.compete.sandbox.watchkitapp`, names itself `Hackers Sandbox`, points to the Sandbox iPhone bundle, and selects `AppIcon-V3-Sandbox`.
- The iPhone app, Watch app, and Live Activity extension all carry valid Apple Development signatures for team `28EF5GR4R6`.
- Focused contract tests compile, including matchup perspective, rolling stale interval, and progress coverage. Simulator execution remains blocked by the existing scheme embedding a watchOS-device product in an iOS Simulator host.
- Device diagnostics report that the paired Watch has Developer Mode disabled and cannot establish development services; this prevents direct validation or installation of the development-signed Watch app until the setting is enabled on-device.
- The four-template Live Activity implementation builds successfully in both unsigned generic-device and development-signed physical-device configurations; the signed build was installed on the connected Sandbox iPhone.
- Contract coverage for field ranking, ties, points-vs-strokes ordering, and decoding states without the new optional fields compiles successfully. Execution remains blocked at the existing iOS Simulator/watchOS-device embed validation step.
