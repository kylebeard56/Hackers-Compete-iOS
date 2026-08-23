# Matchup Scoring & Awards Regression — Research Findings

This document records a **read-only investigation** into why **Week 2** of a series showed “pending” matchups, missing team totals, and broken **Round Awards** player columns, while **Week 1** behaved correctly. No application code was changed during this research.

---

## 1. Symptoms (product)

- **Round Awards** (series tile → “View awards”): Team circles and **Gross/Net** columns showed **“—”**; copy said scores were still waiting, despite a finished round.
- **Round Outcome** / **Live Round → Matchups**: Headline could read **“Matchup pending”** / **“Waiting for both sides to post scores”** while a **player table below** sometimes still showed **per-player gross/net** (different code path).
- **Week 1** on the same series could show **winners, scores, and awards** as expected.

---

## 2. Primary root cause (Firestore + segment configuration)

### 2.1 What went wrong

For **Week 2**, the **round segment** document that drives scoring stored a **hole range that does not match where scores were recorded**.

| Layer | Week 1 (working) | Week 2 (broken) |
|--------|------------------|-----------------|
| **Series round** `course_override` | Preserve at Verdae, **back nine** (`hole_segment.type: back9`) | Same course, **back nine** |
| **`RoundSegment.hole_range`** | **Holes 10 → 18** | **Holes 1 → 9** |
| **`scores` subcollection `hole_number`** | Aligned with **10–18** | Aligned with **10–18** (e.g. 10, 11, 12, 13… sampled) |
| **`scores.segment_id`** | Matches that round’s segment | Matches segment `6hq4…` |

So for Week 2:

- The **scoring engine** iterates **`segment.holeRange.holeNumbers`** → **only holes 1–9**.
- **Actual `ScoreEntry` documents** for that segment use **`hole_number` in 10–18**.
- **No overlap** → effective **zero holes counted** inside the pipeline for those rows → **`holesPlayed`** and team/markup aggregates collapse → UI shows **pending** and **—**.

### 2.2 Verdict

The regression is **not** mysterious business logic across Week 1 vs Week 2 *per se*: it is a **data consistency bug** — **segment `hole_range` (front nine 1–9)** contradicts **stored scoring for the **back nine (10–18)** on the scorecard**, while the league metadata still reflects **back nine**.

A plausible **behavioral trigger** (lobby switched from front to back nine **without** updating **`RoundSegment.hole_range`**) is documented in **§6**.

---

## 3. Investigation context

- **Firebase project**: `hackers-compete`
- **Series ID**: `DO2Rv75wHDUbN65NyHXxbLM71xCV`

### 3.1 Series round documents

| Round | Series round doc ID | Title | Linked `round_id` |
|--------|----------------------|-------|---------------------|
| Week 1 | `0EdeRTXBAop3JcfWyt87c9FRowyo` | Week 1 | `JBfVfXoSidjaTXWIamPCEsKNwNxx` |
| Week 2 | `5BxUSPg21hBS5TNSLeS9HPrbdqjD` | Week 2 | `r0NBGgnA8Scd9WBV4eNwpgqyOaq3` |

Both showed **`status: complete`** and **`awards_status: finalized`** at time of inspection.

### 3.2 Primary round segments

| Round | Segment doc ID | `competitionScope` | `hole_range` (Firestore) |
|--------|----------------|--------------------|--------------------------|
| Week 1 | `lChavacqqycV2afNrlxxNLEX8Lk9` | `matchup` | **startHole 10, endHole 18** |
| Week 2 | `6hq4VhTijVyNCaiwgvZGZJtXf5do` | `matchup` | **startHole 1, endHole 9** |

### 3.3 Scores sampled (Week 2)

Under `rounds/r0NBGgnA8Scd9WBV4eNwpgqyOaq3/scores`:

- `segment_id` on entries **matches** the Week 2 segment id above.
- **`hole_number` values observed** included **10, 11, 12, 13**, etc. — consistent with **back-nine play**, not holes 1–9.

Round **team** documents and **segment `matchups[].team_ids`** were checked for Week 2; **team IDs lined up** with `rounds/.../teams` (e.g. Team 1 vs Team 9 for the first matchup). The blocker was **not** a bad pairing-key join in the sampled data.

---

## 4. Architectural context (why the UI looked “split”)

This section explains why different surfaces could disagree even before discovering the hole-range bug.

### 4.1 “Pending” matchup vs filled player rows

- **Matchup completion** in the app is tied to **`MatchupResultPresentation.hasCompleteSides`** — both sides must have a **non-nil aggregate `total`** from the leaderboard/matchup builder (`LeaderboardBuilder` / `MatchupResultPresentationBuilder`).
- **Some player tables** use **different derivation** than team totals (e.g. **`LiveRoundViewModel`** hole-by-hole methods vs **`SeriesViewModel.matchupOutcomes`** using **`computeStrokePlay`** for table cells).

So **player-facing numbers could appear while team matchup math stayed “incomplete”** whenever aggregates failed — for Week 2, aggregates failed broadly because **the engine never saw strokes inside the iterated hole window**.

### 4.2 Awards sheet vs Live Round

- **Round Awards** loads a cold **`RoundSnapshot`** and uses **`participantScoreLabel` → `ScoringEngine.computeStrokePlay`** over **`segment.holeRange`**.
- If that range excludes all stored **`hole_number`s**, **`holesPlayed`** stays **0** → **“—”** in Gross/Net.

