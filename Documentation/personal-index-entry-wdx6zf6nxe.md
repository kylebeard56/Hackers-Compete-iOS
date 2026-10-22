# Single personal Handicap Index entry — wdx6zf6nxe

Target: existing draft PR #16. [ClickUp requirements](https://app.clickup.com/t/wdx6zf6nxe).

## Root cause and correction

The player editor kept a separate mutable `indexBasis`, initialized from shared round configuration or a previous calculation. Legacy round allocation metadata could therefore become the source basis of ordinary personal input. Missing metadata exposed an `Index basis` picker, and the lobby's Hole Basis menu let players select a nine-hole source for their personal Index. The existing conversion formula was correct, but its input context could be wrong or unresolved for a registered or offline player.

- Ordinary registered/offline entry now resolves one personal Index on an eighteen-hole basis. `ManagePlayerView` has no Index-basis picker or editable basis state. `HandicapEntryView` and the lobby/summary use the same entry policy, with the plain label **Handicap Index**. Ordinary Hole Basis controls are hidden.
- Keep the actual entered Index in `RoundParticipant.handicapIndex`. The halved calculation-only value never replaces it. Recompute Course HCP from the actual selected front/back/full tee data. Retain exact/estimated/unavailable status, explicit estimate consent, caps and existing Playing Handicap behavior.
- Personal round configuration separates source basis (always eighteen holes) from allocation basis (the actual played segment). Course/length changes preserve explicit manual Strokes Received and skip recalculating those participants; their strokes are allocated over the current holes rather than silently halved.
- PR #16 retains separate per-player Index/manual-stroke buffers, the visible Done control and edit-driven roster persistence. Profile Indexes are not changed by round-only input. Gross edits may leave a missing Index unresolved, while net activation still requires resolved input.
- Internal league source bases, series generation, commissioner overrides, caps, and frozen snapshots remain independent. League members keep their configured nine-hole Index conversion. Historical editors retain saved source metadata; completed scorecards/allowances are not rewritten.

The shared correction originates on PR #14 and is integrated through PR #15 into the existing PR #16 candidate with history-preserving branch integrations. No GitHub PR is merged. Conflicts retain PR #16's existing keyboard/mode behavior, personal-history implementation, signed scoring, course-provider fixes, Settings, companion gating and invalid-gross-score protections. Shared regressions are adapted to the release candidate's existing timeline API, without replacing that implementation. Firebase persistence, personal calculation engine, ScoringEngine, Settings and companion runtime files match the original `bde218cc` candidate.

## Formula and Paris Mountain verification

[USGA Rule 6.1b](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/6%201b%209%20holes.htm) specifies:

```text
nineCalculationIndex = roundToTenth(personalIndex / 2)
rawCourseHCP = nineCalculationIndex × (selectedNineSlope / 113)
             + selectedNineRating − selectedNinePar
```

Keep existing final rounding and downstream allowances. An internal nine-hole league Index is already on its league's scale and is not halved again.

