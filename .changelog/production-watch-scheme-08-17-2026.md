# Production Watch Scheme

Date: 08-17-2026

## Scope Boundary

- Changed: Added the shared `Watch` Xcode scheme, which builds and runs the Hackers Watch app with the Production configuration.
- Not touched: Watch app functionality, signing identities, bundle identifiers, and the existing Sandbox and Production iPhone schemes.

## Design Decisions

- Mirrored the Sandbox Watch scheme so both environments have the same run, test, profile, and analyze behavior.
- Kept standalone Watch archiving disabled because the Watch app is distributed through the companion iPhone app's Production archive.

## Deviations

None.

## Tradeoffs

- The dedicated scheme is intended for development runs on a Watch; release distribution continues to use the main Production scheme.

## Open Questions

None.
