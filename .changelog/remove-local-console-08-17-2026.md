# Remove LocalConsole

Date: 08-17-2026

## Scope Boundary

- Changed: Removed the LocalConsole Swift package, its Xcode project linkage, and its references from the unused legacy V2 app utilities.
- Not touched: Current Hackers, Live Activity, Watch app, and scoring code.

## Design Decisions

- Kept the legacy V2 files in place and removed only their LocalConsole-specific behavior so the cleanup remains reversible.

## Deviations

None.

## Tradeoffs

- The legacy triple-tap console debugging surface is removed because its only implementation came from LocalConsole and the current app does not use it.

## Open Questions

None.
