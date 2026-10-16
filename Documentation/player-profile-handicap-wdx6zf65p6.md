# Player Profile Handicap Management — wdx6zf65p6

Ticket: <https://app.clickup.com/t/wdx6zf65p6> · Existing draft [PR #15](https://github.com/kylebeard56/Hackers-Compete-iOS/pull/15), stacked on [PR #14](https://github.com/kylebeard56/Hackers-Compete-iOS/pull/14) at `864af32c641f154b9be68a8fd100a73e4ce4f4cf`.

## Current result and decisions

The user approved a **WHS-inspired, unofficial Hackers personal calculator**, with **explicit assumed PCC = 0** when official PCC is absent. No paid GHIN integration is being added. Complete individual 18-hole cards now calculate directly from Hackers data; a provider is not required for that path.

Eligible individual nines remain in history and qualifying-hole progress with an actual played-nine differential. Their **18-hole conversion remains pending** because the numeric USGA expected-score model is unavailable. No doubling, invented missing-hole score, or unapproved pairing approximation is implemented. Valid partial cards are retained with the specific limitations below. All labels identify a **Hackers Calculated Index**, never an officially issued GHIN Index.

## Personal calculation and eligibility

- Collect canonical regular and league rounds from both `rounds` and `rounds-v2`. Reuse the existing V2 scoring adapter and migration phase rules: staged copies do not replace V1; active V2 copies replace V1 by stable round ID, including removals/cancellation/archival. Never read a league-computed Index or its custom handicap score pool as a personal result.
- Include individually attributable complete stroke-play, match-play, Stableford and best-ball/four-ball cards. Team membership is not an exclusion. Reject Captain’s Choice/Scramble by stored root/segment IDs, normalized catalog aliases and shared-score structure; reject team-only scores, unknown/shamble formats, practice/unofficial postings, duplicates and insufficient cards. Excluded rounds remain in normal history/statistics, whose code is unchanged.
- For this unofficial app policy, completed individual cards default to inclusion unless marked otherwise. This is **not** certification of USGA season, peer-review, jurisdiction or Rules-of-Golf compliance. Owners and permitted persistent offline-player managers can mark a posting Practice, Unofficial or Needs review from personal history. Those metadata edits never change gross scores or frozen scoring allowances.
- Use the stored first-scored date, or the earliest required/persisted score-entry creation time on older cards, never the correction timestamp. Store that date provenance; these are Hackers recorded scoring dates, not independently certified dates of play.
- Require exact selected-tee rating, slope and par. Reuse PR #14’s provenance-aware metadata resolver; estimated nine-hole metadata cannot qualify. Keep recorded individual gross strokes visible even when missing tee data prevents calculation.
- Preserve manual decimal 18-hole Index, source and update date. Legacy integer allowances are never interpreted as Indexes. Use a frozen personal input where present, otherwise the valid replayed personal history, otherwise a manual Index whose recorded update predates play. Store the provenance used for hole limits. Do not use a league allowance as the personal input.
- Compute adjusted gross only for the personal projection: initial par+5, otherwise net double bogey with unrestricted personal Course Handicap (including plus strokes given back). Nine-hole Course Handicap uses the rounded half Index and actual rated nine. Gross scorecards, scoring caps and participant snapshots are never rewritten.
- Record `pcc.value`, `pcc.verification` (`assumed`/`verified`) and `pcc.source` on each calculated/pending score. Missing official PCC uses `0 / assumed / Hackers assumption: official PCC unavailable`. A valid externally supplied `personal_handicap_pcc` on the canonical round takes precedence. Invalid values/provenance are rejected; a verified zero is distinct from assumed zero. No official PCC is computed from Hackers players’ results.
- Standard 18-hole differential: `113 / slope × (adjusted gross − rating − PCC)`. Apply the published fewer-than-20 table; lowest eight of latest 20; maximum 54.0; published negative tie rounding; exceptional reductions against the unrounded differential; cumulative reductions over the then-latest 20 and dilution; Low Index and soft/hard caps. No league 0.96 factor.
- Enforce 54 actual qualifying holes. Eligible nines count nine actual holes, not 18. Pending eligible conversions remain within the latest-20 candidate window and prevent a new calculated result while relevant; their unknown values are not dropped to manufacture a complete pool. An already established valid Index can remain effective, explicitly dated as the **last valid Index**, while a newer posting is pending. Corrections that remove every valid historical prefix remove that fallback and restore manual/unavailable state.

