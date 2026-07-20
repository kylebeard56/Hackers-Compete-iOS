"use strict";

const crypto = require("node:crypto");
const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");

const db = admin.firestore();
const COLLECTIONS = Object.freeze({
  series: "series-v2",
  rounds: "rounds-v2",
  memberships: "series-memberships-v2",
  joinCodes: "join-codes-v2",
  commands: "commands-v2",
  routing: "series-routing-v2",
});
const EMPTY_NAME = Object.freeze({
  given_name: "",
  family_name: "",
  search_key: "",
  search_key_reverse: "",
});

function timeValue(date = new Date()) {
  return { iso: date.toISOString(), unix: date.getTime() / 1000 };
}

function requireString(value, field, minimum = 1) {
  if (typeof value !== "string" || value.trim().length < minimum) {
    throw new HttpsError("invalid-argument", `Expected a valid ${field}.`);
  }
  return value.trim();
}

function commandID(value) {
  const result = requireString(value, "command_id", 8);
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(result)) {
    throw new HttpsError("invalid-argument", "command_id contains unsupported characters.");
  }
  return result;
}

function receiptID(uid, operation, id) {
  return `${uid}_${operation}_${id}`;
}

function makeShareCode(seed, attempt = 0) {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.createHash("sha256").update(`${seed}:${attempt}`).digest();
  return Array.from(bytes.subarray(0, 6), (byte) => alphabet[byte % alphabet.length]).join("");
}

function participationStatus(attendanceDefault) {
  if (attendanceDefault === "accepted") return "confirmed";
  if (attendanceDefault === "no") return "declined";
  return "pending";
}

function canTransition(from, to) {
  return (from === "lobby" && to === "live") ||
    (from === "live" && to === "completed") ||
    (from === "completed" && to === "archived");
}

function canTransitionMigration(from, to) {
  return (from === "ready" && to === "active") ||
    (from === "active" && to === "rolled_back") ||
    (from === "rolled_back" && to === "active");
}

function assertAuthenticated(auth) {
  if (!auth) throw new HttpsError("unauthenticated", "You must be signed in.");
}

function isCommissioner(series, members, uid) {
  return series.commissioner_user_id === uid || members.some((member) => {
    const value = member.data();
    return value.user_id === uid && value.role === "commissioner" && value.is_active !== false;
  });
}

async function loadSeriesAuthority(seriesID, uid) {
  const seriesRef = db.collection(COLLECTIONS.series).doc(seriesID);
  const [seriesSnapshot, memberSnapshots] = await Promise.all([
    seriesRef.get(),
    seriesRef.collection("members").get(),
  ]);
  if (!seriesSnapshot.exists) throw new HttpsError("not-found", "Series V2 was not found.");
  if (!isCommissioner(seriesSnapshot.data(), memberSnapshots.docs, uid)) {
    throw new HttpsError("permission-denied", "Only a Series commissioner can change round structure.");
  }
  return { seriesRef, series: seriesSnapshot.data(), members: memberSnapshots.docs };
}

