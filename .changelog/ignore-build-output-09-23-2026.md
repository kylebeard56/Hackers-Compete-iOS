# Ignore Build Output

Date: 09-23-2026

## Scope Boundary

- Changed: clarified the build ignore rule and removed previously tracked build output from the Git index and origin/main.
- Not touched: local build files and existing Git history.

## Design Decisions

- Retained the existing `build/` rule, which ignores build directories and all their contents, and removed the redundant `build/Release` rule.
- Used index-only removal so local build output remains available.

## Deviations

None.

## Tradeoffs

- Previously committed files remain in historical commits; this cleanup does not rewrite shared history.

## Open Questions

None.
