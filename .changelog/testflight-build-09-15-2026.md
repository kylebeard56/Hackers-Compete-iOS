# TestFlight Build 2026.09.15.1

Date: 09-15-2026

## Scope Boundary

- Changed: Checked-in app, Watch app, and Live Activity build metadata to `2026.09.15.1`, plus the Production TestFlight archive and upload.
- Not touched: Marketing version, signing identities, bundle identifiers, deployment targets, or feature implementation.

## Design Decisions

- Use the repository's existing Production Fastlane deployment workflow and the `Beta Testers` external group.
- Reuse the successfully exported Production IPA for the upload after the initial wrapper invocation correctly stopped for its missing external-distribution changelog.

## Deviations

None.

## Tradeoffs

- Keep the existing automatic-signing and App Store Connect API-key configuration instead of introducing release-specific signing changes.

## Validation

- Clean Production archive and signed App Store IPA export succeeded with marketing version `1.0.0` and build `2026.09.15.1`.
- App Store Connect accepted and processed the build, applied the What to Test note, and distributed it to the external `Beta Testers` group.

## Open Questions

None.