async function writeProvisionedRound(roundID, series, memberDocs, teamDocs, now) {
  const roundRef = db.collection(COLLECTIONS.rounds).doc(roundID);
  const activeMembers = memberDocs
    .map((snapshot) => ({ id: snapshot.id, ...snapshot.data() }))
    .filter((member) => member.is_active !== false);
  const teams = teamDocs.map((snapshot) => ({ id: snapshot.id, ...snapshot.data() }));
  const rules = series.settings?.round_defaults?.rules || {};
  const status = participationStatus(rules.attendance_default);
  const eligible = activeMembers.filter(() => status !== "declined");
  const groupByMember = new Map();
  const teeGroups = [];

  const writer = db.bulkWriter();
  for (let offset = 0; offset < eligible.length; offset += 4) {
    const group = eligible.slice(offset, offset + 4);
    const groupID = `tee-${String(offset / 4 + 1).padStart(3, "0")}`;
    writer.set(roundRef.collection("tee-groups").doc(groupID), {
      id: groupID,
      source_plan_id: null,
      index: offset / 4,
      tee_time: null,
      starting_hole: 1,
      created_at: now,
      last_updated_at: now,
      parent_id: roundID,
      schema: 2,
    });
    const participantIDs = group.map((member) => member.player_id || member.id);
    teeGroups.push({ id: groupID, participantIDs });
    writer.set(roundRef.collection("scoring-groups").doc(groupID), {
      id: groupID,
      source_series_pod_id: null,
      source_partnership_plan_id: null,
      team_id: null,
      tee_group_id: groupID,
      kind: "tee_group",
      participant_ids: participantIDs,
      label: `Group ${offset / 4 + 1}`,
      created_at: now,
      last_updated_at: now,
      parent_id: roundID,
      schema: 2,
    });
    group.forEach((member, index) => groupByMember.set(member.id, { id: groupID, order: index }));
  }

  for (const member of activeMembers) {
    const id = member.player_id || member.id;
    const group = groupByMember.get(member.id);
    writer.set(roundRef.collection("participants").doc(id), {
      id,
      user_id: member.user_id || null,
      player_id: member.player_id || null,
      series_member_id: member.id,
      name: member.name || EMPTY_NAME,
      participation_status: status,
      tee_box_id: member.default_tee_box_id || "",
      original_handicap: 0,
      adjusted_handicap: 0,
      handicap_index: null,
      team_id: member.team_id || null,
      tee_group_id: group?.id || null,
      tee_order: group?.order ?? null,
      is_host: member.user_id === series.commissioner_user_id,
      is_substitute: false,
      created_at: now,
      last_updated_at: now,
      parent_id: roundID,
      schema: 2,
    });
  }

  for (const team of teams) {
    writer.set(roundRef.collection("teams").doc(team.id), {
      id: team.id,
      series_team_id: team.id,
      name: team.name || "",
      color: team.custom_color_hex || team.color || "",
      index: team.index || 0,
      created_at: now,
      last_updated_at: now,
      parent_id: roundID,
      schema: 2,
    });
  }

  const config = series.settings?.round_defaults?.configuration || {};
  let scoringUnits;
  if (config.score_owner_scope === "tee_group") {
    scoringUnits = teeGroups.map((group) => ({
      id: group.id, owner: "score_owner", owner_ids: group.participantIDs, scoring_method: "aggregate",
    }));
  } else if (config.score_owner_scope === "partnership") {
    scoringUnits = [];
    for (let offset = 0; offset < eligible.length; offset += 2) {
      const pair = eligible.slice(offset, offset + 2);
      const pairID = `pair-${String(offset / 2 + 1).padStart(3, "0")}`;
      const ids = pair.map((member) => member.player_id || member.id);
      writer.set(roundRef.collection("scoring-groups").doc(pairID), {
        id: pairID, source_series_pod_id: null, source_partnership_plan_id: null,
        team_id: pair[0]?.team_id || null, tee_group_id: groupByMember.get(pair[0]?.id)?.id || null,
        kind: "partnership", participant_ids: ids, label: `Pair ${offset / 2 + 1}`,
        created_at: now, last_updated_at: now, parent_id: roundID, schema: 2,
      });
      scoringUnits.push({ id: pairID, owner: "score_owner", owner_ids: ids, scoring_method: "aggregate" });
    }
  } else if (config.selection_domain === "team" && teams.length > 0) {
    scoringUnits = teams.map((team) => ({ id: team.id, owner: "team", owner_ids: [team.id], scoring_method: "aggregate" }));
  } else {
    scoringUnits = eligible.map((member) => {
      const id = member.player_id || member.id;
      return { id, owner: "participant", owner_ids: [id], scoring_method: "individual" };
    });
  }
  writer.set(roundRef.collection("segments").doc("segment-1"), {
    id: "segment-1",
    hole_range: config.courses?.[0]?.hole_range || { startHole: 1, endHole: 18 },
    template_id: config.template_id || "stroke-play",
    scoring_units: scoringUnits,
    matchups: [],
    competition_scope: config.competition_scope || "field",
    created_at: now,
    last_updated_at: now,
    parent_id: roundID,
    schema: 2,
  });
  await writer.close();
}

