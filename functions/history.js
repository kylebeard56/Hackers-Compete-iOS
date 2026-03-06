const admin = require("firebase-admin");
const functions = require("firebase-functions");
const { onDocumentUpdated, onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { onCall } = require("firebase-functions/v2/https");

function db() {
  return admin.firestore();
}
const PLAYERS = "players";
const ROUNDS = "rounds";
const PARTICIPANTS = "participants";
const BATCH_SIZE = 400;

async function getParticipants(roundId) {
  const snap = await db().collection(ROUNDS).doc(roundId).collection(PARTICIPANTS).get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

async function getCourseInfo(roundId) {
  const roundDoc = await db().collection(ROUNDS).doc(roundId).get();
  const config = roundDoc.data()?.configuration;
  const courses = config?.courses;
  if (!courses || courses.length === 0) return null;
  return courses[0].course_info || null;
}

function playedAt(iso) {
  const date = iso ? new Date(iso) : new Date();
  return { iso: date.toISOString(), unix: date.getTime() / 1000 };
}

async function updatePlayerHistoryAndCourseHistory(
  playerId,
  roundId,
  participants,
  courseInfo,
  currentPlayerId
) {
  const playerRef = db().collection(PLAYERS).doc(playerId);
  const playerSnap = await playerRef.get();
  if (!playerSnap.exists) return;

  const player = playerSnap.data();
  const processed = player.processed_round_ids || [];

  if (processed.includes(roundId)) return;

  const roundRef = { round_id: roundId, played_at: playedAt() };
  const playerHistory = { ...(player.player_history || {}) };
  const courseHistory = { ...(player.course_history || {}) };

  for (const p of participants) {
    const pid = p.player_id;
    if (!pid || pid === currentPlayerId) continue;

    const entry = playerHistory[pid] || { player_id: pid, name: p.name || {}, rounds: [] };
    entry.name = p.name || entry.name;
    if (!entry.rounds.some((r) => r.round_id === roundId)) {
      entry.rounds = [...(entry.rounds || []), roundRef];
    }
    playerHistory[pid] = entry;
  }

  if (courseInfo) {
    const courseIdType = courseInfo.golf_course_api_id != null ? "course_api" : "manual";
    const courseId = String(courseInfo.golf_course_api_id ?? courseInfo.id ?? "");
    const key = `${courseIdType}:${courseId}`;
    const entry = courseHistory[key] || {
      course_id: courseId,
      course_id_type: courseIdType,
      name: courseInfo.name || "",
      rounds_played: 0,
      played_at: playedAt(),
    };
    entry.name = courseInfo.name || entry.name;
    entry.rounds_played = (entry.rounds_played || 0) + 1;
    entry.played_at = playedAt();
    courseHistory[key] = entry;
  }

  if (!processed.includes(roundId)) {
    processed.push(roundId);
  }

  await playerRef.update({
    player_history: playerHistory,
    course_history: courseHistory,
    processed_round_ids: processed,
  });
}

async function addPlayersToHistoryForExistingRound(playerId, roundId, participantsToAdd, playedAtVal) {
  const playerRef = db().collection(PLAYERS).doc(playerId);
  const playerSnap = await playerRef.get();
  if (!playerSnap.exists) return;

  const player = playerSnap.data();
  const processed = player.processed_round_ids || [];
  if (!processed.includes(roundId)) return;

  const roundRef = { round_id: roundId, played_at: playedAtVal || playedAt() };
  const playerHistory = { ...(player.player_history || {}) };

  for (const p of participantsToAdd) {
    const pid = p.player_id;
    if (!pid) continue;

    const entry = playerHistory[pid] || { player_id: pid, name: p.name || {}, rounds: [] };
    entry.name = p.name || entry.name;
    if (!entry.rounds.some((r) => r.round_id === roundId)) {
      entry.rounds = [...(entry.rounds || []), roundRef];
    }
    playerHistory[pid] = entry;
  }

  await playerRef.update({ player_history: playerHistory });
}

async function addParticipantsToHistoryForLiveRound(
  roundId,
  addedParticipantIds,
  allParticipants,
  courseInfo
) {
  const playedAtVal = playedAt();

  for (const p of allParticipants) {
    const pid = p.player_id;
    if (!pid) continue;

    if (addedParticipantIds.has(pid)) {
      await updatePlayerHistoryAndCourseHistory(pid, roundId, allParticipants, courseInfo, pid);
    } else {
      const toAdd = allParticipants.filter((x) => addedParticipantIds.has(x.player_id));
      if (toAdd.length > 0) {
        await addPlayersToHistoryForExistingRound(pid, roundId, toAdd, playedAtVal);
      }
    }
  }
}

async function revokeParticipantFromHistory(
  roundId,
  removedPlayerId,
  removedPlayerName,
  remainingParticipants,
  courseInfo
) {
  const remainingIds = new Set(remainingParticipants.map((p) => p.player_id).filter(Boolean));

  const removedRef = db().collection(PLAYERS).doc(removedPlayerId);
  const removedSnap = await removedRef.get();
  if (removedSnap.exists) {
    const data = removedSnap.data();
    const processed = (data.processed_round_ids || []).filter((id) => id !== roundId);
    const playerHistory = { ...(data.player_history || {}) };
    for (const [key, entry] of Object.entries(playerHistory)) {
      if (entry.rounds) {
        const newRounds = entry.rounds.filter((r) => r.round_id !== roundId);
        if (newRounds.length === 0) {
          delete playerHistory[key];
        } else {
          playerHistory[key] = { ...entry, rounds: newRounds };
        }
      }
    }
    const courseHistory = { ...(data.course_history || {}) };
    if (courseInfo) {
      const courseIdType = courseInfo.golf_course_api_id != null ? "course_api" : "manual";
      const courseId = String(courseInfo.golf_course_api_id ?? courseInfo.id ?? "");
      const key = `${courseIdType}:${courseId}`;
      const entry = courseHistory[key];
      if (entry) {
        const newRoundsPlayed = Math.max(0, (entry.rounds_played || 1) - 1);
        if (newRoundsPlayed === 0) {
          delete courseHistory[key];
        } else {
          courseHistory[key] = { ...entry, rounds_played: newRoundsPlayed };
        }
      }
    }
    await removedRef.update({
      processed_round_ids: processed,
      player_history: playerHistory,
      course_history: courseHistory,
    });
  }

  for (const pid of remainingIds) {
    const ref = db().collection(PLAYERS).doc(pid);
    const snap = await ref.get();
    if (!snap.exists) continue;

    const data = snap.data();
    const playerHistory = { ...(data.player_history || {}) };
    const entry = playerHistory[removedPlayerId];
    if (entry && entry.rounds) {
      const newRounds = entry.rounds.filter((r) => r.round_id !== roundId);
      if (newRounds.length === 0) {
        delete playerHistory[removedPlayerId];
      } else {
        playerHistory[removedPlayerId] = { ...entry, rounds: newRounds };
      }
      await ref.update({ player_history: playerHistory });
    }
  }
}

exports.onRoundGoesLive = onDocumentUpdated(`${ROUNDS}/{roundId}`, async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before?.status !== "lobby" || after?.status !== "live") return;

  const roundId = event.params.roundId;
  const participants = await getParticipants(roundId);
  const courseInfo = await getCourseInfo(roundId);

  for (const p of participants) {
    if (p.player_id) {
      await updatePlayerHistoryAndCourseHistory(
        p.player_id,
        roundId,
        participants,
        courseInfo,
        p.player_id
      );
    }
  }
});