## Nine-hole and partial-round boundaries

The USGA describes expected score as a standardized population-based value derived from Handicap Index, but the reviewed public pages do not supply the numeric model/data necessary to reproduce it here. Initial nines also need that processing after 54 actual holes. The repository has no provider.

- Complete rated nine: apply published hole limits and half of the explicit PCC; store the **unrounded played-nine differential**. Do not use it as an 18-hole Index input without an authoritative normalized differential.
- Partial 18-hole cards need a user-recorded valid reason (weather preventing continuation, darkness, injury/illness, match finished, or committee closure) and a complete exactly rated nine. Before an established personal Index, only that rated nine contributes to initial progress; other holes are not invented or counted as an 18-hole score.
- With an established personal Index, retain actual qualifying played holes and adjusted gross, but leave the 18-hole differential pending. Do not scale Course Rating, guess expected values or fill unplayed holes. Picked-up holes without a valid individual score remain pending review.
- Never claim that 54 holes alone guarantees a calculated result when required normalization inputs are missing. Six actual nines correctly show 54 holes, pending conversion, no plotted calculated Index, and manual/unavailable effective state.

## Persistence, recalculation and round creation

- Deterministically replay canonical source revisions, with SHA-256 input fingerprints and stable player/round identities. Rebuild on profile load/Refresh and immediately before ordinary-round creation or adding ordinary participants. V1 completion also performs a best-effort refresh for manageable profiles. V2 results/corrections are reflected by the same source refresh before use. There is no new server deployment or background job.
- Persist individual provenance rows under `players/{playerID}/personal-handicap-scores/{roundID}` and actual calculated trend points under `personal-handicap-history/{roundID}`. Remove obsolete derived rows/points after exclusion, correction, deletion or routing changes. Preserve dates of semantically unchanged historical calculations.
- Publish only profile calculation/effective projections; manual input and unrelated player fields are preserved. Every transaction page and final summary checks a refresh-generation token claimed before reading inputs. A newer refresh or concurrent manual edit invalidates older publication. Large histories are paged under Firestore’s write limit; readers always derive from canonical sources rather than trusting a partially published cache.
- Preserve collecting/qualified wire statuses for the earlier Sandbox PR #15 build, with an additive `calculation_pending` flag interpreted by the current client. New fields are optional for legacy player/round/V2 documents.
- Regular creation refreshes the personal result before capturing it and uses PR #14’s Course Handicap/snapshot behavior. A refresh failure is surfaced instead of using a stale calculated cache. Round-only overrides, tee recalculation, historical participant snapshots and independent league calculations remain intact. Read-only registered profiles calculate locally without modifying another owner’s cache; persistent offline identities retain existing management permissions.
- Profile reuses the league card/chart design: effective/manual/calculated (or last valid) values, chronological actual calculated points, qualifying scores/holes, pool/counting totals, and Counts / Pool / Pending / Unofficial rows. Each row exposes PCC provenance, gross/adjusted gross and available differential. No invented nine-hole values appear on the chart.

## Proposed Hackers-specific option — approval required, not implemented

A practical option is **paired-nine estimation**:

1. Pair consecutive eligible complete individual nine-hole cards chronologically, across regular and league play. Sum their unrounded played-nine differentials, then round the combined value once. Never double a single nine.
2. Require 54 actual holes and at least three combined/actual 18-hole differential equivalents. Use the existing published selection table and latest-20-equivalents window; date each pair at the later nine and retain references to both source cards.
3. Label every such result **Hackers paired-nine estimate**, explicitly distinguish it from current WHS expected-score treatment, preserve the manual starting Index, and keep partial-round estimation pending.
4. Continue published caps and exceptional reductions for actual 18-hole cards. Do not invent an exceptional-score comparison Index for a synthetic pair; the proposed first version would not apply an exceptional reduction triggered by a synthetic pair.

