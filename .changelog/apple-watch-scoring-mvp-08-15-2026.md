# Live Round Watch Scoring and Live Activity

Date: 08-15-2026

## Scope Boundary

- Changed: Implementing shared scoring commands, selected-round state, paired Watch scoring, WatchConnectivity synchronization, and a single selected-round Live Activity/Dynamic Island experience.
- Not touched: Direct Watch-to-Firebase access, GPS/HealthKit/shot tracking, Watch leaderboards, and ActivityKit remote push updates.

## Design Decisions

- Use a scoring-only watchOS companion with native list, navigation, and Digital Crown Picker patterns.
- Use the iPhone as the authenticated Firestore authority and Watch Connectivity as the transport.
- Resolve canonical scoring subjects on iPhone so individual and shared-score formats use the same identifiers and permissions as the existing scorecard.
- Persist separate selected rounds for Watch scoring and the single Live Activity so either surface can run independently, including against different active rounds.
- Persist Watch commands before delivery and deduplicate immediate and background delivery by mutation ID.
- Select the Live Activity presentation from the round context: a two-sided matchup scoreboard when authoritative matchup data and probabilities are available, otherwise current-hole context.
- Define round progress as completed holes divided by scheduled holes. Selecting the next hole does not mark that hole complete.
- Give Watch scoring and Live Activity independent round sessions and update pipelines; enabling or disabling either surface does not alter the other.

## Deviations

- The Watch app opts into tap-to-launch from supported Live Activities. watchOS still controls Smart Stack presentation and only launches the app after a person taps the activity.
- ActivityKit remote push updates are deferred; the first implementation updates on-device and marks the activity stale when the iPhone cannot keep it current.

## Tradeoffs

- The paired approach reuses existing authentication and Firestore logic, but queued edits cannot become canonical until the iPhone can receive them.
- Explicit Save and Save & Next actions add confirmation but prevent Digital Crown movement from writing accidentally.
- The Live Activity intentionally stays presentation-only; score entry remains in the authenticated app or Watch flow.
- Running Watch scoring and Live Activity for the same round uses two lightweight listeners so their lifecycle and round selection remain independent.

## Implemented

- Added portable versioned round snapshots, score mutations, acknowledgements, and Live Activity attributes shared only with the surfaces that consume them.
- Added an iPhone companion coordinator that owns the selected round, canonical score validation and writes, Watch projection, mutation deduplication, and ActivityKit reconciliation.
- Added a scoring-only watchOS app with round empty state, hole navigation, prior-score editing, individual and shared-score subjects, explicit save actions, persisted offline delivery, and visible pending/conflict states.
- Added Lock Screen, Dynamic Island, and watchOS Smart Stack Live Activity presentations for hole, personal score, team score, and participant-side matchup probability when that value is supported and safe to reveal.
- Reworked the Live Activity into restrained, adaptive layouts: a boxed personal score on the right, Red-vs-Blue-style score and win-odds treatment for matchups, and hole/par/yardage/remaining context for other formats.
- Fixed the progress track so 17 completed holes in an 18-hole round displays 94.4% rather than full.
- Added both matchup sides, formatted matchup scores, per-side probabilities, and selected-hole metadata to the shared ActivityKit state.
- Matched the Watch icon to the configuration-specific iPhone icon, declared Watch Live Activity launch support, and added a shared `Hackers Watch App - Sandbox` run scheme.
- Added a persistent Live Activity toggle to the in-round gear menu and corrected the inverted “Show scoreless” menu indicator.
- Decoupled “Use on Apple Watch” from Live Activity activation: the dashboard action now controls Watch scoring only, while the in-round gear toggle controls ActivityKit only.
- Added dashboard round selection, Live Activity deep-link routing, Watch score-entry telemetry, and logout/background lifecycle handling.
- Added contract coverage for snapshot encoding, selected-round policy, tee-group projection, deep links, mutation deduplication, and stale-score conflicts.
- Added contract coverage for independently persisted Watch and Live Activity round selections and migration from the previous coupled preference.

## Verification

- The complete `Sandbox` physical-device package builds successfully for generic iOS, including the iPhone app, embedded watchOS app, and Live Activity extension.
- The complete `Sandbox` physical-device package also builds successfully after separating the Watch and Live Activity selections and update pipelines.
- The Live Activity extension builds directly for the iOS simulator.
- The shared `Hackers Watch App - Sandbox` scheme builds successfully, including the V3 Sandbox icon catalog.
- The final embedded Watch product was inspected and contains the Sandbox Watch bundle ID, Sandbox companion bundle ID, `hackersgolfsandbox` URL scheme, `AppIcon-V3-Sandbox`, and `WKSupportsLiveActivityLaunchAttributeTypes` entry.
- The progress regression test compiles in `HackersUnitTests`. Simulator execution is currently blocked during packaging because the iOS Simulator destination attempts to embed a watchOS-device product; the device build path validates successfully.
- The full Sandbox device package builds after adding the in-round activity preference. A later direct unit-target compile was blocked by malformed pre-existing Swift package build paths in DerivedData, not a source compiler failure.

## Open Questions

- Physical paired-device validation remains required before release because Simulator does not validate background `transferUserInfo` behavior.
- Validate tap-to-launch from the Smart Stack and score synchronization on a compatible paired physical Watch after reinstalling the updated Sandbox build.
- Align the iOS Simulator scheme's embedded Watch platform selection if full companion integration tests need to run against paired simulators.
- Validate the deployed Firestore rules against the new iPhone-authoritative Watch score-write path before rollout.
- Remote ActivityKit push updates require a later backend/APNs phase if scores must remain fresh while the iPhone app is suspended.
