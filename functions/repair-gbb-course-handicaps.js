#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");

function parseArgs(argv) {
  const parsed = { write: false };
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === "--write") {
      parsed.write = true;
    } else if (value.startsWith("--")) {
      parsed[value.slice(2)] = argv[index + 1];
      index += 1;
    }
  }
  return parsed;
}

function nowTime(date = new Date()) {
  return { iso: date.toISOString(), unix: date.getTime() / 1000 };
}

function revisionUnix(value) {
  if (value == null) return null;
  if (typeof value === "number") return value;
  if (typeof value.unix === "number") return value.unix;
  if (typeof value.toMillis === "function") return value.toMillis() / 1000;
  return null;
}

function assert(condition, message) {
  if (!condition) throw new Error(`Refusing repair: ${message}`);
}

function normalizedShareCode(value) {
  return String(value || "").trim().toUpperCase();
}

function scoreGrossTotals(scoreDocs) {
  const totals = new Map();
  const counts = new Map();
  for (const row of scoreDocs) {
    if (!Number.isInteger(row.hole_number)) continue;
    const ownerID = row.scoring_unit_id;
    if (!ownerID) continue;
    counts.set(ownerID, (counts.get(ownerID) || 0) + 1);
    if (Number.isInteger(row.strokes)) {
      totals.set(ownerID, (totals.get(ownerID) || 0) + row.strokes);
    }
  }
  return { totals, counts };
}

function supportsTotalGrossCorrection(round, segments) {
  const configuration = round.configuration || {};
  const templateID = configuration.format_summary?.template_id
    || configuration.primary_format?.template_id
    || segments[0]?.template_id
    || "";
  const strokeTotalIDs = new Set(["stroke_play", "stroke_play_gross", "stroke_play_net"]);
  const scoreOwnerScope = configuration.score_owner_scope || "individual";
  const matchupResolutionStyle = configuration.matchup_resolution_style || "round_aggregate";
  const matchupScoringStyle = configuration.matchup_scoring_style || "aggregate_round_total";
  const teamScoringScope = configuration.team_scoring?.scope || "per_round";
  const primaryAggregationScope =
    configuration.primary_format?.configuration?.aggregation?.scope || "per_round";
  const scoringUnitsAreIndividual = segments.every((segment) =>
    (segment.scoring_units || []).every((unit) =>
      unit.owner === "participant"
        && Array.isArray(unit.owner_ids)
        && unit.owner_ids.length === 1
    )
  );

  return strokeTotalIDs.has(templateID)
    && scoreOwnerScope === "individual"
    && scoringUnitsAreIndividual
    && matchupResolutionStyle === "round_aggregate"
    && matchupScoringStyle === "aggregate_round_total"
    && teamScoringScope === "per_round"
    && primaryAggregationScope === "per_round";
}