This differs from current WHS/GHIN and is **only a proposal**. It is not enabled by the PCC-zero authorization.

## Primary rule references reviewed

- [USGA 2.1a — authorized formats](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/2%201a%20Played%20in%20an%20Authorized%20Format%20of%20Play.htm)
- [USGA 3.1b — net double bogey](https://www.usga.org/handicapping/roh/Content/rules/3%201b%20After%20a%20Handicap%20Index%20Has%20Been%20Established.htm), [6.1b — nine-hole Course Handicap](https://www.usga.org/handicapping/roh/Content/rules/6%201b%209%20holes.htm)
- [3.2a — valid reasons for holes not played](https://www.usga.org/handicapping/roh/Content/rules/3%202a%20Reason%20for%20Not%20Playing%20One%20or%20More%20Holes.htm)
- [Nine-hole expected-score explanation](https://www.usga.org/content/usga/home-page/handicapping/world-handicap-system/world-handicap-system-usga-golf-faqs/faqs---expected-score-explained.html), [initial nines/54 holes](https://www.usga.org/content/usga/home-page/handicapping/world-handicap-system/world-handicap-system-usga-golf-faqs/faqs---new-player-treatment-of-9-hole-scores.html), [initial 10–17 holes](https://www.usga.org/content/usga/home-page/handicapping/world-handicap-system/world-handicap-system-usga-golf-faqs/faqs---10-17-holes-whike-establishing-handicap.html)
- [5.2a — calculation table](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/5%202a%20For%20Fewer%20Than%2020%20Scores.htm), [5.1c — minus rounding](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/5%201c%20Calculation%20of%20a%20Score%20DifferentialRoundingMinus.htm)
- [5.6 — PCC](https://www.usga.org/handicapping/roh/Content/rules/5%206%20Playing%20Conditions%20Calculation.htm), [5.7 — Low Index](https://www.usga.org/handicapping/roh/Content/rules/5%207%20Low%20Handicap%20Index.htm), [5.8 — caps](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/5%208%20Limit%20on%20Upward%20Movement%20of%20a%20Handicap.htm), [5.9 — exceptional scores](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/5%209%20Submission%20of%20an%20Exceptional%20Score.htm)

## Validation

The final regression run passed **377 tests, zero failures/skips** on iPhone 17 Pro / iOS 26.3.1, confirmed with `xcresulttool get test-results summary`. This includes persisted-status compatibility and raw-nine-history safeguards. The preceding broader run passed 375 tests.

The separate **Sandbox simulator build passed**, with signing disabled and `ONLY_ACTIVE_ARCH=YES`. `git diff --check` passed. Validation used `xcodebuild` with project `Hackers.xcodeproj`, scheme/configuration `Sandbox`, the iPhone 17 Pro iOS 26.3.1 destination, and the suites below selected with `-only-testing:HackersUnitTests/<suite>`. The test result bundle is `/private/tmp/HackersPersonalHandicapAssumedPCC-ready.xcresult`; the separate build log is `/private/tmp/HackersPersonalHandicapAssumedPCC-ready-build.log`.

Suites: personal calculation/profile, Course Handicap, scoring engine, series creation/sync, commissioner overrides, league computation/history/accrual, Codable, activation, and V2 routing/model behavior. New tests exercise actual cards without provider fixtures, assumed/verified PCC, gross/adjusted gross and snapshot immutability, nines/partial progress and missing expected inputs, practice/exclusion, V2 individual league nines, corrections, manual transition, last-valid retention and cache projection.

Live authenticated Firebase transactions/save-reload, concurrent multi-device publication, manual UI and physical-device acceptance were not exercised. Firebase admin inspection failed because existing credentials require reauthentication; no login, rules/database changes or deployment was attempted. Existing app-host Firebase permission/keychain and unpaired-watch messages can occur during unit tests. Source uses the existing `(default)` Firestore instance and SDK rather than provisioning or switching databases.