const createSeriesV2 = onCall(async ({ auth, data }) => {
  assertAuthenticated(auth);
  const id = commandID(data?.command_id);
  const name = requireString(data?.name, "name");
  const seriesRef = db.collection(COLLECTIONS.series).doc(id);
  const receiptRef = db.collection(COLLECTIONS.commands).doc(receiptID(auth.uid, "create-series", id));
  const codeRefs = Array.from({ length: 12 }, (_, index) =>
    db.collection(COLLECTIONS.joinCodes).doc(makeShareCode(id, index))
  );
  const now = timeValue();

  return db.runTransaction(async (transaction) => {
    const receipt = await transaction.get(receiptRef);
    if (receipt.exists) return { ...receipt.data(), replayed: true };
    const existing = await transaction.get(seriesRef);
    if (existing.exists) throw new HttpsError("already-exists", "Series V2 already exists for this command.");
    const codeSnapshots = [];
    for (const ref of codeRefs) codeSnapshots.push(await transaction.get(ref));
    const codeIndex = codeSnapshots.findIndex((snapshot) => !snapshot.exists);
    if (codeIndex < 0) throw new HttpsError("resource-exhausted", "Could not reserve a unique Series code.");
    const shareCode = codeRefs[codeIndex].id;
    const playerID = typeof data.commissioner_player_id === "string" ? data.commissioner_player_id : null;
    const memberID = playerID || `user-${auth.uid}`;
    const response = { ok: true, command_id: id, entity_id: id, revision: 1, replayed: false };
    transaction.create(seriesRef, {
      id,
      name,
      description: data.description || null,
      share_code: shareCode,
      commissioner_user_id: auth.uid,
      commissioner_player_id: playerID,
      status: "draft",
      visibility: data.visibility || "private",
      settings: data.settings || {},
      round_count: 0,
      completed_round_count: 0,
      active_announcement_count: 0,
      minimum_client_version: data.minimum_client_version || null,
      migration: null,
      created_at: now,
      last_updated_at: now,
      starts_at: null,
      ends_at: null,
      schema: 2,
    });
    transaction.create(seriesRef.collection("members").doc(memberID), {
      id: memberID,
      user_id: auth.uid,
      player_id: playerID,
      name: data.commissioner_name || EMPTY_NAME,
      role: "commissioner",
      team_id: null,
      default_tee_box_id: null,
      is_active: true,
      joined_at: now,
      left_at: null,
      legacy_member_id: null,
      created_at: now,
      last_updated_at: now,
      parent_id: id,
      schema: 2,
    });
    if (playerID) {
      const membershipID = `${id}_${playerID}`;
      transaction.create(db.collection(COLLECTIONS.memberships).doc(membershipID), {
        id: membershipID,
        series_id: id,
        member_id: memberID,
        player_id: playerID,
        user_id: auth.uid,
        role: "commissioner",
        is_active: true,
        created_at: now,
        last_updated_at: now,
        schema: 2,
      });
    }
    transaction.create(codeRefs[codeIndex], {
      id: shareCode,
      target_type: "series",
      target_id: id,
      model_version: 2,
      created_at: now,
      last_updated_at: now,
      schema: 2,
    });
    transaction.create(receiptRef, response);
    return response;
  });
});

