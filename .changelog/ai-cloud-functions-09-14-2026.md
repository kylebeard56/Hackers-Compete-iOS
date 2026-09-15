# AI Cloud Functions

Date: 09-14-2026

## Scope Boundary
- Move course web lookup and scorecard OCR behind the existing Firebase callable architecture; remove bundled OpenAI/Anthropic credentials and direct provider networking.
- Preserve database-first search, course confirmation, existing enrichment, and unrelated working changes. GolfCourseAPI is separate.
- Add a narrow Firestore rule exclusion for the new AI counters. Both original deployed rules allowed public reads/writes; broader application authorization is explicitly deferred for separate review.

## Design Decisions
- Server owns prompts, schemas, tools, output limits, and allowed models. Luna follows Box Fox's `gpt-5.6-luna`; Sonnet remains available. Existing detailed OCR tier remains GPT-4.1.
- Require signed-in non-anonymous Firebase users. Bound payloads and provider duration. Reserve an atomic per-user limit of 8 requests/minute and 100/day, including failed attempts.
- Keep raw provider errors, prompts, images, and secrets out of logs and client responses.

## Deviations
- None.

## Tradeoffs
- Firebase callables match the app's existing transport. UI cancellation discards late results; an already dispatched server request may finish and count toward the request limit.
- App Check is not enabled in this app; the new function does not suddenly require it. Authentication and quotas are the initial controls.

## Open Questions
- Owner account `kyle@tigermindlabs.com` is authenticated. Both projects have enabled version 1 for both provider secrets, configured by the user. Shared provider keys across environments are intentional.
- Sandbox `courseAI` is deployed and active with both secret bindings. Domain-restricted sharing blocked the default public invoker IAM binding; the approved service-specific Cloud Run `--no-invoker-iam-check` setting permits HTTP access while the callable requires Firebase sign-in. Organization-wide policy is unchanged.
- Production function deployment remains pending sandbox live verification.
- Sandbox counter rules are deployed after 30 successful Google rules checks. Existing application collections retain their original public policy; this needs a separate security review.
- Live OCR and internet-only lookup remain unverified: admin test-token signing was denied (`iam.serviceAccounts.signBlob`). The temporary Auth user was deleted before any AI call; no quota record was created. A normal user session or explicitly approved temporary signing permission is needed.
- Simulator app launches on iPhone 17 Pro but is signed out; the browser mirror currently reports no simulators. No provider-key issue has been established for the new secrets.

## Validation
- 36 iOS tests in 5 suites passed, including gateway payload/decoding, consented location, model migration, and bundled-key absence.
- 14 backend tests passed: authenticated-only requests, quota windows, input limits, both providers, real-search requirement, bounded continuations, OCR tee preservation, and sanitized failures. Provider responses are fixtures.
- Xcode simulator build succeeded; no direct AI provider URLs or private key entries remain in iOS source/configuration.
- Setup and rollout instructions: `Documentation/AI/Cloud-Functions.md`. Live provider access is waiting on fresh secret versions, then function deployment and authenticated smoke tests.
- Verified the browser Secret Manager page targets Hackers Compete Sandbox (75387746846) with the owner account. The personal Gmail account could not access it; account-switch links can drop the selected project.
- Live sandbox endpoint rejects both signed-out requests and invalid Firebase tokens with HTTP 401 / UNAUTHENTICATED, before quota/provider access.
- Broomsedge, Old Barnwell, and The Tree Farm returned zero GolfCourseAPI results. Broomsedge in Rembert, SC is the planned real web-fallback fixture.