---

## 5. Secondary differences (Week 2 series metadata)

Week 2’s **`SeriesRound.round_config`** included additional fields versus Week 1 samples (for example **`tee_group_mode: pod_aligned`**, **`pod_grouping_strategy: align_by_index`**, **`score_owner_scope: individual`**, **`matchup_scoring_style: aggregate_round_total`**, etc.). These matter for scheduling and parity but **do not contradict** the core finding: **segment hole range vs score hole numbers**.

---

## 6. Hypothesis: lobby switched front ↔ back nine without updating `RoundSegment`

**Observed in play:** In the **game lobby** for the affected round, play was initially set up for **one nine** (e.g. front), then **changed on the fly** to the **other nine** (e.g. back). That sequence is strongly consistent with the Firestore picture: **`Round.configuration`** reflecting **holes 10–18** gameplay while **`RoundSegment.hole_range` stayed `1–9`**.

This is **not** the **`SeriesRound`** document overriding the **`rounds`** document. It is an **intra-round split** between two layers that the app updates on **different code paths**:

| Layer | What drives it in Live Round | Week 2 failure mode |
|--------|------------------------------|---------------------|
| **Hole list / navigation / many per-hole surfaces** | **`RoundSnapshot.holeRange`** from **`round.configuration.courses.first`** — see `RoundSnapshot.holeRange` in `RoundSnapshot.swift`. | After switching to **back nine**, this can show **10–18** and users post **`ScoreEntry.hole_number` in 10–18**. |
| **Matchup tab, `engineResult`, awards-style aggregates** | **`snapshot.roundSegment`** (Firestore **`segments`** subcollection) passed into **`ScoringEngine.computeSnapshotResult`**. The engine iterates **`segment.holeRange.holeNumbers`**. | If the **segment doc** was never updated, it can still say **1–9** while scores exist on **10–18** → **no overlap** for the pipeline. |

### 6.1 `setCourseSegment` (lobby course / nine change)

**`RoundSession.setCourseSegment(to:)`** updates **`snapshot.round.configuration.courses[0]`** and persists with **`snapshot.round.put()`** — it does **not** in that same flow write **`RoundSegment.hole_range`** on the **`segments`** subcollection.

So: **switching course / nine in the lobby updates the round root configuration** but can leave **stale `RoundSegment` bounds** unless another path re-syncs them.

### 6.2 Where `RoundSegment.holeRange` *does* get aligned

**`SeriesRoundSyncPlanning.buildUpdatedSegment`** sets **`segment.holeRange = courseSegment.holeRange`** when building an updated segment from series context — a **different path** than lobby-only **`setCourseSegment`**.

**Implication:** This bug is most likely when **nine or course is changed after the segment was first created**, and **only the round document** was updated — not an “always broken” path for every round.

### 6.3 Is this “isolated”?

**Mostly yes** in the sense that it requires that **desync** (round config vs segment `hole_range`) to occur. Rounds where **segment and configuration stay in lockstep** (or where segment is rebuilt from the same **`courseSegment`**) should not hit this. **Week 1** in the same series did not show the segment/score hole mismatch in Firestore.

---

## 7. Likely remediation direction (not implemented here)

**Data / one-off repair**: For affected rounds, align **`RoundSegment.hole_range`** with actual **`hole_number`** distribution and league intent (e.g. **10–18** for back nine).

**App / product**:

- When **`setCourseSegment`** (or any flow) changes **`CourseSegment.holeSegment` / `holeRange`**, **also update** the primary **`RoundSegment`** in Firestore (or rebuild it from the same source of truth as creation).
- Optional **guards or diagnostics** when **`scores`** exist for **`hole_number`s** outside **`segment.hole_range`** for the same **`segment_id`**.

---

## 8. References in codebase (for tracing)

| Topic | Location |
|--------|----------|
| `RoundSnapshot` / segment helpers | `Hackers/Shared/Models/Round/RoundSnapshot.swift` |
| Lobby course / nine change (round root only, in this extension) | `Hackers/Core/Round/RoundSession+Course.swift` (`setCourseSegment`) |
| Segment hole range when syncing from series | `Hackers/Features/Series/Services/SeriesRoundSyncPlanning.swift` (`buildUpdatedSegment`) |
| Scoring orchestration (`computeSnapshotResult`, `computeStrokePlay`, matchup pipelines) | `Hackers/Core/Scoring/ScoringEngine.swift` |
| Matchup presentation & `hasCompleteSides` | `Hackers/Core/Scoring/LeaderboardBuilder.swift` |
| Outcome matchup status + `engineResult` uses `roundSegment` | `Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift` |
| Awards matchup cards + participant columns | `Hackers/Features/Series/ViewModels/SeriesViewModel.swift` (`matchupOutcomes`), `Hackers/Features/Series/Sheets/SeriesRoundDetailSheets.swift` |
| `HoleSegment` ↔ `HoleRange` (1–9 vs 10–18) | `Hackers/Shared/Models/Hole/HoleSegment.swift` |

---

## 9. Changelog

| Date | Notes |
|------|--------|
| 2026-04-29 | Initial research memo from Firestore inspection + codebase trace. |
| 2026-04-29 | Added lobby front/back hypothesis, `setCourseSegment` vs segment sync, reference table updates. |