const createSeriesRoundV2 = onCall(async ({ auth, data }) => {
  assertAuthenticated(auth);
  const id = commandID(data?.command_id);
  const seriesID = requireString(data?.series_id, "series_id");
  const title = requireString(data?.title, "title");
  const authority = await loadSeriesAuthority(seriesID, auth.uid);
  const teamSnapshot = await authority.seriesRef.collection("teams").get();
  const roundRef = db.collection(COLLECTIONS.rounds).doc(id);
  const receiptRef = db.collection(COLLECTIONS.commands).doc(receiptID(auth.uid, "create-round", id));
  const codeRefs = Array.from({ length: 12 }, (_, index) =>
    db.collection(COLLECTIONS.joinCodes).doc(makeShareCode(id, index))
  );
  const now = timeValue();

  const reservation = await db.runTransaction(async (transaction) => {
    const receipt = await transaction.get(receiptRef);
    if (receipt.exists) return { replayed: true, ...receipt.data() };
    const seriesSnapshot = await transaction.get(authority.seriesRef);
    const existingRound = await transaction.get(roundRef);
    const codeSnapshots = [];
    for (const ref of codeRefs) codeSnapshots.push(await transaction.get(ref));
    const series = seriesSnapshot.data();
    const codeIndex = codeSnapshots.findIndex((snapshot) => !snapshot.exists || snapshot.data()?.target_id === id);
    if (codeIndex < 0) throw new HttpsError("resource-exhausted", "Could not reserve a unique round code.");
    const shareCode = codeRefs[codeIndex].id;

    if (!existingRound.exists) {
      const defaults = series.settings?.round_defaults || {};
      const playerIDs = authority.members.map((member) => member.data().player_id).filter(Boolean);
      transaction.create(roundRef, {
        id,
        name: title,
        share_code: shareCode,
        created_by_user_id: auth.uid,
        status: "lobby",
        schedule: data?.scheduled_at ? {
          scheduled_at: data.scheduled_at,
          time_zone_identifier: data.time_zone_identifier || "UTC",
        } : null,
        configuration: defaults.configuration || {},
        series_context: {
          series_id: seriesID,
          round_index: series.round_count || 0,
          applied_defaults_revision: series.settings?.round_defaults_revision || 1,
          lobby_activated_at: null,
          standings_policy_binding: null,
          team_scoring_profile_binding: null,
          individual_scoring_profile_binding: null,
          rules: defaults.rules || {},
          legacy_series_round_id: null,
          migrated_from_v1: false,
        },
        participant_player_ids: [...new Set(playerIDs)].sort(),
        provisioning: { phase: "provisioning", command_id: id, last_completed_stage: "root", failure_code: null, retry_count: 0 },
        revision: 0,
        scoring_paused: false,
        canceled_at: null,
        canceled_by_user_id: null,
        cancellation_reason: null,
        created_at: now,
        last_updated_at: now,
        schema: 2,
      });
      transaction.update(authority.seriesRef, {
        round_count: admin.firestore.FieldValue.increment(1),
        last_updated_at: now,
      });
    }
    transaction.set(codeRefs[codeIndex], {
      id: shareCode,
      target_type: "round",
      target_id: id,
      model_version: 2,
      created_at: now,
      last_updated_at: now,
      schema: 2,
    });
    return { replayed: false, shareCode, series };
  });

  if (reservation.replayed) return { ...reservation, replayed: true };
  try {
    await writeProvisionedRound(id, reservation.series, authority.members, teamSnapshot.docs, now);
    const response = await db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return { ...receipt.data(), replayed: true };
      const current = await transaction.get(roundRef);
      const value = { ok: true, command_id: id, entity_id: id, revision: Math.max(current.data()?.revision || 0, 1), replayed: false };
      transaction.update(roundRef, {
        provisioning: { phase: "ready", command_id: id, last_completed_stage: "structure", failure_code: null, retry_count: 0 },
        revision: value.revision,
        last_updated_at: timeValue(),
      });
      transaction.create(receiptRef, value);
      return value;
    });
    return response;
  } catch (error) {
    await roundRef.set({
      provisioning: {
        phase: "failed",
        command_id: id,
        last_completed_stage: "root",
        failure_code: "structure_write_failed",
        retry_count: admin.firestore.FieldValue.increment(1),
      },
      last_updated_at: timeValue(),
    }, { merge: true });
    throw new HttpsError("internal", "Round provisioning failed and can be safely retried.", error.message);
  }
});

