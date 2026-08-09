const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const { setGlobalOptions } = require("firebase-functions/v2");
const { HttpsError, onCall } = require("firebase-functions/v2/https");
const firebase_tools = require("firebase-tools");
const { canDeleteRound, roundIDFromDeletePath } = require("./round-permissions");
const {
  onRoundGoesLive,
  onParticipantAddedToLiveRound,
  onParticipantRemovedFromLiveRound,
  onParticipantUpdatedInLiveRound,
  clearAllPlayerHistory,
} = require("./history");
const {
  createSeriesV2,
  createSeriesRoundV2,
  transitionRoundV2,
  applySeriesDefaultsV2,
  adoptRoundIntoSeriesV2,
  setSeriesMigrationPhaseV2,
  propagateSeriesMemberV2,
} = require("./series-round-v2");

// Set defaults for all functions
setGlobalOptions({
  region: "us-central1",
  timeoutSeconds: 540,
  memory: "2GiB",
  maxInstances: 10,
});

exports.deleteFullRound = onCall(async (request) => {
  const { auth, data } = request;

  // Require the user to be signed in
  if (!auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be signed in to call this function."
    );
  }

  const path = data?.path;
  const roundID = roundIDFromDeletePath(path);
  if (!roundID) {
    throw new HttpsError(
      "invalid-argument",
      "Expected { path: 'rounds/roundId' }"
    );
  }

  const roundSnapshot = await admin.firestore().collection("rounds").doc(roundID).get();
  if (!roundSnapshot.exists) {
    throw new HttpsError("not-found", "Round was not found.");
  }
  if (!canDeleteRound(roundSnapshot.data(), auth.uid)) {
    throw new HttpsError("permission-denied", "Only the round creator can delete this round.");
  }

  try {
    // Recursively delete the document and subcollections
    await firebase_tools.firestore.delete(`rounds/${roundID}`, {
      project: process.env.GCLOUD_PROJECT,
      recursive: true,
      force: true,
    });

    return { ok: true, path };
  } catch (error) {
    throw new HttpsError(
      "internal",
      "Failed to delete document tree",
      error.message
    );
  }
});

exports.onRoundGoesLive = onRoundGoesLive;
exports.onParticipantAddedToLiveRound = onParticipantAddedToLiveRound;
exports.onParticipantRemovedFromLiveRound = onParticipantRemovedFromLiveRound;
exports.onParticipantUpdatedInLiveRound = onParticipantUpdatedInLiveRound;
exports.clearAllPlayerHistory = clearAllPlayerHistory;
exports.createSeriesV2 = createSeriesV2;
exports.createSeriesRoundV2 = createSeriesRoundV2;
exports.transitionRoundV2 = transitionRoundV2;
exports.applySeriesDefaultsV2 = applySeriesDefaultsV2;
exports.adoptRoundIntoSeriesV2 = adoptRoundIntoSeriesV2;
exports.setSeriesMigrationPhaseV2 = setSeriesMigrationPhaseV2;
exports.propagateSeriesMemberV2 = propagateSeriesMemberV2;
