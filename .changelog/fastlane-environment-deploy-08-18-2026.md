# Fastlane Environment Deployment

Date: 08-18-2026

## Scope Boundary

- Changed: Added explicit Sandbox/Production selection, build-number overrides, build-only validation, automatic-signing API authentication, environment-specific app lookup, and environment-specific IPA names.
- Not touched: Xcode's automatic-signing setting, manually managed provisioning profiles, tester membership, or App Store Connect metadata.

## Design Decisions

- The wrapper requires an explicit `sandbox` or `production` environment to prevent accidental uploads to the wrong app.
- The existing Team API key is passed to both archive and export so `xcodebuild` can manage signing assets with `-allowProvisioningUpdates`.
- A build-only mode exercises the complete archive/export path without changing TestFlight state.
- Generated build numbers use `YYYY.MM.DD.interval`; `--build-number` pins a specific value when required.

## Deviations

None.

## Tradeoffs

- Manual provisioning-profile overrides were removed from this workflow because all targets use automatic signing and a single profile override was insufficient for the embedded Watch and Live Activity bundles.
- Fastlane 2.230 requires the legacy `app-store` export-method alias, which Xcode 27 still accepts.
- Provisioning authentication is supplied through `xcargs` only because this Fastlane version automatically reuses those arguments during export; also setting `export_xcargs` duplicates them.
- App Store Connect normalizes numeric build-number components for display, so uploaded `2026.08.18.1` appears there as `2026.8.18.1`; the signed app, Watch app, and Live Activity extension retain `2026.08.18.1` in `CFBundleVersion`.

## Open Questions

None. Build-only exports succeeded for both environments, and Production `2026.08.18.1` was uploaded, processed, and distributed to the external `Beta Testers` group with its embedded Watch and Live Activity targets.
