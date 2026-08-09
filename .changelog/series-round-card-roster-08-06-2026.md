# Series Round Card Roster

Date: 08-06-2026

## Scope Boundary

- Changed: Series round-card status, participant metadata, team player rows, scoring indicators, viewer identification, substitute counts, and focused presentation tests.
- Not touched: Live-round scoring calculations, leaderboard team ranking, attendance mutation, or round roster/substitution workflows.

## Design Decisions

- Live cards reuse the existing motion-safe live indicator and keep provisional scoring context available to accessibility without showing the technical term visually.
- Team rows show every player ordered best-to-worst; a compact dot marks players whose score currently counts without adding a visual legend.
- Player rows use first name plus last initial on screen, preserve the full name for accessibility, and use a smaller inner inset so names and metrics align more naturally with the team card.
- Participant metadata uses an `x of y playing` label and adds a singular/plural substitute label only when at least one active participant is a substitute.
- Viewer identity stays inline as a `YOU` chip, so the separate live/completed participation strip can be removed without losing the viewer's score.

## Deviations

None.

## Tradeoffs

- Upcoming and lobby cards retain the participation chip because it communicates actionable RSVP state; live and result cards rely on the inline viewer row.

## Open Questions

None.

## Verification

- `build-for-testing` succeeded for the app and `HackersUnitTests` bundle, including the new compact player-name formatter coverage.
- The focused 11-test suite was attempted twice, but the only available Simulator rejected the test-runner launch both times with `Launchd job spawn failed`; no tests executed in those attempts.
- Scoped `git diff --check` passed.
