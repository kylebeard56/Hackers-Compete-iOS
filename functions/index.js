const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const { setGlobalOptions } = require("firebase-functions/v2");
const { onCall } = require("firebase-functions/v2/https");
const firebase_tools = require("firebase-tools");
const {
  onRoundGoesLive,
  onParticipantAddedToLiveRound,
  onParticipantRemovedFromLiveRound,
  clearAllPlayerHistory,
} = require("./history");

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
    const functions = require("firebase-functions");
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in to call this function."
    );
  }

  const path = data?.path;
  if (typeof path !== "string" || !path.includes("/")) {
    const functions = require("firebase-functions");
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Expected { path: 'collection/docId' }"
    );
  }

  try {
    // Recursively delete the document and subcollections
    await firebase_tools.firestore.delete(path, {
      project: process.env.GCLOUD_PROJECT,
      recursive: true,
      force: true,
    });

    return { ok: true, path };
  } catch (error) {
    const functions = require("firebase-functions");
    throw new functions.https.HttpsError(
      "internal",
      "Failed to delete document tree",
      error.message
    );
  }
});

exports.onRoundGoesLive = onRoundGoesLive;
exports.onParticipantAddedToLiveRound = onParticipantAddedToLiveRound;
exports.onParticipantRemovedFromLiveRound = onParticipantRemovedFromLiveRound;
exports.clearAllPlayerHistory = clearAllPlayerHistory;
