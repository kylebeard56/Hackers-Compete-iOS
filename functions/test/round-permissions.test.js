"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  canDeleteRound,
  roundIDFromDeletePath,
  roundOwnerUserID,
} = require("../round-permissions");

test("delete path accepts exactly one round document", () => {
  assert.equal(roundIDFromDeletePath("rounds/round-1"), "round-1");
  assert.equal(roundIDFromDeletePath(" rounds/round-1 "), null);
  assert.equal(roundIDFromDeletePath("series/series-1"), null);
  assert.equal(roundIDFromDeletePath("rounds/round-1/scores/score-1"), null);
  assert.equal(roundIDFromDeletePath("rounds/"), null);
  assert.equal(roundIDFromDeletePath(null), null);
});

test("round ownership supports legacy and V2 creator fields", () => {
  assert.equal(roundOwnerUserID({ created_by: "legacy-owner" }), "legacy-owner");
  assert.equal(roundOwnerUserID({ created_by_user_id: "v2-owner" }), "v2-owner");
  assert.equal(canDeleteRound({ created_by: "owner" }, "owner"), true);
  assert.equal(canDeleteRound({ created_by_user_id: "owner" }, "other"), false);
});
