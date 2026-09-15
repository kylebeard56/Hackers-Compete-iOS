# GolfCourseAPI compatibility

Date: 09-14-2026

## Scope Boundary

- Update course lookup for the provider's opaque string IDs and summary-only search responses; recover cached legacy recents and offer replacement matches for confirmation.
- Preserve existing numeric IDs in stored courses and round snapshots. No bulk database migration or API key rotation.

## Design Decisions

- Live requests confirmed the existing key returns HTTP 200 for search and new detail IDs; legacy numeric detail IDs return HTTP 404.
- Provider documentation explicitly rejects numeric IDs and requires a detail request for tee/scorecard data.
- User approved searching the saved name and confirming a replacement when an old recent course cannot be recovered.
- Keep legacy numeric and new string identities distinct when encoding stored data.

## PR #11 follow-up

- Retained its useful legacy document lookup, provider-identity checks, and stable tee normalization in the current provider-compatible implementation.
- Also normalize legacy UUID records returned by indexed Firebase search before filtering and deduplicating, instead of discarding them.
- Added regression coverage for legacy search/detail tee identity and preservation of all saved ratings, slopes, and hole data, plus rejection of non-provider search records.
- Omitted the proposed scan of 200 arbitrary cache records on a search miss: it adds reads and does not guarantee recovery. Current provider search and explicit replacement confirmation remain the fallback for unindexed legacy courses.
- User will close PR #11; no GitHub mutation performed here.
- Follow-up validation: all 19 repository tests passed in the simulator, including the two additional regression tests; `git diff --check` passed.

## Deviations

- The simulator opens at sign-in. Validate the provider contract and recovery behavior using simulator tests without altering the user's account.

## Tradeoffs

- Fetch scorecards when a search result is selected; do not download every result for ordinary course search.
- PR #11's legacy-cache recovery addresses only part of the failure; it does not support the changed provider contract.
- Older app releases cannot decode newly created rounds containing string provider IDs and need the app update; existing numeric snapshots retain their original encoding.
- The backend history writer already accepts string IDs, so no backend deployment is needed.

## Open Questions

- None for implementation. Account-specific Firebase recovery still needs verification while signed in; this simulator opens at sign-in.

## Validation

- 44 targeted simulator regressions passed, plus 3 scorecard-enrichment tests and 1 opt-in live-provider diagnostic (48 total).
- Live simulator search for `Verdae` returned 2 summaries; detail `xnmmcgzp` loaded 8 filtered tees, including an 18-hole scorecard.
- Original live request to `/v1/courses/24833` returned HTTP 404; `/v1/search?search_query=Verdae` and `/v1/courses/xnmmcgzp` returned HTTP 200 with the existing key.
- Official contract: https://api.golfcourseapi.com/docs/api/ and https://api.golfcourseapi.com/docs/api/openapi.yml.
- Final simulator test build and `git diff --check` passed. Xcode beta required per-command Watch-target exclusion; project settings were not changed.
- Live test is opt-in through `RUN_LIVE_GOLFCOURSE_API_TEST=1` in the test process environment; normal regression runs use deterministic stubs.
- Local changes only; no PR changes, database migration, or deployment performed.