const transitionRoundV2 = onCall(async ({ auth, data }) => {
  assertAuthenticated(auth);
  const id = commandID(data?.command_id);
  const roundID = requireString(data?.round_id, "round_id");
  const target = requireString(data?.target_status, "target_status");
  const expected = Number(data?.expected_revision);
  if (!Number.isInteger(expected)) throw new HttpsError("invalid-argument", "expected_revision must be an integer.");
  const roundRef = db.collection(COLLECTIONS.rounds).doc(roundID);
  const receiptRef = db.collection(COLLECTIONS.commands).doc(receiptID(auth.uid, "transition-round", id));

  return db.runTransaction(async (transaction) => {
    const receipt = await transaction.get(receiptRef);
    if (receipt.exists) return { ...receipt.data(), replayed: true };
    const roundSnapshot = await transaction.get(roundRef);
    if (!roundSnapshot.exists) throw new HttpsError("not-found", "Round V2 was not found.");
    const round = roundSnapshot.data();
    let series = null;
    if (round.series_context?.series_id) {
      const seriesSnapshot = await transaction.get(db.collection(COLLECTIONS.series).doc(round.series_context.series_id));
      series = seriesSnapshot.data();
    }
    if (round.created_by_user_id !== auth.uid && series?.commissioner_user_id !== auth.uid) {
      throw new HttpsError("permission-denied", "Only the round owner or commissioner can change lifecycle state.");
    }
    if (round.revision !== expected) throw new HttpsError("aborted", "Round revision changed; refresh before retrying.");
    if (round.provisioning?.phase !== "ready") throw new HttpsError("failed-precondition", "Round provisioning is not ready.");
    if (!canTransition(round.status, target)) throw new HttpsError("failed-precondition", `Cannot transition ${round.status} to ${target}.`);
    const revision = expected + 1;
    const response = { ok: true, command_id: id, entity_id: roundID, revision, replayed: false };
    transaction.update(roundRef, { status: target, revision, last_updated_at: timeValue() });
    transaction.create(receiptRef, response);
    return response;
  });
});

const applySeriesDefaultsV2 = onCall(async ({ auth, data }) => {
  assertAuthenticated(auth);
  const id = commandID(data?.command_id);
  const roundID = requireString(data?.round_id, "round_id");
  const expected = Number(data?.expected_revision);
  const roundRef = db.collection(COLLECTIONS.rounds).doc(roundID);
  const roundSnapshot = await roundRef.get();
  if (!roundSnapshot.exists) throw new HttpsError("not-found", "Round V2 was not found.");
  const round = roundSnapshot.data();
  const seriesID = round.series_context?.series_id;
  if (!seriesID) throw new HttpsError("failed-precondition", "Round is not tied to a Series.");
  const authority = await loadSeriesAuthority(seriesID, auth.uid);
  const receiptRef = db.collection(COLLECTIONS.commands).doc(receiptID(auth.uid, "apply-defaults", id));

  return db.runTransaction(async (transaction) => {
    const receipt = await transaction.get(receiptRef);
    if (receipt.exists) return { ...receipt.data(), replayed: true };
    const [currentRound, currentSeries] = await Promise.all([
      transaction.get(roundRef),
      transaction.get(authority.seriesRef),
    ]);
    const value = currentRound.data();
    const series = currentSeries.data();
    if (value.status !== "lobby") throw new HttpsError("failed-precondition", "Defaults can only be applied in the lobby.");
    if (value.revision !== expected) throw new HttpsError("aborted", "Round revision changed; refresh before retrying.");
    const revision = expected + 1;
    const context = { ...value.series_context,
      applied_defaults_revision: series.settings?.round_defaults_revision || 1,
      rules: series.settings?.round_defaults?.rules || {},
      lobby_activated_at: value.series_context?.lobby_activated_at || timeValue(),
    };
    const response = { ok: true, command_id: id, entity_id: roundID, revision, replayed: false };
    transaction.update(roundRef, {
      configuration: series.settings?.round_defaults?.configuration || value.configuration,
      series_context: context,
      revision,
      last_updated_at: timeValue(),
    });
    transaction.create(receiptRef, response);
    return response;
  });
});