function validateManifest(manifest) {
  assert(manifest.schema === 1, "manifest schema must be 1");
  const target = manifest.target || {};
  assert(target.seriesId, "target.seriesId is required");
  assert(target.seriesRoundId, "target.seriesRoundId is required");
  assert(target.roundId, "target.roundId is required");
  assert(normalizedShareCode(target.shareCode) === "GBB", "target.shareCode must be GBB");
  assert(Array.isArray(manifest.players), "players must be an array");
  assert(manifest.players.length === 33, "the GBB manifest must contain exactly 33 players");
  assert(manifest.expected?.participantCount === 33, "expected.participantCount must be 33");
  assert(manifest.expected?.scoreDocumentCount === 297, "expected.scoreDocumentCount must be 297");
  assert(Number.isFinite(manifest.expected?.roundRevision), "expected.roundRevision is required");
  assert(Number.isFinite(manifest.expected?.seriesRoundRevision), "expected.seriesRoundRevision is required");

  const participantIDs = new Set();
  const memberIDs = new Set();
  for (const player of manifest.players) {
    assert(player.participantId, "every player needs participantId");
    assert(player.memberId, `participant ${player.participantId} needs memberId`);
    assert(player.name, `participant ${player.participantId} needs name`);
    assert(Number.isInteger(player.courseHandicap), `${player.name} needs an integer courseHandicap`);
    assert(Number.isInteger(player.grossTotal), `${player.name} needs an integer grossTotal`);
    assert(Number.isInteger(player.par), `${player.name} needs the authoritative front-nine par`);
    assert(player.teeBoxId, `${player.name} needs teeBoxId`);
    assert(!participantIDs.has(player.participantId), `duplicate participantId ${player.participantId}`);
    assert(!memberIDs.has(player.memberId), `duplicate memberId ${player.memberId}`);
    participantIDs.add(player.participantId);
    memberIDs.add(player.memberId);
  }

  assert(manifest.karis?.participantId, "karis.participantId is required");
  assert(manifest.karis?.teeBoxId === "red_female", "Karis must resolve to red_female");
  assert(participantIDs.has(manifest.karis.participantId), "Karis participant is absent from players");
  assert(manifest.course?.holeSegment === "front9", "GBB repair must target the front9 segment");
  if (manifest.course.completeAuthoritativeTeeMetadata === true) {
    const metadataByID = new Map(
      (manifest.course.tees || []).map((tee) => [tee.teeBoxId, tee])
    );
    for (const teeBoxID of new Set(manifest.players.map((player) => player.teeBoxId))) {
      const tee = metadataByID.get(teeBoxID);
      assert(tee, `official metadata is missing for tee ${teeBoxID}`);
      assert(Number.isFinite(tee.ratingFront), `front-nine rating is missing for tee ${teeBoxID}`);
      assert(Number.isInteger(tee.slopeFront), `front-nine slope is missing for tee ${teeBoxID}`);
    }
  }
}

function teeMapFromRound(round) {
  const map = new Map();
  for (const course of round.configuration?.courses || []) {
    for (const tee of course.course_info?.tees || []) map.set(tee.id, tee);
  }
  return map;
}

function updatedCourses(courses, teeMetadata) {
  const metadataByID = new Map((teeMetadata || []).map((tee) => [tee.teeBoxId, tee]));
  return (courses || []).map((course) => ({
    ...course,
    course_info: {
      ...course.course_info,
      tees: (course.course_info?.tees || []).map((tee) => {
        const official = metadataByID.get(tee.id);
        if (!official) return tee;
        return {
          ...tee,
          name: official.name || tee.name,
          gender: official.gender || tee.gender,
          ratingFront: official.ratingFront,
          slopeFront: official.slopeFront,
        };
      }),
    },
  }));
}

function repairScoringUnits(units, handicapByParticipantID, explicitAllowances = {}) {
  return (units || []).map((unit) => {
    const represented = (unit.owner_ids || []).filter((id) => handicapByParticipantID.has(id));
    if (represented.length === 0) return unit;

    const explicit = explicitAllowances[unit.id];
    if (represented.length > 1 && explicit == null) {
      throw new Error(
        `Refusing repair: scoring unit ${unit.id} represents multiple repaired participants; `
          + "add manifest.scoringUnitAllowances for this unit."
      );
    }

    const memberStrokes = { ...(unit.handicap_allowance?.member_strokes || {}) };
    const adjustments = { ...(unit.handicap_adjustments || {}) };
    for (const participantID of represented) {
      const strokes = handicapByParticipantID.get(participantID);
      memberStrokes[participantID] = strokes;
      adjustments[participantID] = strokes;
    }

    const unitStrokes = explicit ?? (
      represented.length === 1
        ? handicapByParticipantID.get(represented[0])
        : unit.handicap_allowance?.unit_strokes
    );
    assert(Number.isFinite(unitStrokes), `missing allowance for scoring unit ${unit.id}`);
    return {
      ...unit,
      handicap_adjustments: adjustments,
      handicap_allowance: {
        ...(unit.handicap_allowance || {}),
        unit_strokes: unitStrokes,
        member_strokes: memberStrokes,
      },
    };
  });
}

