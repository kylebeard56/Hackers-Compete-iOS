#!/usr/bin/env node
"use strict";

// Dry-run by default. Add --write only after reviewing the emitted manifest.
const crypto = require("node:crypto");
const admin = require("firebase-admin");
const args = process.argv.slice(2);
const valueAfter = (flag) => {
  const index = args.indexOf(flag);
  return index >= 0 ? args[index + 1] : null;
};
const projectID = valueAfter("--project");
if (!admin.apps.length) admin.initializeApp(projectID ? { projectId: projectID } : undefined);
const { timeValue, makeShareCode } = require("./series-round-v2");
const db = admin.firestore();
const write = args.includes("--write");
const seriesFilter = valueAfter("--series");
const minimumClientVersion = valueAfter("--minimum-client-version");

function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonical(value[key])]));
  }
  return value;
}

function semanticHash(value) {
  return crypto.createHash("sha256").update(JSON.stringify(canonical(value))).digest("hex");
}

function v2Status(status) {
  if (status === "complete") return "completed";
  if (status === "paused") return "live";
  return ["lobby", "live", "archived"].includes(status) ? status : "lobby";
}

function rulesFrom(settings, roundConfig = {}) {
  return {
    attendance_enabled: settings.is_attendance_enabled !== false,
    attendance_default: settings.attendance_default || "pending",
    roster_application_policy: "until_live",
    matchup_mode: roundConfig.matchup_mode || "field",
    pod_grouping_strategy: roundConfig.pod_grouping_strategy || settings.pod_grouping_default || "disabled",
    team_assignment_mode: roundConfig.team_assignment_mode || "manual",
    tee_group_mode: roundConfig.tee_group_mode || "auto",
    counts_toward_handicap_pool: roundConfig.counts_toward_handicap_pool !== false,
    excluded_handicap_member_ids: roundConfig.excluded_handicap_member_ids || [],
    commissioner_only_structure_edits: true,
  };
}

function configurationFrom(roundConfiguration, seriesRoundConfig = {}) {
  const config = roundConfiguration || {};
  const primary = config.primary_format?.configuration || {};
  return {
    template_id: config.format_summary?.template_id || seriesRoundConfig.format_template_id || "stroke-play",
    format_summary: config.format_summary || {
      template_id: seriesRoundConfig.format_template_id || "stroke-play",
      name: "Stroke Play",
      icon: "f450",
      category: "stroke",
    },
    courses: config.courses || [],
    competition_scope: config.competition_scope || seriesRoundConfig.competition_scope || "field",
    team_scoring: config.team_scoring || seriesRoundConfig.team_scoring || { mode: "all", count: 1, scope: "per_hole" },
    stableford_points: config.stableford_points || null,
    score_owner_scope: config.score_owner_scope || seriesRoundConfig.score_owner_scope || "individual",
    matchup_scoring_style: config.matchup_scoring_style || seriesRoundConfig.matchup_scoring_style || "aggregate_round_total",
    hole_win_points: config.hole_win_points ?? seriesRoundConfig.hole_win_points ?? 1,
    match_winner_bonus_points: config.match_winner_bonus_points ?? seriesRoundConfig.match_winner_bonus_points ?? 0,
    match_tie_policy: config.match_tie_policy || seriesRoundConfig.match_tie_policy || "half",
    selection_domain: config.selection_domain || seriesRoundConfig.selection_domain || null,
    score_input_mode: config.score_input_mode || "strokes",
    score_basis: primary.basis || seriesRoundConfig.score_basis_override || "gross",
    max_score_over_par: primary.max_score_over_par || seriesRoundConfig.max_score_over_par || "quad",
    handicap_stroke_basis: config.handicap_stroke_basis || seriesRoundConfig.handicap_stroke_basis || null,
    shared_score_handicap_config: config.shared_score_handicap_config || seriesRoundConfig.shared_score_handicap_config || null,
    handicap_entry_format: config.handicap_entry_format || seriesRoundConfig.handicap_entry_format || "strokes",
    handicap_normalization_mode: config.handicap_normalization_mode || seriesRoundConfig.handicap_normalization_mode || "off",
    handicap_maximum: config.league_handicap_maximum ?? null,
    secret_scoring: config.secret_scoring || false,
    scores_revealed: config.scores_revealed || false,
    team_colors_enabled: config.team_colors_enabled !== false,
    substitutes_score: config.substitutes_score || false,
  };
}

async function getDocs(reference) {
  return (await reference.get()).docs;
}