The supplied GHIN screenshot provides personal Index 17.7, rating 33.7 and slope 128. Independently checked Paris Mountain White hole pars from [Golfify's hole-by-hole card](https://www.golfify.io/courses/paris-mountain-country-club), cross-checked with [18Birdies](https://18birdies.com/golf-courses/club/ae205950-86ac-11e4-8c28-020000005b00/paris-mountain-country-club), are 5,4,5,4,3,4,4,3,4 for the front nine: **par 36**. The calculation-only Index is 8.9, raw Course HCP is approximately 7.7814, and the existing final rounding produces **8**. Tests compute the expectation from the hole pars, rating and slope; they do not feed GHIN's displayed result into the calculator. Published provider yardages/ratings differ from the supplied screenshot, so the fixture documents each input's source rather than asserting all provider data is a current GHIN feed. Production uses the selected tee's actual stored metadata; no course record is edited by this change.

## Changed paths

- `ScoringService+Course.swift`: shared personal entry/context and allocation configuration, preserving internal league conversion and the release candidate's manual-stroke buffers.
- `RoundSnapshot.swift`, `RoundSession+Config.swift`, `RoundSession+Course.swift`: setup basis resolution and source-preserving course/segment recalculation.
- `ManagePlayerView.swift`, `HandicapEntryView.swift`, `GameLobby+Configuration.swift`, `GameLobby.swift`, `NavButton.swift`: remove technical personal-basis affordances and preserve started-round protections.
- `Round+Participant.swift`: one clear personal Index label, existing per-player entry draft, and optional unresolved input.
- Course Handicap, entry, hosted keyboard/navigation, personal-history and scoring regression suites: new coverage and adaptation of upstream tests to existing release APIs.

## Validation and limits

The upstream PR #14 run passed **184 tests, 0 failed/skipped** on iPhone 17 Pro / iOS 26.3.1 using XcodeBuildMCP, Sandbox. Result: `/private/tmp/HackersPersonalIndex14-verified.xcresult`.

New coverage includes registered/offline 18→front nine→back nine→18 changes, tee changes, Codable save/reload, full segment stroke allocation, original Index preservation, manual-stroke preservation, internal league nine-hole conversion, historical metadata, the real Manage Player/Handicap Entry views, and editor→summary→editor navigation. Hosted UI tests exercise real SwiftUI/UIKit editors with in-memory participants, without authentication or Firestore writes. Summary/back navigation uses a test-only NavigationStack harness rendering the production summary formatter; it does not claim a signed-in end-to-end summary flow. Test yardages are synthetic and are not calculation inputs. Existing release regression suites remain enabled.

This is an **unreleased code correction**. The existing October 16 TestFlight build is not updated by branch changes. Updated TestFlight/physical-device acceptance remains required before claiming that build fixed. Signed-in Firebase end-to-end/concurrency is not exercised. No PR merge, upload, deployment or production-data change is authorized or performed here.


Final PR #16 complete unit suite: **1,024 passed, 0 failed, 5 existing opt-in skips**, XcodeBuildMCP, Sandbox / iPhone 17 Pro / iOS 26.3.1. Result bundle: `/private/tmp/HackersPersonalIndex16-full-final.xcresult`. All existing release, course, scoring, keyboard, Settings and companion tests remain enabled. This adds four shared calculation/entry methods and two hosted UI methods, plus retains the upstream audit regressions.

Visually inspected the actual Manage Player screenshots after keyboard dismissal: [registered player](personal-index-entry-wdx6zf6nxe/registered-front-nine.png), [offline player](personal-index-entry-wdx6zf6nxe/offline-front-nine.png). Both show Index 17.7, exact Course HCP 8 and Strokes Received 8, with one editable Index and no basis picker.


Stacked PR #15 validation passed **293 selected tests, 0 failed/skipped**, including personal calculation/profile, Course Handicap, scoring, series creation and commissioner overrides: `/private/tmp/HackersPersonalIndex15-verified.xcresult`. The final ancestry integration into PR #16 was verified to have an identical tree to the tested candidate; it changes no runtime files. PR #14 head: `140f22ce` (core policy `64b2cd90`); PR #15 head: `e9782443`; PR #16 integrated code: `74aeaae6` (primary fix `6ab125ca`). Existing compiler warnings were not suppressed or repaired as unrelated work.


The five unchanged opt-in skips are the live OCR diagnostic's cover/bundled-card cases, course-chat preview rendering, live chat search, and live course search/detail diagnostic. The complete regression run did not enable external-service opt-ins. No new skip was introduced.

Standalone **Sandbox simulator build, install and launch passed** via XcodeBuildMCP on the same iPhone simulator. Build log: `/Users/Kirsten/Library/Developer/XcodeBuildMCP/workspaces/Hackers-Combined-f7828574fa53/logs/build_run_sim_2026-10-18T14-28-38-955Z_pid11554_e349c71f.log`. Runtime UI inspection confirms the app reaches the Apple/Google sign-in screen. No authenticated app session was available, so a signed-in end-to-end lobby/save/reload smoke test was not performed. The actual editors were visually reviewed through the hosted screenshots above; this does not replace TestFlight/device acceptance.

Build/test configuration: project `Hackers.xcodeproj`, scheme/configuration `Sandbox`, simulator `A868F0E8-B3F2-4B0D-9AAC-D3283A1B5806`, derived data `/private/tmp/HackersEntryDerived`, existing source packages `/private/tmp/HackersCombinedDerived/SourcePackages`, automatic package resolution disabled, signing disabled, active architecture only. The complete unit run selects `HackersUnitTests`, disables Address Sanitizer/code coverage as in the existing baseline and uses serial testing. The standalone build omits the test-only coverage flag. `git diff --check` passes. No tests were disabled or newly skipped, and no unrelated compiler-warning cleanup was included.
