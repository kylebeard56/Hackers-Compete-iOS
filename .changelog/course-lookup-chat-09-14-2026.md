# Course lookup chat

Date: 09-14-2026

## Scope Boundary

- Review and improve Ask AI course lookup speed, location clarification, request lifecycle, and conversation UI.
- Preserve the existing round/tee confirmation flow and the provider-ID compatibility fix already in this working tree.
- Use Box Fox as a read-only reference; retain Hackers branding and existing AI providers rather than importing its workout gateway or storage architecture.

## Design Decisions

- Reuse Box Fox's chat patterns: compact navigation, conversation-first content, keyboard-safe composer, contextual replies, retry without duplicate user messages, and cancellation/stale-response protection.
- Search the course database before expensive web scorecard extraction for a course-name request.
- Use permitted location only to narrow named-course matches; ask for city/state when identity remains ambiguous, and never fabricate course or scorecard data.

## Review Findings

- Every turn currently performs web scorecard extraction before course API enrichment; enrichment may search multiple names and download full scorecards before showing a result.
- Dismissal clears messages but does not cancel an in-flight request; a late response can repopulate the cleared conversation.
- Errors are outside the conversation; there is no inline retry or stop control.
- Existing follow-up text requests several kinds of information at once instead of a targeted location question.
- Current candidate confirmation accepts a web scorecard with any nonempty hole list; review incomplete scorecard handling during implementation.

## Deviations

- Interactive simulator capture is currently blocked by the active CommandLineTools selection; switching to Xcode requires the user's local administrator password. Code review continues while awaiting that setup.

## Tradeoffs

- No new persistent chat storage, shared app framework, model migration, or backend deployment is planned.

## Open Questions

- No open product decisions. See validation for the remaining interactive-device verification limits.

## Implementation

- Direct name search returns directory summaries in one request with no model call; the chosen scorecard loads before round/tee confirmation. Empty scorecards remain an inline error.
- Ambiguous results preserve the original name for a city/state reply, including common postal abbreviations and full US state names. Explicit typed location takes precedence over the device location.
- Location can narrow results by distance or a bounded three-second reverse-geocode lookup when provider summaries lack coordinates. Missing location falls back to a short city/state question.
- Web research remains the fallback for unresolved details or a supplied location/link. Web-only scorecards require review even if the model reports high confidence. Provider requests now have explicit timeouts (course API 15 seconds, AI lookup 25 seconds).
- Adopted Box Fox's single active turn, stale-result protection, Stop, retry using the current location preference without duplicate user messages, Start over, and in-memory conversation retention on sheet dismissal.
- Replaced the carousel and custom header with a native conversation screen, tappable example names, a keyboard-safe composer, truthful location status, inline errors, and dynamic text. Removed the model picker from the user flow; provider configuration is unchanged.

## Validation

- Initial updated lookup/view-model run: 17 tests passed.
- Expanded run found the scorecard-success fixture had no tees. Added a real scorecard fixture and an explicit empty-scorecard rejection regression.
- Expanded regression run: 43 tests passed (course lookup, view model, and repository suites). Final rerun after the current-location retry and dark-button corrections also passed all 43 tests.
- Live simulator chat lookup for “Verdae”: two candidates in 0.574 seconds (final rerun: 0.514 seconds), zero model calls; selected provider detail contained an 18-hole scorecard. This is one observed lookup, not a latency benchmark.
- Opt-in diagnostic run: 12 tests passed, including the live search and five actual SwiftUI view renders. Initial unattached-window captures were blank; attaching the test window to its simulator scene fixed capture.
- Inspected empty, candidate, dark, loading, and accessibility-size error states. Found and corrected candidate-button contrast in dark mode; final captures inspected.
- Web fallback was exercised with structured provider fixtures, not a live AI web-search call. Full signed-in navigation, system keyboard interactions, and location permission dialogs remain unverified because interactive simulator tooling is blocked by the active CommandLineTools selection.


## Flow Review

This is a source review plus isolated simulator view validation, not a complete signed-in product audit. Box Fox's chat model, chat view, and design skill were used as read-only references.

| Step | Current health | Evidence / limitation |
| --- | --- | --- |
| Enter course | Improved | Conversation prompt, tappable course examples, accessible Send label, native toolbar. |
| Find matches | Verified | Live “Verdae” returned two matches in 0.574 seconds with no model call. |
| Clarify location | Verified with fixtures | Original query survives follow-up; typed city/state overrides device location; missing coordinates can use locality lookup. Real permission dialogs not exercised. |
| Select scorecard | Verified | Summary-to-detail handoff, inline failure, empty-card rejection, and existing confirmation flow covered in simulator tests. |
| Recover or pause | Verified with fixtures | Stop/reset reject late responses; retry does not duplicate messages; current location preference is applied on retry. |
| Read and reply | Rendered | Light, dark, loading, and large-text error states captured. Interactive keyboard, VoiceOver traversal, and signed-in navigation remain unverified. |

Simulator capture artifacts: `/tmp/hackers-chat-review/`. Regression output: `/tmp/hackers-chat-tests-final.log`. Live lookup and rendering output: `/tmp/hackers-chat-diagnostics-final.log`.


## Source-label follow-up

- Removed the “Golf Course API” and “Internet” chips from course cards, including the combined-source case.
- Removed provider/source names from assistant result and follow-up copy. Source metadata remains internal for diagnostics and matching.
- Updated the existing copy expectations; the prior screenshots show the earlier source-chip design.