async function courseSegment(selection) {
  if (!selection?.course_id) return null;
  const snapshot = await db.collection("courses").doc(selection.course_id).get();
  if (!snapshot.exists) throw new Error(`Course not found for V1 selection: ${selection.course_id}`);
  const course = snapshot.data();
  const segment = selection.hole_segment || { type: "full18" };
  const range = segment.type === "front9" ? { startHole: 1, endHole: 9 }
    : segment.type === "back9" ? { startHole: 10, endHole: 18 }
      : segment.type === "custom" ? { startHole: segment.lower, endHole: segment.upper }
        : { startHole: 1, endHole: 18 };
  return {
    course_info: {
      id: snapshot.id,
      golf_course_api_id: course.golf_course_api_id || null,
      name: selection.cached_name || course.course_name || course.club_name || "Course",
      total_holes: range.endHole - range.startHole + 1,
      location: course.location || null,
      venue_details: course.venue_details || null,
      tees: course.tees || [],
    },
    hole_range: range,
    default_tee: selection.default_tee_box_id || null,
  };
}

async function planSeries(seriesSnapshot) {
  const source = seriesSnapshot.data();
  const sourceRef = seriesSnapshot.ref;
  const [members, teams, pods, attendance, seriesRounds] = await Promise.all([
    getDocs(sourceRef.collection("members")),
    getDocs(sourceRef.collection("teams")),
    getDocs(sourceRef.collection("pods")),
    getDocs(sourceRef.collection("attendance")),
    getDocs(sourceRef.collection("rounds")),
  ]);
  const settings = source.settings || {};
  const defaultConfig = settings.default_round_config || {};
  const defaultCourseSegment = await courseSegment(settings.default_course);
  const rounds = [];

  for (const shellSnapshot of seriesRounds.sort((a, b) => (a.data().index || 0) - (b.data().index || 0))) {
    const shell = shellSnapshot.data();
    const roundID = shell.round_id || shellSnapshot.id;
    const linked = shell.round_id ? await db.collection("rounds").doc(shell.round_id).get() : null;
    const linkedRound = linked?.exists ? linked.data() : null;
    const subcollections = {};
    if (linkedRound) {
      for (const name of ["participants", "teams", "tee-groups", "scoring-groups", "segments", "scores"]) {
        subcollections[name] = await getDocs(linked.ref.collection(name));
      }
    }
    const selectedCourseSegment = linkedRound ? null : await courseSegment(shell.course_override || settings.default_course);
    rounds.push({ shellSnapshot, shell, roundID, linkedRound, subcollections, selectedCourseSegment });
  }

  return { source, sourceRef, members, teams, pods, attendance, rounds, settings, defaultConfig, defaultCourseSegment };
}

function manifestFor(plan) {
  return {
    series_id: plan.sourceRef.id,
    members: plan.members.length,
    teams: plan.teams.length,
    pods: plan.pods.length,
    attendance: plan.attendance.length,
    rounds: plan.rounds.map(({ roundID, linkedRound, subcollections, shell }) => ({
      source_series_round_id: shell.id || roundID,
      round_id: roundID,
      had_linked_round: Boolean(linkedRound),
      status: v2Status(linkedRound?.status || shell.status),
      documents: Object.fromEntries(Object.entries(subcollections).map(([key, value]) => [key, value.length])),
    })),
    source_semantic_hash: semanticHash({
      root: plan.source,
      members: plan.members.map((item) => item.data()),
      teams: plan.teams.map((item) => item.data()),
      rounds: plan.rounds.map((item) => ({ shell: item.shell, round: item.linkedRound })),
    }),
  };
}

function mappedRoundChild(collection, data, roundID) {
  const base = { ...data, parent_id: roundID, schema: 2 };
  if (collection === "participants") {
    return {
      ...base,
      participation_status: data.presence_status === "no_show" ? "no_show" : "confirmed",
      tee_group_id: data.group_id || null,
    };
  }
  if (collection === "teams") return { ...base, series_team_id: data.series_team_id || null };
  if (collection === "tee-groups") return { ...base, source_plan_id: data.source_plan_id || null };
  if (collection === "scoring-groups") {
    return {
      ...base,
      source_series_pod_id: data.seed_series_pod_id || null,
      source_partnership_plan_id: data.source_partnership_plan_id || null,
      participant_ids: data.participant_ids || data.member_ids || [],
    };
  }
  if (collection === "segments") {
    return {
      ...base,
      template_id: data.template_id || data.game_format || "stroke-play",
      matchups: data.matchups || [],
      competition_scope: data.competition_scope || "field",
    };
  }
  if (collection === "scores") return { ...base, tee_group_id: data.tee_group_id || data.group_id || "" };
  return base;
}

