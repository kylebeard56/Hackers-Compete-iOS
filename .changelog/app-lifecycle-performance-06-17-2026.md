# App Lifecycle Performance

Date: 06-17-2026

## Scope Boundary

- Changed: round listener actor isolation, dashboard loading fan-out, dashboard series status hydration, primary-player caching, skeleton task cancellation, lobby snapshot reaction guards, and reset-time stale data clearing.
- Not touched: Firestore schema, listener query shapes, full dashboard data-store architecture, and Sentry instrumentation.

## Design Decisions

- Kept decoded listener work off the main actor where possible, then applied published `RoundSession` mutations on the main actor through a shared helper.
- Reused the existing series linked-round status resolver for dashboard chips so live series rounds do not visually downgrade to lobby from stale linked round roots.
- Bounded dashboard series-round fetch concurrency instead of making it fully sequential, preserving responsiveness without starting every series subcollection fetch at once.

## Deviations

- Backed out the attempted `LiveRoundViewModel` follow-up-task cancellation because it changed timing relied on by current hole-ordering and outcome behavior.

## Tradeoffs

- This reduces listener/view churn without replacing the broad `RoundSnapshot` publication model; a larger store split would be more invasive and should be trace-guided.
- Live-round follow-up task cancellation remains a candidate, but it needs a design that preserves synchronous visible-group and outcome initialization.

## Open Questions

- Profile on device with Sentry hang reproduction to decide whether `RoundSession.snapshot` should be split into narrower published collections.
