# Course AI deployment

Both scorecard OCR and course chat's internet fallback now call the authenticated Firebase callable `courseAI` in `us-central1`. Database-first GolfCourseAPI search still runs as before. There is no direct OpenAI or Anthropic client and no provider key in the iOS plist.

The backend owns these choices:

| App selection | Server model | Tasks |
| --- | --- | --- |
| Luna / Juniper scan | `gpt-5.6-luna` | Course web lookup, OCR |
| Sonnet / Magnolia scan | `claude-sonnet-4-6` | Course web lookup, OCR |
| Azalea scan | `gpt-4.1` | Detailed OCR |

The app sends stable selection names, a bounded transcript or JPEG, and notes/location only when provided and permitted. It cannot override the API host, prompt, tools, output token limit, or actual model ID. Firebase attaches the signed-in user's ID token. Anonymous requests are rejected. There is no automatic cross-provider retry.

## Current status

The iOS migration and AI function are implemented locally: 36 iOS tests and 14 backend tests passed. The built simulator app was checked for absent provider key entries. The sandbox AI function is **deployed and active**, but successful authenticated calls to live providers are not yet verified. The old provider tokens were revoked.

Google Cloud authentication now works through `kyle@tigermindlabs.com`, and billing is enabled in both Hackers projects. Both projects now have enabled version 1 for OpenAI and Anthropic, created by the user. The same provider keys across sandbox/production are intentional. The sandbox function references these secrets at runtime. No provider credentials were read or copied from Box Fox.

Live requests without a Firebase token, and requests with an invalid token, both returned HTTP 401 / UNAUTHENTICATED from the deployed sandbox callable. Authenticated AI smoke tests need a normal Firebase session; the admin account lacks test-token signing permission.

The rules protecting `courseAIUsage` passed 30 checks and were deployed to sandbox. Production function deployment remains pending sandbox live verification. Both projects' original Firestore policy allowed public reads/writes to every collection. The narrow new rule excludes only the AI counters; securing existing application data is a separate, important review.

For key entry, use [Hackers Sandbox Secret Manager](https://console.cloud.google.com/security/secret-manager/secrets?project=hackers-compete-sandbox&authuser=1) under `kyle@tigermindlabs.com`. The browser session was verified to show Hackers Compete Sandbox, project number `75387746846`, and both secret containers. `authuser=1` selects that account in the current browser session; if account ordering changes, use Google's account picker explicitly. The personal Gmail account cannot access this project.

## Required server setup

Run these from the repository root in your own interactive terminal. Secret commands prompt for the value; never put a key in a command argument, source file, plist, or chat message. Create fresh Hackers-specific credentials in the provider dashboards first. Do not reuse the revoked credentials.

```sh
gcloud auth login
# Use the account with deployment access to the Hackers project.
gcloud services enable secretmanager.googleapis.com --project hackers-compete-sandbox
./functions/node_modules/.bin/firebase login:add
# Select kyle@tigermindlabs.com in the browser login.
./functions/node_modules/.bin/firebase functions:secrets:set OPENAI_API_KEY --project hackers-compete-sandbox --account kyle@tigermindlabs.com
./functions/node_modules/.bin/firebase functions:secrets:set ANTHROPIC_API_KEY --project hackers-compete-sandbox --account kyle@tigermindlabs.com
```

The checked-in `firestore.rules` was derived from the deployed rules. It excludes `courseAIUsage` from the existing public wildcard, denying all client reads/writes to that collection while retaining existing application behavior. This change is deployed in sandbox. Admin SDK access bypasses rules.

Run `python3 functions/test-course-ai-rules.py` from the repository root with a Google Cloud login authorized for sandbox to repeat the 30 validation cases. They cover authenticated and unauthenticated get/list/create/update/delete on counters and existing course/round paths; they do not mutate application documents. Before production deployment, recheck the deployed rules for intervening changes and apply this narrow exclusion. Never add a deny block beneath an unrestricted wildcard: Firestore allow rules are additive.

Request limits are 8 per user per minute and 100 per UTC day, reserved transactionally before provider access. Failed attempts count. Limits persist across function instances. Request payloads, output sizes, number of model calls, search counts, and provider duration are also bounded. App Check is not yet configured in this app; do not turn on enforcement without shipping a working client attestation setup first.

## Deploy and verify sandbox first

```sh
npm --prefix functions run test:course-ai
./functions/node_modules/.bin/firebase deploy --only functions:courseAI --project hackers-compete-sandbox --account kyle@tigermindlabs.com
```

The organization uses domain-restricted sharing. Firebase CLI's attempt to add an `allUsers` invoker role was rejected even though the function became ACTIVE. Sandbox was configured with Google's supported service-specific alternative:

```sh
gcloud run services update courseai --region us-central1 --project hackers-compete-sandbox --no-invoker-iam-check
```

This permits the iOS HTTPS request to reach the callable. The function itself still verifies the Firebase ID token and rejects unsigned/anonymous callers before accessing secrets or providers. The organization policy and other services are unchanged. Apply the same explicitly reviewed service-specific setting for production when it is deployed. See [Google's public Cloud Run guidance](https://docs.cloud.google.com/run/docs/authenticating/public).

Deploy the function before distributing the updated app. The normal all-functions deploy commands also include it, and will need the secrets configured in that target project. Firebase binds the two secrets to this function; they are not available to the iOS app. Later key rotation needs a new secret version followed by redeployment of `courseAI`.

Use the Sandbox app signed in to a real Firebase test account:

1. Find a known database course: verify its search/selection still works without an AI request.
2. Choose a real course confirmed absent from GolfCourseAPI. Enter its name and city; verify actual web search, official identity, and source-supported tees/holes. Confirm ambiguous names ask for location rather than guessing. Repeat with Luna and Sonnet selected from the chat menu.
3. Scan the bundled multi-tee `MockScorecard` image using Juniper and Magnolia. Confirm all tee rows; the Blue tee fixture has 18 holes, par 72, 6,197 yards, rating 71.1, slope 133. The image has no course identity, which should remain empty.
4. Scan the official Verdae cover fixture used by `LiveScorecardOCRDiagnosticTests`. It contains identity but no hole grid: OCR must return no holes, then the existing enrichment may resolve the real database scorecard.
5. Verify signed-out calls are rejected and excessive calls are rate limited. Provider failures should produce a generic temporary-unavailability message, never a key or provider response body.

`RUN_LIVE_SCORECARD_OCR=1` enables the opt-in simulator OCR diagnostic suite. It now also requires the Sandbox function to be deployed and the test host to have a signed-in Firebase session. Ordinary tests use fixture transports; their passing results do not establish live model access or OCR accuracy.

After sandbox verification, enable Secret Manager and repeat secret setup in production. Deploy the tested rule exclusion with `--only firestore:rules --project hackers-compete` before deploying `--only functions:courseAI --project hackers-compete`, then ship the app. Old installed builds still contain the revoked keys and require an app update. Removing keys from the working tree does not erase Git history; the exposed credentials must remain revoked.

## References

- [Firebase callable authentication](https://firebase.google.com/docs/functions/callable)
- [Firebase Secret Manager parameters](https://firebase.google.com/docs/functions/config-env#secret_parameters)
- [Luna model capabilities](https://developers.openai.com/api/docs/models/gpt-5.6-luna)
- [Anthropic server-tool continuation](https://platform.claude.com/docs/en/agents-and-tools/tool-use/server-tools)
