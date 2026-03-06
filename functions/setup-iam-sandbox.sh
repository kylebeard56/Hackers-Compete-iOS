#!/bin/bash
# One-time IAM setup for Firebase Functions (2nd gen) on hackers-compete-sandbox
# Run: ./setup-iam-sandbox.sh

set -e
PROJECT="hackers-compete-sandbox"

echo "Enabling required APIs..."
gcloud services enable pubsub.googleapis.com eventarc.googleapis.com run.googleapis.com cloudfunctions.googleapis.com --project=$PROJECT

echo "Creating Pub/Sub service agent (fixes 'does not exist' error)..."
gcloud beta services identity create --project=$PROJECT --service=pubsub.googleapis.com 2>/dev/null || true

echo "Waiting 30 seconds for service agents to propagate..."
sleep 30

echo "Adding IAM bindings for $PROJECT..."

gcloud projects add-iam-policy-binding $PROJECT \
  --member=serviceAccount:service-75387746846@gcp-sa-pubsub.iam.gserviceaccount.com \
  --role=roles/iam.serviceAccountTokenCreator

gcloud projects add-iam-policy-binding $PROJECT \
  --member=serviceAccount:75387746846-compute@developer.gserviceaccount.com \
  --role=roles/run.invoker

gcloud projects add-iam-policy-binding $PROJECT \
  --member=serviceAccount:75387746846-compute@developer.gserviceaccount.com \
  --role=roles/eventarc.eventReceiver

echo "Done. You can now run: npm run deploy:sandbox"
