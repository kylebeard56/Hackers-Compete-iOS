"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp({ projectId: "hackers-v2-tests" });

const {
  makeShareCode,
  participationStatus,
  canTransition,
  canTransitionMigration,
} = require("../series-round-v2");
const {
  configurationFrom,
  mappedRoundChild,
  v2Status,
} = require("../migrate-series-v1-to-v2");

test("share codes are deterministic and omit ambiguous characters", () => {
  const first = makeShareCode("command-123", 0);
  assert.equal(first, makeShareCode("command-123", 0));
  assert.equal(first.length, 6);
  assert.match(first, /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]+$/);
  assert.notEqual(first, makeShareCode("command-123", 1));
});

test("legacy attendance defaults map to V2 participation", () => {
  assert.equal(participationStatus("accepted"), "confirmed");
  assert.equal(participationStatus("no"), "declined");
  assert.equal(participationStatus("pending"), "pending");
});

test("round lifecycle only moves forward through canonical states", () => {
  assert.equal(canTransition("lobby", "live"), true);
  assert.equal(canTransition("live", "completed"), true);
  assert.equal(canTransition("completed", "archived"), true);
  assert.equal(canTransition("completed", "live"), false);
  assert.equal(canTransition("lobby", "completed"), false);
});

test("migration cutover only activates ready data and rolls back active data", () => {
  assert.equal(canTransitionMigration("ready", "active"), true);
  assert.equal(canTransitionMigration("active", "rolled_back"), true);
  assert.equal(canTransitionMigration("rolled_back", "active"), true);
  assert.equal(canTransitionMigration("copying", "active"), false);
  assert.equal(canTransitionMigration("ready", "rolled_back"), false);
});

test("migration maps paused and completed lifecycle without losing pause semantics", () => {
  assert.equal(v2Status("paused"), "live");
  assert.equal(v2Status("complete"), "completed");
  assert.equal(v2Status("archived"), "archived");
});

test("migration creates a decode-compatible default format summary", () => {
  const configuration = configurationFrom(null, { format_template_id: "stroke-play" });
  assert.deepEqual(configuration.format_summary, {
    template_id: "stroke-play",
    name: "Stroke Play",
    icon: "f450",
    category: "stroke",
  });
  assert.equal(configuration.score_basis, "gross");
  assert.equal(configuration.max_score_over_par, "quad");
});

test("migration maps V1 participant group and presence fields", () => {
  const mapped = mappedRoundChild("participants", {
    id: "p1",
    group_id: "g1",
    presence_status: "no_show",
  }, "r1");
  assert.equal(mapped.tee_group_id, "g1");
  assert.equal(mapped.participation_status, "no_show");
  assert.equal(mapped.parent_id, "r1");
  assert.equal(mapped.schema, 2);
});
