// functions/index.js (v2)
const { setGlobalOptions } = require("firebase-functions/v2");
const { onCall } = require("firebase-functions/v2/https");
const firebase_tools = require("firebase-tools");

// v2: global defaults apply to all functions (can still override per-function)
setGlobalOptions({ timeoutSeconds: 540, memory: "2GiB", maxInstances: 10 });

exports.recursiveDelete = onCall(async (request) => {
  // v2 uses `request` instead of (data, context)
  const { auth, data } = request;

  if (!(auth && auth.token && auth.token.admin)) {
    // v2 throws the same HttpsError (comes from v1 package name, but works)
    const functions = require("firebase-functions");
    throw new functions.https.HttpsError("permission-denied", "Admin only");
  }

  const path = data?.path;
  if (typeof path !== "string" || !path.includes("/")) {
    const functions = require("firebase-functions");
    throw new functions.https.HttpsError("invalid-argument", "Expect { path: 'collection/docId' }");
  }

  await firebase_tools.firestore.delete(path, {
    project: process.env.GCLOUD_PROJECT,
    recursive: true,
    force: true,
  });

  return { ok: true, path };
});
