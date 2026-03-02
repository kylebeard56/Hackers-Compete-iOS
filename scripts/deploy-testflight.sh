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
#   --api-key-path PATH     Path to App Store Connect API key (.json or .p8)
#   --changelog "Text"      "What to Test" text for TestFlight
#   --profile "Name"       App Store provisioning profile (if "No profiles" export error)
#   -h, --help              Show this help
#
# Environment variables:
#   APP_STORE_CONNECT_API_KEY_PATH  Path to API key JSON (alternative to --api-key-path)
#   APP_STORE_CONNECT_API_KEY_P8    Path to App Store Connect API .p8 file
#   APP_STORE_CONNECT_KEY_ID        App Store Connect API key id
#   APP_STORE_CONNECT_ISSUER_ID     App Store Connect API issuer id
#   EXTERNAL_GROUP                  External group name (alternative to --group)
#   CHANGELOG                       What to Test text (alternative to --changelog)
#   EXPORT_PROVISIONING_PROFILE_NAME App Store profile name (if export fails)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GROUP="Beta Testers"
API_KEY_PATH=""
CHANGELOG=""
PROFILE=""
KEY_FILE="$PROJECT_ROOT/credentials/KEY_ISSUER_IDS.txt"

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
    --profile)
      PROFILE="$2"
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
if [[ -z "$API_KEY_PATH" && -n "${APP_STORE_CONNECT_API_KEY_P8:-}" ]]; then
  API_KEY_PATH="$APP_STORE_CONNECT_API_KEY_P8"
fi

cd "$PROJECT_ROOT"

# Check for fastlane via Bundler
if ! bundle exec fastlane --version &>/dev/null; then
  echo "Error: fastlane is not available in Bundler. Run: bundle install"
  exit 1
fi

export EXTERNAL_GROUP="$GROUP"
[[ -n "$CHANGELOG" ]] && export CHANGELOG
[[ -n "$PROFILE" ]] && export EXPORT_PROVISIONING_PROFILE_NAME="$PROFILE"

if [[ -n "$API_KEY_PATH" ]]; then
  if [[ ! -f "$API_KEY_PATH" ]]; then
    echo "Error: API key file not found: $API_KEY_PATH"
    exit 1
  fi
  export APP_STORE_CONNECT_API_KEY_PATH="$API_KEY_PATH"
fi

# If no ids are exported yet, load KEY_ID / ISSUER_ID from credentials file when present.
if [[ -f "$KEY_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$KEY_FILE"
fi

if [[ -n "${APP_STORE_CONNECT_KEY_ID:-}" ]]; then
  export APP_STORE_CONNECT_KEY_ID
elif [[ -n "${KEY_ID:-}" ]]; then
  export APP_STORE_CONNECT_KEY_ID="$KEY_ID"
fi

if [[ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
  export APP_STORE_CONNECT_ISSUER_ID
elif [[ -n "${ISSUER_ID:-}" ]]; then
  export APP_STORE_CONNECT_ISSUER_ID="$ISSUER_ID"
fi

echo "Deploying to TestFlight..."
echo "  Group: $GROUP"
[[ -n "$CHANGELOG" ]] && echo "  Changelog: $CHANGELOG"
echo ""

bundle exec fastlane deploy_testflight