async function writeSeries(plan, manifest) {
  const id = plan.sourceRef.id;
  const targetRef = db.collection("series-v2").doc(id);
  const routingRef = db.collection("series-routing-v2").doc(id);
  const now = timeValue();
  const s = plan.settings;
  const defaults = {
    configuration: configurationFrom(null, plan.defaultConfig),
    rules: rulesFrom(s, plan.defaultConfig),
    default_team_scoring_profile_id: s.default_team_scoring_profile_id || null,
    default_individual_scoring_profile_id: s.default_individual_scoring_profile_id || null,
    scheduled_tee_time_minutes_from_midnight: s.default_scheduled_tee_time_minutes_from_midnight || null,
    recurring_play_weekdays: s.recurring_play_weekdays || [],
  };
  if (plan.defaultCourseSegment) defaults.configuration.courses = [plan.defaultCourseSegment];
  const target = {
    id,
    name: plan.source.name,
    description: plan.source.description || null,
    share_code: plan.source.share_code || "",
    commissioner_user_id: plan.source.commissioner_user_id,
    commissioner_player_id: plan.source.commissioner_player_id || null,
    status: plan.source.status,
    visibility: plan.source.visibility,
    settings: {
      experience_preset: s.experience_preset || "league",
      round_defaults: defaults,
      round_defaults_revision: 1,
      handicap_config: s.handicap_config || {},
      allow_manual_award_overrides: s.allow_manual_award_overrides !== false,
      use_teams: s.use_teams || false,
      use_individual_standings: s.use_individual_standings !== false,
      use_team_standings: s.use_team_standings || false,
      show_scoreboard_tile: s.show_scoreboard_tile || false,
      standings_policy_revision: s.standings_policy_revision || null,
      standings_read_authority: s.standings_read_authority || "legacy",
    },
    round_count: plan.rounds.length,
    completed_round_count: plan.source.completed_round_count || 0,
    active_announcement_count: plan.source.active_announcement_count || 0,
    minimum_client_version: minimumClientVersion,
    migration: {
      source_series_id: id,
      phase: "copying",
      cutover_revision: 0,
      migrated_at: now,
      validated_at: null,
      activated_at: null,
      rolled_back_at: null,
      source_semantic_hash: manifest.source_semantic_hash,
    },
    created_at: plan.source.created_at,
    last_updated_at: now,
    starts_at: plan.source.starts_at || null,
    ends_at: plan.source.ends_at || null,
    schema: 2,
  };

  if (target.share_code) {
    const reservation = await db.collection("join-codes-v2").doc(target.share_code).get();
    if (reservation.exists && reservation.data()?.target_id !== id) {
      throw new Error(`V2 join-code collision for Series ${id}: ${target.share_code}`);
    }
  }
  const existingRouting = await routingRef.get();
  if (existingRouting.exists && ["active", "rolled_back"].includes(existingRouting.data()?.phase)) {
    throw new Error(`Refusing to overwrite ${existingRouting.data().phase} migration routing for Series ${id}.`);
  }

  const writer = db.bulkWriter();
  writer.set(targetRef, target);
  writer.set(routingRef, {
    id,
    source_series_id: id,
    target_series_id: id,
    phase: "copying",
    revision: 0,
    minimum_client_version: minimumClientVersion,
    activated_at: null,
    rolled_back_at: null,
    created_at: existingRouting.data()?.created_at || now,
    last_updated_at: now,
    schema: 2,
  });
  if (target.share_code) writer.set(db.collection("join-codes-v2").doc(target.share_code), {
    id: target.share_code, target_type: "series", target_id: id, model_version: 2,
    created_at: now, last_updated_at: now, schema: 2,
  });
  for (const memberSnapshot of plan.members) {
    const member = memberSnapshot.data();
    writer.set(targetRef.collection("members").doc(memberSnapshot.id), {
      ...member, id: memberSnapshot.id, legacy_member_id: memberSnapshot.id, parent_id: id, schema: 2,
    });
    if (member.player_id) {
      const indexID = `${id}_${member.player_id}`;
      writer.set(db.collection("series-memberships-v2").doc(indexID), {
        id: indexID, series_id: id, member_id: memberSnapshot.id, player_id: member.player_id,
        user_id: member.user_id || null, role: member.role || "member", is_active: member.is_active !== false,
        created_at: member.created_at || now, last_updated_at: now, schema: 2,
      });
    }
  }
  for (const teamSnapshot of plan.teams) writer.set(targetRef.collection("teams").doc(teamSnapshot.id), {
    ...teamSnapshot.data(), id: teamSnapshot.id, legacy_team_id: teamSnapshot.id, parent_id: id, schema: 2,
  });
  for (const podSnapshot of plan.pods) writer.set(targetRef.collection("pods").doc(podSnapshot.id), {
    ...podSnapshot.data(), id: podSnapshot.id, parent_id: id, schema: 2,
  });

  for (const item of plan.rounds) {
    const { shell, linkedRound, roundID } = item;
    const status = v2Status(linkedRound?.status || shell.status);
    const roundRef = db.collection("rounds-v2").doc(roundID);
    const config = configurationFrom(linkedRound?.configuration, shell.round_config || plan.defaultConfig);
    if (!linkedRound && item.selectedCourseSegment) config.courses = [item.selectedCourseSegment];
    const participantIDs = linkedRound?.players || plan.members.map((member) => member.data().player_id).filter(Boolean);
    const shareCode = linkedRound?.share_code || makeShareCode(`migration:${roundID}`);
    const reservation = await db.collection("join-codes-v2").doc(shareCode).get();
    if (reservation.exists && reservation.data()?.target_id !== roundID) {
      throw new Error(`V2 join-code collision for Round ${roundID}: ${shareCode}`);
    }
    writer.set(roundRef, {
      id: roundID,
      name: linkedRound?.name || shell.title || null,
      share_code: shareCode,
      created_by_user_id: linkedRound?.created_by || plan.source.commissioner_user_id,
      status,
      schedule: shell.scheduled_at ? { scheduled_at: shell.scheduled_at, time_zone_identifier: "UTC" } : null,
      configuration: config,
      series_context: {
        series_id: id,
        round_index: shell.index || 0,
        applied_defaults_revision: 1,
        lobby_activated_at: linkedRound ? (linkedRound.created_at || now) : null,
        standings_policy_binding: shell.policy_binding || null,
        team_scoring_profile_binding: null,
        individual_scoring_profile_binding: null,
        rules: rulesFrom(s, shell.round_config || plan.defaultConfig),
        legacy_series_round_id: item.shellSnapshot.id,
        migrated_from_v1: true,
      },
      participant_player_ids: [...new Set(participantIDs)].sort(),
      provisioning: { phase: "ready", command_id: `migration_${id}`, last_completed_stage: "validated_copy", failure_code: null, retry_count: 0 },
      revision: 1,
      scoring_paused: linkedRound?.status === "paused",
      canceled_at: null,
      canceled_by_user_id: null,
      cancellation_reason: null,
      created_at: linkedRound?.created_at || shell.created_at || now,
      last_updated_at: now,
      schema: 2,
    });
    writer.set(db.collection("join-codes-v2").doc(shareCode), {
      id: shareCode, target_type: "round", target_id: roundID, model_version: 2,
      created_at: linkedRound?.created_at || now, last_updated_at: now, schema: 2,
    });
    for (const [collection, docs] of Object.entries(item.subcollections)) {
      for (const child of docs) writer.set(roundRef.collection(collection).doc(child.id), mappedRoundChild(collection, child.data(), roundID));
    }
    if (!linkedRound) {
      const attendance = new Map(
        plan.attendance
          .map((snapshot) => snapshot.data())
          .filter((value) => value.series_round_id === item.shellSnapshot.id)
          .map((value) => [value.member_id, value.status])
      );
      const activeMembers = plan.members
        .map((snapshot) => ({ id: snapshot.id, ...snapshot.data() }))
        .filter((member) => member.is_active !== false);
      const eligible = activeMembers.filter((member) => attendance.get(member.id) !== "no");
      const groupByMember = new Map();
      const plannedTeeGroups = [];
      for (let offset = 0; offset < eligible.length; offset += 4) {
        const group = eligible.slice(offset, offset + 4);
        const groupID = `tee-${String(offset / 4 + 1).padStart(3, "0")}`;
        const ids = group.map((member) => member.player_id || member.id);
        plannedTeeGroups.push({ id: groupID, participantIDs: ids });
        writer.set(roundRef.collection("tee-groups").doc(groupID), {
          id: groupID, source_plan_id: null, index: offset / 4, tee_time: null, starting_hole: 1,
          created_at: now, last_updated_at: now, parent_id: roundID, schema: 2,
        });
        writer.set(roundRef.collection("scoring-groups").doc(groupID), {
          id: groupID, source_series_pod_id: null, source_partnership_plan_id: null,
          team_id: null, tee_group_id: groupID, kind: "tee_group", participant_ids: ids,
          label: `Group ${offset / 4 + 1}`, created_at: now, last_updated_at: now, parent_id: roundID, schema: 2,
        });
        group.forEach((member, order) => groupByMember.set(member.id, { id: groupID, order }));
      }
      for (const member of activeMembers) {
        const participantID = member.player_id || member.id;
        const group = groupByMember.get(member.id);
        const response = attendance.get(member.id);
        writer.set(roundRef.collection("participants").doc(participantID), {
          id: participantID, user_id: member.user_id || null, player_id: member.player_id || null,
          series_member_id: member.id, name: member.name, participation_status: response === "accepted" ? "confirmed" : response === "no" ? "declined" : "pending",
          tee_box_id: member.default_tee_box_id || "", original_handicap: 0, adjusted_handicap: 0,
          handicap_index: null, team_id: member.team_id || null, tee_group_id: group?.id || null,
          tee_order: group?.order ?? null, is_host: member.user_id === plan.source.commissioner_user_id,
          is_substitute: member.role === "substitute", created_at: now, last_updated_at: now,
          parent_id: roundID, schema: 2,
        });
      }
      for (const teamSnapshot of plan.teams) {
        const team = teamSnapshot.data();
        writer.set(roundRef.collection("teams").doc(teamSnapshot.id), {
          id: teamSnapshot.id, series_team_id: teamSnapshot.id, name: team.name || "",
          color: team.custom_color_hex || team.color || "", index: team.index || 0,
          created_at: now, last_updated_at: now, parent_id: roundID, schema: 2,
        });
      }
      let scoringUnits;
      if (config.score_owner_scope === "tee_group") {
        scoringUnits = plannedTeeGroups.map((group) => ({
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
      } else if (config.selection_domain === "team" && plan.teams.length) {
        scoringUnits = plan.teams.map((team) => ({
          id: team.id, owner: "team", owner_ids: [team.id], scoring_method: "aggregate",
        }));
      } else {
        scoringUnits = eligible.map((member) => {
          const participantID = member.player_id || member.id;
          return { id: participantID, owner: "participant", owner_ids: [participantID], scoring_method: "individual" };
        });
      }
      writer.set(roundRef.collection("segments").doc("segment-1"), {
        id: "segment-1", hole_range: item.selectedCourseSegment?.hole_range || { startHole: 1, endHole: 18 }, template_id: config.template_id,
        scoring_units: scoringUnits,
        matchups: [], competition_scope: config.competition_scope,
        created_at: now, last_updated_at: now, parent_id: roundID, schema: 2,
      });
    }
    writer.set(targetRef.collection("round-result-states").doc(roundID), {
      id: roundID,
      status: shell.awards_status === "finalized" ? "finalized" : "pending",
      latest_generation_id: null,
      semantic_hash: null,
      failure_code: null,
      finalized_at: shell.awards_finalized_at || null,
      created_at: shell.created_at || now,
      last_updated_at: now,
      parent_id: id,
      schema: 2,
    });
  }

  for (const collection of ["announcements", "scoring-profiles", "handicap-scores", "handicap-overrides", "round-results", "standings"]) {
    for (const snapshot of await getDocs(plan.sourceRef.collection(collection))) {
      writer.set(targetRef.collection(collection).doc(snapshot.id), { ...snapshot.data(), parent_id: id, schema: 2 });
    }
  }
  await writer.close();
}

async function validateWrittenSeries(plan, sourceManifest) {
  const target = await db.collection("series-v2").doc(plan.sourceRef.id).get();
  const routingRef = db.collection("series-routing-v2").doc(plan.sourceRef.id);
  const validatingAt = timeValue();
  await Promise.all([
    target.ref.update({ "migration.phase": "validating", last_updated_at: validatingAt }),
    routingRef.update({ phase: "validating", last_updated_at: validatingAt }),
  ]);
  const rounds = await db.collection("rounds-v2").where("series_context.series_id", "==", plan.sourceRef.id).get();
  const errors = [];
  if (!target.exists) errors.push("missing_series_root");
  if (rounds.size !== plan.rounds.length) errors.push(`round_count:${rounds.size}/${plan.rounds.length}`);
  for (const sourceRound of plan.rounds) {
    const result = await db.collection("rounds-v2").doc(sourceRound.roundID).get();
    if (!result.exists) errors.push(`missing_round:${sourceRound.roundID}`);
    else if (result.data().series_context?.legacy_series_round_id !== sourceRound.shellSnapshot.id) {
      errors.push(`round_mapping:${sourceRound.roundID}`);
    }
    if (result.exists) {
      for (const [collection, sourceDocs] of Object.entries(sourceRound.subcollections)) {
        const targetDocs = await result.ref.collection(collection).get();
        const expected = sourceDocs
          .map((snapshot) => ({ id: snapshot.id, data: mappedRoundChild(collection, snapshot.data(), sourceRound.roundID) }))
          .sort((a, b) => a.id.localeCompare(b.id));
        const actual = targetDocs.docs
          .map((snapshot) => ({ id: snapshot.id, data: snapshot.data() }))
          .sort((a, b) => a.id.localeCompare(b.id));
        if (semanticHash(expected) !== semanticHash(actual)) {
          errors.push(`semantic_mismatch:${sourceRound.roundID}/${collection}`);
        }
      }
      if (!sourceRound.linkedRound) {
        const [participants, segments] = await Promise.all([
          result.ref.collection("participants").get(),
          result.ref.collection("segments").get(),
        ]);
        const expectedParticipants = plan.members.filter((member) => member.data().is_active !== false).length;
        if (participants.size !== expectedParticipants) {
          errors.push(`planned_participants:${sourceRound.roundID}:${participants.size}/${expectedParticipants}`);
        }
        if (segments.empty) errors.push(`planned_segment:${sourceRound.roundID}`);
      }
    }
  }
  const sourceResults = await plan.sourceRef.collection("round-results").get();
  const targetResults = await target.ref.collection("round-results").get();
  const expectedResults = sourceResults.docs
    .map((snapshot) => ({ id: snapshot.id, data: { ...snapshot.data(), parent_id: plan.sourceRef.id, schema: 2 } }))
    .sort((a, b) => a.id.localeCompare(b.id));
  const actualResults = targetResults.docs
    .map((snapshot) => ({ id: snapshot.id, data: snapshot.data() }))
    .sort((a, b) => a.id.localeCompare(b.id));
  if (semanticHash(expectedResults) !== semanticHash(actualResults)) errors.push("semantic_mismatch:round-results");
  const completedAt = timeValue();
  if (errors.length === 0) {
    await Promise.all([
      target.ref.update({
        "migration.phase": "ready",
        "migration.validated_at": completedAt,
        "migration.source_semantic_hash": sourceManifest.source_semantic_hash,
        last_updated_at: completedAt,
      }),
      routingRef.update({ phase: "ready", last_updated_at: completedAt }),
    ]);
  } else {
    await Promise.all([
      target.ref.update({ "migration.phase": "failed", last_updated_at: completedAt }),
      routingRef.update({ phase: "failed", last_updated_at: completedAt }),
    ]);
  }
  return errors;
}

async function main() {
  if (!projectID) {
    throw new Error("An explicit --project is required for every migration read or write.");
  }
  if (write && !minimumClientVersion) {
    throw new Error("--write requires --minimum-client-version so migrated leagues can enforce the V2-capable app build.");
  }
  const snapshots = seriesFilter
    ? [await db.collection("series").doc(seriesFilter).get()]
    : (await db.collection("series").get()).docs;
  const reports = [];
  for (const snapshot of snapshots) {
    if (!snapshot.exists) throw new Error(`V1 Series not found: ${seriesFilter}`);
    const plan = await planSeries(snapshot);
    const manifest = manifestFor(plan);
    const report = { mode: write ? "write" : "dry-run", ...manifest, validation_errors: [] };
    if (write) {
      await writeSeries(plan, manifest);
      report.validation_errors = await validateWrittenSeries(plan, manifest);
      if (report.validation_errors.length) process.exitCode = 2;
    }
    reports.push(report);
  }
  process.stdout.write(`${JSON.stringify({ generated_at: timeValue(), reports }, null, 2)}\n`);
}

if (require.main === module) {
  main().catch((error) => {
    process.stderr.write(`${error.stack || error.message}\n`);
    process.exitCode = 1;
  });
}

module.exports = { canonical, semanticHash, v2Status, rulesFrom, configurationFrom, mappedRoundChild };
