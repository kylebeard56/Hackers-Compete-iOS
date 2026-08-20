# Live Activity Bundle ID Casing

Date: 08-18-2026

## Scope Boundary

- Changed: Normalized the Sandbox and Production Live Activity extension bundle ID suffixes to lowercase.
- Not touched: Target names, product names, source type names, Watch app identifiers, main app identifiers, and Apple Developer portal records.

## Design Decisions

- Kept the existing reverse-DNS structure and changed only `LiveActivity` to `liveactivity` for consistency with the other bundle ID components.

## Deviations

None.

## Tradeoffs

- Existing Apple App IDs may retain their original display casing, but Apple treats bundle IDs as case-insensitive.

## Open Questions

None.
