# Ignore IPA Artifacts

Date: 09-04-2026

## Scope Boundary

- Changed: Removed the three generated IPAs in `build/` from Git's index while preserving their local copies.
- Not touched: Other tracked build artifacts, Fastlane configuration, and repository history.

## Design Decisions

- Existing `.gitignore` rules already cover `build/` and `*.ipa`; untracking the previously committed files makes those rules effective without changing them.

## Deviations

None.

## Tradeoffs

- Old IPA versions remain recoverable from Git history; this does not reduce historical repository size.

## Open Questions

None.
