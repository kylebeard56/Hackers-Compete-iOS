# TestFlight Build 2026.08.29.2

Date: 08-29-2026

## Scope Boundary

- Changed: App, Watch app, and Live Activity build metadata to `2026.08.29.2`, plus the Production TestFlight archive and upload.
- Not touched: Marketing version, signing identities, bundle identifiers, deployment targets, or existing feature implementation changes.

## Design Decisions

- Use the repository's Production Fastlane deployment workflow and keep its command-line build-number override aligned with the checked-in Xcode build settings.
- Use the existing `Beta Testers` external group and summarize the refined player insights, interactive probability chart, and final counting-status behavior in TestFlight's What to Test notes.

## Deviations

None.

## Tradeoffs

- The upload uses the repository's existing automatic-signing and App Store Connect API-key configuration rather than introducing release-specific signing changes.

## Validation

- The clean Production archive and signed App Store IPA export succeeded with marketing version `1.0.0` and build `2026.08.29.2`.
- App Store Connect accepted and processed the build, applied the What to Test notes, and distributed it to the external `Beta Testers` group.
- The exported IPA and compressed dSYMs are available in the repository's `build` directory.

## Open Questions

None.