exports.onParticipantAddedToLiveRound = onDocumentCreated(
  `${ROUNDS}/{roundId}/${PARTICIPANTS}/{participantId}`,
  async (event) => {
    const roundDoc = await db().collection(ROUNDS).doc(event.params.roundId).get();
    if (roundDoc.data()?.status !== "live") return;

    const newParticipant = event.data.data();
    const allParticipants = await getParticipants(event.params.roundId);
    const courseInfo = await getCourseInfo(event.params.roundId);
    const addedId = newParticipant.player_id;
    if (!addedId) return;

    await addParticipantsToHistoryForLiveRound(
      event.params.roundId,
      new Set([addedId]),
      allParticipants,
      courseInfo
    );
  }
);

exports.onParticipantRemovedFromLiveRound = onDocumentDeleted(
  `${ROUNDS}/{roundId}/${PARTICIPANTS}/{participantId}`,
  async (event) => {
    const roundDoc = await db().collection(ROUNDS).doc(event.params.roundId).get();
    if (roundDoc.data()?.status !== "live") return;

    const deletedData = event.data?.data?.();
    const playerId = deletedData?.player_id;
    if (!playerId) {
      console.warn("onParticipantDeleted: no document data available for participant", event.params.participantId);
      return;
    }

    const remainingParticipants = await getParticipants(event.params.roundId);
    const courseInfo = await getCourseInfo(event.params.roundId);

    await revokeParticipantFromHistory(
      event.params.roundId,
      playerId,
      deletedData.name ?? {},
      remainingParticipants,
      courseInfo
    );
  }
);

exports.clearAllPlayerHistory = onCall(async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }

  const playersSnap = await db().collection(PLAYERS).get();
  let count = 0;
  const docs = playersSnap.docs;

  for (let i = 0; i < docs.length; i += BATCH_SIZE) {
    const batch = db().batch();
    const chunk = docs.slice(i, i + BATCH_SIZE);
    for (const doc of chunk) {
      batch.update(doc.ref, {
        player_history: {},
        course_history: {},
        processed_round_ids: [],
      });
      count++;
    }
    await batch.commit();
  }

  return { ok: true, playersUpdated: count };
});
