"use strict";

function roundIDFromDeletePath(path) {
  if (typeof path !== "string") return null;
  const match = /^rounds\/([^/]+)$/.exec(path);
  return match?.[1] || null;
}

function roundOwnerUserID(round) {
  return round?.created_by_user_id || round?.created_by || null;
}

function canDeleteRound(round, uid) {
  return typeof uid === "string" && uid.length > 0 && roundOwnerUserID(round) === uid;
}

module.exports = {
  canDeleteRound,
  roundIDFromDeletePath,
  roundOwnerUserID,
};
