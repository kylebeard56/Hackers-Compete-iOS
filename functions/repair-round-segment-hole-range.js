const admin = require("firebase-admin");

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith("--")) continue;
    const key = arg.slice(2);
    if (key === "write") {
      args.write = true;
    } else {
      args[key] = argv[i + 1];
      i += 1;
    }
  }
  return args;
}

function usage() {
  console.log(
    [
      "Usage:",
      "  node repair-round-segment-hole-range.js --project <projectId> --round <roundId> --start <hole> --end <hole> [--segment <segmentId>] [--write]",
      "",
      "Default is dry-run. Add --write to update rounds/{roundId}/segments/{segmentId}.hole_range."
    ].join("\n")
  );
}

function nowTime() {
  const date = new Date();
  return {
    iso: date.toISOString(),
    unix: date.getTime() / 1000
  };
}

function rangeFromData(data) {
  const range = data?.hole_range || {};
  return {
    startHole: range.startHole ?? range.start_hole,
    endHole: range.endHole ?? range.end_hole
  };
}

function rangeLabel(range) {
  return `${range.startHole}-${range.endHole}`;
}

function hasRecordedScore(score) {
  return score.strokes != null
    || score.relative_to_par != null
    || score.points != null
    || score.value != null
    || score.picked_up === true;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const projectId = args.project;
  const roundId = args.round;
  const segmentId = args.segment;
  const startHole = Number(args.start);
  const endHole = Number(args.end);
  const shouldWrite = args.write === true;

  if (!projectId || !roundId || !Number.isInteger(startHole) || !Number.isInteger(endHole) || startHole < 1 || endHole < startHole || endHole > 18) {
    usage();
    process.exitCode = 1;
    return;
  }

  if (!admin.apps.length) {
    admin.initializeApp({ projectId });
  }

  const db = admin.firestore();
  const roundRef = db.collection("rounds").doc(roundId);
  const roundSnap = await roundRef.get();
  if (!roundSnap.exists) {
    throw new Error(`Round not found: rounds/${roundId}`);
  }

  const segmentsRef = roundRef.collection("segments");
  let segmentRef;
  if (segmentId) {
    segmentRef = segmentsRef.doc(segmentId);
  } else {
    const segmentsSnap = await segmentsRef.get();
    if (segmentsSnap.empty) {
      throw new Error(`No segments found for round ${roundId}`);
    }
    if (segmentsSnap.size > 1) {
      throw new Error(`Round ${roundId} has ${segmentsSnap.size} segments. Pass --segment explicitly.`);
    }
    segmentRef = segmentsSnap.docs[0].ref;
  }

  const segmentSnap = await segmentRef.get();
  if (!segmentSnap.exists) {
    throw new Error(`Segment not found: ${segmentRef.path}`);
  }

  const segment = segmentSnap.data();
  const currentRange = rangeFromData(segment);
  const intendedRange = { startHole, endHole };
  const scoresSnap = await roundRef.collection("scores").where("segment_id", "==", segmentRef.id).get();
  const scoredHoles = [...new Set(
    scoresSnap.docs
      .map((doc) => doc.data())
      .filter(hasRecordedScore)
      .map((score) => score.hole_number)
      .filter((hole) => Number.isInteger(hole))
  )].sort((a, b) => a - b);
  const intendedHoleSet = new Set(Array.from({ length: endHole - startHole + 1 }, (_, index) => startHole + index));
  const overlappingScores = scoredHoles.filter((hole) => intendedHoleSet.has(hole));

  console.log(`Project: ${projectId}`);
  console.log(`Round: ${roundId}`);
  console.log(`Segment: ${segmentRef.id}`);
  console.log(`Current segment range: ${rangeLabel(currentRange)}`);
  console.log(`Intended segment range: ${rangeLabel(intendedRange)}`);
  console.log(`Recorded score holes for segment: ${scoredHoles.length ? scoredHoles.join(", ") : "(none)"}`);

  if (currentRange.startHole === startHole && currentRange.endHole === endHole) {
    console.log("No update needed: segment already has the intended range.");
    return;
  }

  if (scoredHoles.length > 0 && overlappingScores.length === 0) {
    throw new Error("Refusing repair: no recorded score holes overlap the intended range.");
  }

  if (!shouldWrite) {
    console.log("Dry-run only. Re-run with --write to apply this repair.");
    return;
  }

  await segmentRef.update({
    hole_range: intendedRange,
    last_updated_at: nowTime()
  });
  console.log("Repair applied.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