function buildRepairPlan(manifest, data) {
  validateManifest(manifest);
  const { round, seriesRound, participants, scores, segments, processingState, handicapScores } = data;
  const target = manifest.target;
  const expected = manifest.expected;

  assert(normalizedShareCode(round.share_code) === "GBB", "live round share code is not GBB");
  assert(round.status === "complete", `round status is ${round.status}, expected complete`);
  assert(seriesRound.round_id === target.roundId, "series round does not link to the target round");
  assert(seriesRound.status === "complete", `series round status is ${seriesRound.status}, expected complete`);
  assert(participants.length === expected.participantCount, `found ${participants.length} participants`);
  assert(scores.length === expected.scoreDocumentCount, `found ${scores.length} score documents`);
  const selectedCourse = (round.configuration?.courses || []).find(
    (course) => course.course_info?.id === manifest.course.courseId
  );
  assert(selectedCourse, "the authoritative course is not embedded in the round");
  const range = selectedCourse.hole_range || {};
  assert(
    (range.startHole ?? range.start_hole) === 1
      && (range.endHole ?? range.end_hole) === 9,
    "the embedded course segment is not front nine"
  );
  const playersByParticipantID = new Map(manifest.players.map((player) => [player.participantId, player]));
  const participantDataByID = new Map(participants.map((participant) => [participant.id, participant]));
  const teeByID = teeMapFromRound(round);
  const gross = scoreGrossTotals(scores);
  const diffs = [];
  for (const player of manifest.players) {
    const participant = participantDataByID.get(player.participantId);
    assert(participant, `participant document missing for ${player.name}`);
    assert(participant.series_member_id === player.memberId, `member mismatch for ${player.name}`);
    const currentCourseHandicap =
      participant.league_handicap_strokes_at_creation ?? participant.adjusted_handicap;
    if (player.expectedCurrentCourseHandicap != null) {
      assert(
        currentCourseHandicap === player.expectedCurrentCourseHandicap,
        `current course handicap changed for ${player.name}`
      );
    }
    if (player.expectedCurrentTeeBoxId != null) {
      assert(
        participant.tee_box_id === player.expectedCurrentTeeBoxId,
        `current tee changed for ${player.name}`
      );
    }
    assert(
      gross.counts.get(player.participantId) === expected.scoresPerParticipant,
      `${player.name} has ${gross.counts.get(player.participantId) || 0} score documents`
    );
    assert(gross.totals.get(player.participantId) === player.grossTotal, `gross total mismatch for ${player.name}`);
    assert(teeByID.has(player.teeBoxId), `tee ${player.teeBoxId} is not embedded in the round`);
    diffs.push({
      participantId: player.participantId,
      name: player.name,
      oldCourseHandicap: currentCourseHandicap,
      newCourseHandicap: player.courseHandicap,
      oldTeeBoxId: participant.tee_box_id,
      newTeeBoxId: player.participantId === manifest.karis.participantId
        ? manifest.karis.teeBoxId
        : player.teeBoxId,
      grossTotal: player.grossTotal,
    });
  }

  const handicapByParticipantID = new Map(
    manifest.players.map((player) => [player.participantId, player.courseHandicap])
  );
  const segmentUpdates = segments.map((segment) => ({
    id: segment.id,
    scoring_units: repairScoringUnits(
      segment.scoring_units,
      handicapByParticipantID,
      manifest.scoringUnitAllowances || {}
    ),
  }));
  const completeTeeMetadata = manifest.course.completeAuthoritativeTeeMetadata === true;
  const handicapSampleCount = handicapScores.filter(
    (score) => score.source_round_id === target.roundId
  ).length;
  const alreadyApplied = diffs.every(
    (diff) => diff.oldCourseHandicap === diff.newCourseHandicap
      && diff.oldTeeBoxId === diff.newTeeBoxId
  ) && seriesRound.last_score_adjustment_reason === manifest.auditReason;

  if (!alreadyApplied) {
    assert(
      revisionUnix(round.last_updated_at) === expected.roundRevision,
      "round revision differs from the reviewed manifest"
    );
    assert(
      revisionUnix(seriesRound.last_updated_at) === expected.seriesRoundRevision,
      "series round revision differs from the reviewed manifest"
    );
    if (expected.canonicalGenerationId != null) {
      assert(
        processingState?.latest_generation_id === expected.canonicalGenerationId,
        "canonical generation differs from the reviewed manifest"
      );
    }
  }

  return {
    alreadyApplied,
    diffs,
    segmentUpdates,
    completeTeeMetadata,
    handicapSampleCount,
    projectedCanonicalSampleCount: manifest.players.length,
    supportsTotalGrossCorrection: supportsTotalGrossCorrection(round, segments),
    courses: updatedCourses(
      round.configuration?.courses || [],
      manifest.course.tees || []
    ),
    playerByParticipantID: playersByParticipantID,
  };
}

