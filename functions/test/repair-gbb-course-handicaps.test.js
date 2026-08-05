"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  buildRepairPlan,
  repairScoringUnits,
  scoreGrossTotals,
  supportsTotalGrossCorrection,
  validateManifest,
} = require("../repair-gbb-course-handicaps");

function validManifest() {
  const players = Array.from({ length: 33 }, (_, index) => ({
    participantId: `p${index}`,
    memberId: `m${index}`,
    name: `Player ${index}`,
    courseHandicap: index,
    grossTotal: 36 + index,
    teeBoxId: index === 0 ? "red_female" : "white_male",
    par: 36,
  }));
  return {
    schema: 1,
    target: {
      seriesId: "series",
      seriesRoundId: "week11",
      roundId: "round",
      shareCode: "GBB",
    },
    expected: {
      participantCount: 33,
      scoreDocumentCount: 297,
      scoresPerParticipant: 9,
      roundRevision: 1,
      seriesRoundRevision: 1,
    },
    course: {
      courseId: "course",
      courseName: "Course",
      holeSegment: "front9",
      completeAuthoritativeTeeMetadata: false,
      tees: [],
    },
    karis: { participantId: "p0", teeBoxId: "red_female" },
    players,
  };
}

test("manifest refuses any target other than exactly GBB", () => {
  const manifest = validManifest();
  manifest.target.shareCode = "ABC";
  assert.throws(() => validateManifest(manifest), /shareCode must be GBB/);
});

test("manifest requires all 33 authoritative player rows", () => {
  const manifest = validManifest();
  manifest.players.pop();
  assert.throws(() => validateManifest(manifest), /exactly 33 players/);
});

test("score totals retain deterministic document counts and gross", () => {
  const rows = Array.from({ length: 9 }, (_, index) => ({
    scoring_unit_id: "p0",
    hole_number: index + 1,
    strokes: 4,
  }));
  const result = scoreGrossTotals(rows);
  assert.equal(result.counts.get("p0"), 9);
  assert.equal(result.totals.get("p0"), 36);
});

test("individual scoring-unit allowance is replaced consistently", () => {
  const units = [{
    id: "p0",
    owner_ids: ["p0"],
    handicap_adjustments: { p0: 8 },
    handicap_allowance: {
      unit_strokes: 8,
      member_strokes: { p0: 8 },
      source_config: {},
    },
  }];
  const updated = repairScoringUnits(units, new Map([["p0", 9]]));
  assert.equal(updated[0].handicap_adjustments.p0, 9);
  assert.equal(updated[0].handicap_allowance.unit_strokes, 9);
  assert.equal(updated[0].handicap_allowance.member_strokes.p0, 9);
});

test("multi-player scoring units require an explicit authoritative allowance", () => {
  const units = [{
    id: "team",
    owner_ids: ["p0", "p1"],
    handicap_allowance: { unit_strokes: 10, member_strokes: {} },
  }];
  assert.throws(
    () => repairScoringUnits(units, new Map([["p0", 9], ["p1", 11]])),
    /add manifest.scoringUnitAllowances/
  );
});

test("aggregate participant stroke totals support total-gross correction", () => {
  assert.equal(
    supportsTotalGrossCorrection(
      {
        configuration: {
          format_summary: { template_id: "stroke_play" },
          score_owner_scope: "individual",
          matchup_resolution_style: "round_aggregate",
          matchup_scoring_style: "aggregate_round_total",
          team_scoring: { scope: "per_round" },
        },
      },
      [{ scoring_units: [{ owner: "participant", owner_ids: ["p1"] }] }]
    ),
    true
  );
  assert.equal(
    supportsTotalGrossCorrection(
      {
        configuration: {
          format_summary: { template_id: "stroke_play" },
          competition_scope: "matchup",
          score_owner_scope: "individual",
          matchup_resolution_style: "round_aggregate",
          matchup_scoring_style: "aggregate_round_total",
          team_scoring: { scope: "per_round" },
        },
      },
      [{ scoring_units: [{ owner: "participant", owner_ids: ["p1"] }] }]
    ),
    true
  );
  assert.equal(
    supportsTotalGrossCorrection(
      {
        configuration: {
          format_summary: { template_id: "best_ball" },
          score_owner_scope: "individual",
          matchup_resolution_style: "round_aggregate",
          matchup_scoring_style: "aggregate_round_total",
          team_scoring: { scope: "per_round" },
        },
      },
      [{ scoring_units: [{ owner: "participant", owner_ids: ["p1"] }] }]
    ),
    false
  );
  assert.equal(
    supportsTotalGrossCorrection(
      {
        configuration: {
          format_summary: { template_id: "stroke_play" },
          score_owner_scope: "individual",
          matchup_resolution_style: "hole_by_hole",
          matchup_scoring_style: "aggregate_round_total",
          team_scoring: { scope: "per_round" },
        },
      },
      [{ scoring_units: [{ owner: "participant", owner_ids: ["p1"] }] }]
    ),
    false
  );
});

test("a repeated already-applied repair is an idempotent no-op despite new revisions", () => {
  const manifest = validManifest();
  manifest.auditReason = "GBB authoritative repair";
  const tees = [
    { id: "red_female", name: "Red", gender: "female", ratingFront: null, slopeFront: null },
    { id: "white_male", name: "White", gender: "male", ratingFront: null, slopeFront: null },
  ];
  const participants = manifest.players.map((player) => ({
    id: player.participantId,
    series_member_id: player.memberId,
    adjusted_handicap: player.courseHandicap,
    league_handicap_strokes_at_creation: player.courseHandicap,
    tee_box_id: player.teeBoxId,
  }));
  const scores = manifest.players.flatMap((player) => (
    Array.from({ length: 9 }, (_, index) => ({
      scoring_unit_id: player.participantId,
      hole_number: index + 1,
      strokes: index < 8 ? 4 : player.grossTotal - 32,
    }))
  ));
  const scoringUnits = manifest.players.map((player) => ({
    id: player.participantId,
    owner_ids: [player.participantId],
    handicap_adjustments: { [player.participantId]: player.courseHandicap },
    handicap_allowance: {
      unit_strokes: player.courseHandicap,
      member_strokes: { [player.participantId]: player.courseHandicap },
      source_config: {},
    },
  }));
  const plan = buildRepairPlan(manifest, {
    round: {
      share_code: "GBB",
      status: "complete",
      last_updated_at: { unix: 2 },
      configuration: {
        format_summary: { template_id: "best_ball" },
        courses: [{
          course_info: { id: "course", tees },
          hole_range: { startHole: 1, endHole: 9 },
        }],
      },
    },
    seriesRound: {
      round_id: "round",
      status: "complete",
      last_updated_at: { unix: 2 },
      last_score_adjustment_reason: manifest.auditReason,
    },
    participants,
    scores,
    segments: [{ id: "segment", scoring_units: scoringUnits }],
    processingState: { latest_generation_id: "new-generation" },
    handicapScores: [],
  });

  assert.equal(plan.alreadyApplied, true);
  assert.equal(plan.projectedCanonicalSampleCount, 33);
});