const adoptRoundIntoSeriesV2 = onCall(async ({ auth, data }) => {
  assertAuthenticated(auth);
  const id = commandID(data?.command_id);
  const roundID = requireString(data?.round_id, "round_id");
  const seriesID = requireString(data?.series_id, "series_id");
  const expected = Number(data?.expected_revision);
  if (!Number.isInteger(expected)) throw new HttpsError("invalid-argument", "expected_revision must be an integer.");
  const authority = await loadSeriesAuthority(seriesID, auth.uid);
  const roundRef = db.collection(COLLECTIONS.rounds).doc(roundID);
  const receiptRef = db.collection(COLLECTIONS.commands).doc(receiptID(auth.uid, "adopt-round", id));
  const scoreSnapshot = await roundRef.collection("scores").limit(1).get();
  if (!scoreSnapshot.empty) throw new HttpsError("failed-precondition", "A round with scores cannot be adopted.");
  const now = timeValue();

  const staged = await db.runTransaction(async (transaction) => {
    const receipt = await transaction.get(receiptRef);
    if (receipt.exists) return { replayed: true, ...receipt.data() };
    const [roundSnapshot, seriesSnapshot] = await Promise.all([
      transaction.get(roundRef),
      transaction.get(authority.seriesRef),
    ]);
    if (!roundSnapshot.exists) throw new HttpsError("not-found", "Round V2 was not found.");
    const round = roundSnapshot.data();
    const series = seriesSnapshot.data();
    const existingSeriesID = round.series_context?.series_id;
    if (existingSeriesID && existingSeriesID !== seriesID) {
      throw new HttpsError("failed-precondition", "Round already belongs to another Series.");
    }
    if (round.created_by_user_id !== auth.uid) {
      throw new HttpsError("permission-denied", "Only the standalone round owner can adopt it.");
    }
    if (round.status !== "lobby") throw new HttpsError("failed-precondition", "Only a lobby round can be adopted.");
    if (round.revision !== expected && !existingSeriesID) {
      throw new HttpsError("aborted", "Round revision changed; refresh before retrying.");
    }
    const defaults = series.settings?.round_defaults || {};
    const context = existingSeriesID ? round.series_context : {
      series_id: seriesID,
      round_index: series.round_count || 0,
      applied_defaults_revision: data.apply_series_defaults ? (series.settings?.round_defaults_revision || 1) : 0,
      lobby_activated_at: now,
      standings_policy_binding: null,
      team_scoring_profile_binding: null,
      individual_scoring_profile_binding: null,
      rules: defaults.rules || {},
      legacy_series_round_id: null,
      migrated_from_v1: false,
    };
    const revision = existingSeriesID ? round.revision : expected + 1;
    transaction.update(roundRef, {
      series_context: context,
      configuration: data.apply_series_defaults ? (defaults.configuration || round.configuration) : round.configuration,
      provisioning: { phase: "provisioning", command_id: id, last_completed_stage: "adopted_root", failure_code: null, retry_count: 0 },
      revision,
      last_updated_at: now,
    });
    if (!existingSeriesID) transaction.update(authority.seriesRef, {
      round_count: admin.firestore.FieldValue.increment(1),
      last_updated_at: now,
    });
    return { replayed: false, revision };
  });
  if (staged.replayed) return staged;

  const writer = db.bulkWriter();
  const playerIDs = [];
  for (const snapshot of authority.members) {
    const member = snapshot.data();
    if (member.is_active === false) continue;
    const participantID = member.player_id || snapshot.id;
    if (member.player_id) playerIDs.push(member.player_id);
    writer.set(roundRef.collection("participants").doc(participantID), {
      id: participantID,
      user_id: member.user_id || null,
      player_id: member.player_id || null,
      series_member_id: snapshot.id,
      name: member.name || EMPTY_NAME,
      participation_status: participationStatus(authority.series.settings?.round_defaults?.rules?.attendance_default),
      tee_box_id: member.default_tee_box_id || "",
      original_handicap: 0,
      adjusted_handicap: 0,
      handicap_index: null,
      team_id: member.team_id || null,
      tee_group_id: null,
      tee_order: null,
      is_host: member.user_id === auth.uid,
      is_substitute: false,
      created_at: now,
      last_updated_at: now,
      parent_id: roundID,
      schema: 2,
    }, { merge: true });
  }
  await writer.close();
  const response = await db.runTransaction(async (transaction) => {
    const receipt = await transaction.get(receiptRef);
    if (receipt.exists) return { ...receipt.data(), replayed: true };
    const updates = {
      provisioning: { phase: "ready", command_id: id, last_completed_stage: "adopted_roster", failure_code: null, retry_count: 0 },
      last_updated_at: timeValue(),
    };
    if (playerIDs.length) updates.participant_player_ids = admin.firestore.FieldValue.arrayUnion(...playerIDs);
    transaction.update(roundRef, updates);
    const value = { ok: true, command_id: id, entity_id: roundID, revision: staged.revision, replayed: false };
    transaction.create(receiptRef, value);
    return value;
  });
  return response;
});

