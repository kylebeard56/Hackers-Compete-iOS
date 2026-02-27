#!/usr/bin/env bash
#
# Deploy Hackers to TestFlight: archive, upload, set export compliance, distribute to Beta Testers.
#
# Prerequisites:
#   - App Store Connect API Key (recommended): Create at App Store Connect > Users and Access > Keys
#   - Or Apple ID + App-specific password for legacy auth
#
# Usage:
#   ./scripts/deploy-testflight.sh [options]
#
# Options:
#   --group "Group Name"     External beta group (default: "Beta Testers")
#   --api-key-path PATH     Path to App Store Connect API key JSON
#   --changelog "Text"      "What to Test" text for TestFlight
#   -h, --help              Show this help
#
# Environment variables:
#   APP_STORE_CONNECT_API_KEY_PATH  Path to API key JSON (alternative to --api-key-path)
#   EXTERNAL_GROUP                  External group name (alternative to --group)
#   CHANGELOG                       What to Test text (alternative to --changelog)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GROUP="Beta Testers"
API_KEY_PATH=""
CHANGELOG=""

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --group)
      GROUP="$2"
      shift 2
      ;;
    --api-key-path)
      API_KEY_PATH="$2"
      shift 2
      ;;
    --changelog)
      CHANGELOG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# Resolve API key path
if [[ -z "$API_KEY_PATH" && -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]]; then
  API_KEY_PATH="$APP_STORE_CONNECT_API_KEY_PATH"
fi

cd "$PROJECT_ROOT"

# Check for fastlane
if ! command -v fastlane &>/dev/null; then
  echo "Error: fastlane is not installed. Run: bundle install && bundle exec fastlane"
  exit 1
fi

export EXTERNAL_GROUP="$GROUP"
[[ -n "$CHANGELOG" ]] && export CHANGELOG

if [[ -n "$API_KEY_PATH" ]]; then
  if [[ ! -f "$API_KEY_PATH" ]]; then
    echo "Error: API key file not found: $API_KEY_PATH"
    exit 1
  fi
  export APP_STORE_CONNECT_API_KEY_PATH="$API_KEY_PATH"
fi

echo "Deploying to TestFlight..."
echo "  Group: $GROUP"
[[ -n "$CHANGELOG" ]] && echo "  Changelog: $CHANGELOG"
echo ""

bundle exec fastlane deploy_testflight