function usage() {
  console.log(
    "Usage: node repair-gbb-course-handicaps.js "
      + "--project <projectId> --manifest <manifest.json> [--write]\n"
      + "Dry-run is the default. --write is refused unless every manifest invariant matches."
  );
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.project || !args.manifest) {
    usage();
    process.exitCode = 1;
    return;
  }

  const manifestPath = path.resolve(args.manifest);
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  const admin = require("firebase-admin");
  if (!admin.apps.length) admin.initializeApp({ projectId: args.project });
  const db = admin.firestore();
  const target = manifest.target || {};
  assert(target.projectId === args.project, "manifest projectId does not match --project");

  const seriesRef = db.collection("series").doc(target.seriesId);
  const seriesRoundRef = seriesRef.collection("rounds").doc(target.seriesRoundId);
  const roundRef = db.collection("rounds").doc(target.roundId);
  const processingRef = seriesRef.collection("round-processing-states").doc(target.seriesRoundId);

  const [
    roundSnapshot,
    seriesRoundSnapshot,
    participantSnapshot,
    scoreSnapshot,
    segmentSnapshot,
    processingSnapshot,
    handicapSnapshot,
    awardSnapshot,
  ] = await Promise.all([
    roundRef.get(),
    seriesRoundRef.get(),
    roundRef.collection("participants").get(),
    roundRef.collection("scores").get(),
    roundRef.collection("segments").get(),
    processingRef.get(),
    seriesRef.collection("handicap-scores").where("source_round_id", "==", target.roundId).get(),
    seriesRef.collection("point-awards").where("series_round_id", "==", target.seriesRoundId).get(),
  ]);

  assert(roundSnapshot.exists, `rounds/${target.roundId} does not exist`);
  assert(seriesRoundSnapshot.exists, `series round ${target.seriesRoundId} does not exist`);
  const data = {
    round: roundSnapshot.data(),
    seriesRound: seriesRoundSnapshot.data(),
    participants: participantSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
    scores: scoreSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
    segments: segmentSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
    processingState: processingSnapshot.exists ? processingSnapshot.data() : null,
    handicapScores: handicapSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
  };
  const plan = buildRepairPlan(manifest, data);

  console.log(`Project: ${args.project}`);
  console.log(`Series / round: ${target.seriesId} / ${target.seriesRoundId}`);
  console.log(`Linked round: ${target.roundId} (GBB)`);
  console.log(`Participants / score docs: ${data.participants.length} / ${data.scores.length}`);
  console.table(plan.diffs);
  console.log(`Karis tee correction: ${manifest.karis.participantId} -> red_female`);
  console.log(`Existing round handicap samples: ${plan.handicapSampleCount}`);
  console.log(`Projected canonical handicap samples: ${plan.projectedCanonicalSampleCount}`);
  console.log(
    `Future handicap eligibility: ${plan.completeTeeMetadata ? "eligible" : "excluded until official tee metadata is complete"}`
  );
  console.log(`Existing point awards to be reconciled: ${awardSnapshot.size}`);
  console.log(
    `Correction input: ${plan.supportsTotalGrossCorrection ? "total gross supported" : "hole-dependent; physical hole scores required"}`
  );
  if (plan.alreadyApplied) {
    console.log("No-op: this manifest repair is already applied.");
    return;
  }

  if (!args.write) {
    console.log("Dry-run complete. No documents were changed. Review this diff before adding --write.");
    return;
  }

  assert(
    manifest.players.every(
      (player) => Number.isInteger(player.expectedCurrentCourseHandicap)
        && typeof player.expectedCurrentTeeBoxId === "string"
    ),
    "write mode requires expectedCurrentCourseHandicap and expectedCurrentTeeBoxId for every player"
  );
  assert(
    plan.supportsTotalGrossCorrection || manifest.holeScoresVerifiedFromPhysicalCards === true,
    "hole-dependent GBB scoring requires holeScoresVerifiedFromPhysicalCards=true"
  );

  const timestamp = nowTime();
  const operationCount = plan.diffs.length
    + plan.segmentUpdates.length
    + handicapSnapshot.size
    + 3;
  assert(operationCount <= 500, `repair requires ${operationCount} Firestore operations`);

  const batch = db.batch();
  for (const diff of plan.diffs) {
    const current = data.participants.find((participant) => participant.id === diff.participantId);
    const player = plan.playerByParticipantID.get(diff.participantId);
    const tee = teeMapFromRound({ configuration: { courses: plan.courses } }).get(diff.newTeeBoxId);
    batch.set(roundRef.collection("participants").doc(diff.participantId), {
      adjusted_handicap: player.courseHandicap,
      league_handicap_strokes_at_creation: player.courseHandicap,
      tee_box_id: diff.newTeeBoxId,
      handicap_snapshot: {
        authoritative_course_handicap: player.courseHandicap,
        handicap_index: current.handicap_index ?? null,
        effective_strokes: player.courseHandicap,
        course_id: manifest.course.courseId,
        course_name: manifest.course.courseName,
        tee_box_id: diff.newTeeBoxId,
        tee_name: tee?.name || player.teeName || "",
        tee_gender: tee?.gender || player.teeGender || "",
        hole_segment: { type: "front9" },
        course_rating: tee?.ratingFront ?? null,
        course_slope: tee?.slopeFront ?? null,
        par: player.par,
        handicap_stroke_basis: manifest.course.handicapStrokeBasis || "nine_hole",
        maximum_handicap: manifest.course.maximumHandicap ?? null,
        entry_format: "course_handicap",
        calculator_fingerprint: `commissioner-repair:${target.seriesRoundId}`,
        selected_handicap_score_ids: player.selectedHandicapScoreIds || [],
        calculated_at: timestamp,
        source: "commissioner_repair",
      },
      last_updated_at: timestamp,
    }, { merge: true });
  }
  for (const update of plan.segmentUpdates) {
    batch.set(roundRef.collection("segments").doc(update.id), {
      scoring_units: update.scoring_units,
      last_updated_at: timestamp,
    }, { merge: true });
  }
  for (const scoreDocument of handicapSnapshot.docs) {
    batch.set(scoreDocument.ref, {
      counts_toward_handicap_index: plan.completeTeeMetadata,
      last_updated_at: timestamp,
    }, { merge: true });
  }

  const roundConfiguration = {
    ...(data.round.configuration || {}),
    courses: plan.courses,
  };
  batch.set(roundRef, {
    configuration: roundConfiguration,
    last_updated_at: timestamp,
  }, { merge: true });

  const roundConfig = {
    ...(data.seriesRound.round_config || {}),
    counts_toward_handicap_pool: plan.completeTeeMetadata,
  };
  batch.set(seriesRoundRef, {
    round_config: roundConfig,
    last_score_adjustment_at: timestamp,
    last_score_adjustment_reason: manifest.auditReason,
    score_adjustment_count: (data.seriesRound.score_adjustment_count || 0) + 1,
    awards_status: "pending",
    awards_finalized_at: admin.firestore.FieldValue.delete(),
    last_updated_at: timestamp,
  }, { merge: true });
  batch.set(processingRef, {
    id: target.seriesRoundId,
    status: "pending",
    source_revision: `commissioner-repair:${timestamp.unix}`,
    source_updated_at: timestamp.unix,
    completed_at: admin.firestore.FieldValue.delete(),
    last_updated_at: timestamp,
    parent_id: target.seriesId,
    schema: 1,
  }, { merge: true });

  await batch.commit();
  console.log(
    "GBB source repair committed. Open the upgraded commissioner app to reconcile "
      + "handicaps, awards, canonical results, and standings."
  );
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = {
  buildRepairPlan,
  parseArgs,
  repairScoringUnits,
  scoreGrossTotals,
  supportsTotalGrossCorrection,
  validateManifest,
};
