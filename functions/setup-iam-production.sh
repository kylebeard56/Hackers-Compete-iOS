#!/bin/bash
# One-time IAM setup for Firebase Functions (2nd gen) on hackers-compete (production)
# Run: ./setup-iam-production.sh

set -e
PROJECT="hackers-compete"

echo "Enabling required APIs..."
gcloud services enable pubsub.googleapis.com eventarc.googleapis.com run.googleapis.com cloudfunctions.googleapis.com --project=$PROJECT

echo "Creating Pub/Sub service agent (fixes 'does not exist' error)..."
gcloud beta services identity create --project=$PROJECT --service=pubsub.googleapis.com 2>/dev/null || true

echo "Waiting 30 seconds for service agents to propagate..."
sleep 30

echo "Getting project number for $PROJECT..."
PROJECT_NUMBER=$(gcloud projects describe $PROJECT --format='value(projectNumber)')
if [ -z "$PROJECT_NUMBER" ]; then
  echo "Error: Could not get project number. Is gcloud authenticated and does $PROJECT exist?"
  exit 1
fi
echo "Project number: $PROJECT_NUMBER"

echo "Adding IAM bindings for $PROJECT..."

gcloud projects add-iam-policy-binding $PROJECT \
  --member=serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com \
  --role=roles/iam.serviceAccountTokenCreator

gcloud projects add-iam-policy-binding $PROJECT \
  --member=serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
  --role=roles/run.invoker

gcloud projects add-iam-policy-binding $PROJECT \
  --member=serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
  --role=roles/eventarc.eventReceiver

echo "Done. You can now run: npm run deploy:production"
echo ""
echo "If you got 'does not exist' errors, wait 2-3 minutes and run this script again."