const setSeriesMigrationPhaseV2 = onCall(async ({ auth, data }) => {
  assertAuthenticated(auth);
  const id = commandID(data?.command_id);
  const seriesID = requireString(data?.series_id, "series_id");
  const target = requireString(data?.target_phase, "target_phase");
  const expected = Number(data?.expected_revision);
  if (!Number.isInteger(expected)) throw new HttpsError("invalid-argument", "expected_revision must be an integer.");
  if (!["active", "rolled_back"].includes(target)) {
    throw new HttpsError("invalid-argument", "Commissioner cutover commands may only activate or roll back V2.");
  }

  const authority = await loadSeriesAuthority(seriesID, auth.uid);
  const routingRef = db.collection(COLLECTIONS.routing).doc(seriesID);
  const receiptRef = db.collection(COLLECTIONS.commands).doc(receiptID(auth.uid, "series-cutover", id));

  return db.runTransaction(async (transaction) => {
    const receipt = await transaction.get(receiptRef);
    if (receipt.exists) return { ...receipt.data(), replayed: true };
    const [seriesSnapshot, routingSnapshot] = await Promise.all([
      transaction.get(authority.seriesRef),
      transaction.get(routingRef),
    ]);
    if (!routingSnapshot.exists) throw new HttpsError("failed-precondition", "Series migration routing was not found.");
    const series = seriesSnapshot.data();
    const routing = routingSnapshot.data();
    if (series.commissioner_user_id !== auth.uid) {
      throw new HttpsError("permission-denied", "Only the primary commissioner can cut over or roll back a migrated Series.");
    }
    if (routing.revision !== expected) throw new HttpsError("aborted", "Migration routing changed; refresh before retrying.");
    if (!canTransitionMigration(routing.phase, target)) {
      throw new HttpsError("failed-precondition", `Cannot transition migration ${routing.phase} to ${target}.`);
    }
    if (target === "active") {
      if (!series.migration?.validated_at) throw new HttpsError("failed-precondition", "Migration validation is incomplete.");
      if (typeof routing.minimum_client_version !== "string" || !routing.minimum_client_version.trim()) {
        throw new HttpsError("failed-precondition", "A minimum V2-capable client version is required.");
      }
    }

    const now = timeValue();
    const revision = expected + 1;
    const activatedAt = target === "active" ? now : (routing.activated_at || null);
    const rolledBackAt = target === "rolled_back" ? now : null;
    const migration = {
      ...series.migration,
      phase: target,
      cutover_revision: revision,
      activated_at: activatedAt,
      rolled_back_at: rolledBackAt,
    };
    const response = { ok: true, command_id: id, entity_id: seriesID, revision, replayed: false };
    transaction.update(routingRef, {
      phase: target,
      revision,
      activated_at: activatedAt,
      rolled_back_at: rolledBackAt,
      last_updated_at: now,
    });
    transaction.update(authority.seriesRef, { migration, last_updated_at: now });
    transaction.create(receiptRef, response);
    return response;
  });
});

