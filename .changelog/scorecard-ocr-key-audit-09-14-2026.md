# Scorecard OCR and AI key audit

Date: 09-14-2026

## Scope Boundary

- Test scorecard image extraction and course matching; trace AI credential ownership.
- Cloud Functions migration is a separate client/server change pending the user's scope response.
- Preserve the existing provider-ID and course-chat work.

## Findings

- Both AI providers read literal nonempty keys from the tracked `Hackers/Info.plist`; those entries also exist in the built Sandbox app. Values were not printed.
- OCR, generic AI completions, and course-chat web research send requests directly from iOS to the provider. The Functions entry point has no AI handlers.
- Removing keys before moving requests server-side would break OCR and AI web research. Directory-only course search does not need these AI keys.
- The existing OCR tests use a blank image and mocked JSON: useful for mapping and prompts, but not evidence that image recognition works against a live provider.
- Added an opt-in real-image diagnostic using the bundled scorecard, checking Blue tee hole count, par, yardages, rating, slope, and no invented course name. The image has no course title, so it cannot alone verify a named-course lookup.

## Validation

- Initial regression run: 19 tests passed (OCR prompts/mapping, enrichment, and updated chat copy).
- Real bundled-image requests failed for both Juniper/OpenAI and Magnolia/Anthropic with HTTP 401. Image accuracy cannot be verified until valid credentials are available. No successful live OCR claim is made.
- The official Verdae scorecard is split into a cover with course identity/ratings and a reverse with holes. Added an opt-in cover-to-course diagnostic using the official cover URL; live execution is pending valid credentials.
- Found and fixed fabricated default holes on identity-only OCR results. Empty OCR tees now stay empty; an unambiguous provider match may supply the real scorecard while existing OCR hole data is preserved.
- Provider 401 failures map to a user-facing service-unavailable message, removing instructions for end users to edit API-key configuration.
- Live diagnostics use `RUN_LIVE_SCORECARD_OCR=1`. Log: `/tmp/hackers-ocr-live.log`. Final regression run: 31 tests passed in four suites; `/tmp/hackers-ocr-tests-final-v2.log`.

Official fixture source: [The Preserve at Verdae scorecard](https://www.thepreserveatverdae.com/about-us/scorecard/) (the site publishes the 2022 card images; used as a test fixture, not a claim about current ratings).

## Open Questions

- Whether to prepare an authenticated Cloud Functions migration as part of this task.


## Recommended credential migration

- Add authenticated, operation-specific callable functions for OCR and course-chat research using the existing Firebase region and client conventions.
- Store fresh provider credentials in Secret Manager; keep allowed models, payload limits, and provider requests on the server.
- Verify the server route in Sandbox, then remove the bundled key entries and direct client authentication before release.
- Rotate/revoke the bundled credentials because they are present in tracked source and compiled app resources. HTTP 401 confirms rejection but does not establish when or why the credentials became invalid.
- No Cloud Function deployment, secret rotation, or key removal was performed in this audit.