const propagateSeriesMemberV2 = onDocumentWritten("series-v2/{seriesID}/members/{memberID}", async (event) => {
  const { seriesID, memberID } = event.params;
  const after = event.data?.after;
  const before = event.data?.before;
  const value = after?.exists ? after.data() : null;
  const previous = before?.exists ? before.data() : null;
  const rounds = await db.collection(COLLECTIONS.rounds)
    .where("series_context.series_id", "==", seriesID)
    .where("status", "==", "lobby")
    .get();
  const writer = db.bulkWriter();
  for (const round of rounds.docs) {
    const priorID = previous?.player_id || memberID;
    const nextID = value?.player_id || memberID;
    const currentPlayerIDs = new Set(round.data().participant_player_ids || []);
    if (previous?.player_id) currentPlayerIDs.delete(previous.player_id);
    if (value?.player_id && value.is_active !== false) currentPlayerIDs.add(value.player_id);
    if (!value || value.is_active === false) {
      writer.delete(round.ref.collection("participants").doc(priorID));
      writer.update(round.ref, { participant_player_ids: [...currentPlayerIDs].sort(), last_updated_at: timeValue() });
      continue;
    }
    const participantRef = round.ref.collection("participants").doc(nextID);
    const participant = await participantRef.get();
    const participantData = {
      id: nextID,
      user_id: value.user_id || null,
      player_id: value.player_id || null,
      series_member_id: memberID,
      name: value.name || EMPTY_NAME,
      tee_box_id: value.default_tee_box_id || "",
      team_id: value.team_id || null,
      last_updated_at: timeValue(),
      parent_id: round.id,
      schema: 2,
    };
    if (!participant.exists) Object.assign(participantData, {
      participation_status: "pending",
      original_handicap: 0,
      adjusted_handicap: 0,
      handicap_index: null,
      tee_group_id: null,
      tee_order: null,
      is_host: false,
      is_substitute: false,
      created_at: timeValue(),
    });
    writer.set(participantRef, participantData, { merge: true });
    if (priorID !== nextID) writer.delete(round.ref.collection("participants").doc(priorID));
    writer.update(round.ref, { participant_player_ids: [...currentPlayerIDs].sort(), last_updated_at: timeValue() });
  }
  const indexedPlayerID = value?.player_id || previous?.player_id;
  const indexID = indexedPlayerID ? `${seriesID}_${indexedPlayerID}` : null;
  if (indexID) {
    writer.set(db.collection(COLLECTIONS.memberships).doc(indexID), {
      id: indexID,
      series_id: seriesID,
      member_id: memberID,
      player_id: indexedPlayerID,
      user_id: value?.user_id || previous?.user_id || null,
      role: value?.role || previous?.role || "member",
      is_active: Boolean(value && value.is_active !== false),
      created_at: previous?.created_at || timeValue(),
      last_updated_at: timeValue(),
      schema: 2,
    }, { merge: true });
  }
  if (previous?.player_id && value?.player_id && previous.player_id !== value.player_id) {
    writer.set(db.collection(COLLECTIONS.memberships).doc(`${seriesID}_${previous.player_id}`), {
      is_active: false,
      last_updated_at: timeValue(),
    }, { merge: true });
  }
  await writer.close();
});

module.exports = {
  COLLECTIONS,
  timeValue,
  makeShareCode,
  participationStatus,
  canTransition,
  canTransitionMigration,
  createSeriesV2,
  createSeriesRoundV2,
  transitionRoundV2,
  applySeriesDefaultsV2,
  adoptRoundIntoSeriesV2,
  setSeriesMigrationPhaseV2,
  propagateSeriesMemberV2,
};
