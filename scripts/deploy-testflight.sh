#!/usr/bin/env bash
#
# Build Sandbox or Production and optionally deploy it to TestFlight.
#
# Prerequisites:
#   - App Store Connect API Key (recommended): Create at App Store Connect > Users and Access > Keys
#   - Or Apple ID + App-specific password for legacy auth
#
# Usage:
#   ./scripts/deploy-testflight.sh --environment sandbox [options]
#
# Options:
#   --environment NAME      Required: sandbox or production
#   --build-number NUMBER   Override build number (for example, 2026.08.18.1)
#   --build-only            Archive and export without uploading
#   --group "Group Name"    External beta group (default: "Beta Testers")
#   --api-key-path PATH     App Store Connect API key (.json or .p8)
#   --changelog "Text"      TestFlight "What to Test" text
#   -h, --help              Show this help
#
# Environment variables:
#   APP_STORE_CONNECT_API_KEY_PATH  Path to API key JSON (alternative to --api-key-path)
#   APP_STORE_CONNECT_API_KEY_P8    Path to App Store Connect API .p8 file
#   APP_STORE_CONNECT_KEY_ID        App Store Connect API key id
#   APP_STORE_CONNECT_ISSUER_ID     App Store Connect API issuer id
#   HACKERS_ENVIRONMENT             sandbox or production
#   SKIP_TESTFLIGHT_UPLOAD          Set to 1 to build without uploading
#   EXTERNAL_GROUP                  External group name (alternative to --group)
#   EXTERNAL_TESTER_GROUP           External group name (local Apple keys alias)
#   CHANGELOG                       What to Test text (alternative to --changelog)
#   HACKERS_BUILD_NUMBER            Manual build number override
#   BUILD_NUMBER_CACHE              Local date/run cache (default: fastlane/.build-number-cache.json)
#   APPLE_KEYS_DIR                  Local Apple keys directory (default: ~/Developer/Keys/Apple)
#   APPLE_KEYS_ENV_FILE             Local Apple env file (default: $APPLE_KEYS_DIR/apple.txt)
#   XCODE_APP_PATH                  Xcode app path when xcode-select points at CommandLineTools
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GROUP="Beta Testers"
ENVIRONMENT="${HACKERS_ENVIRONMENT:-}"
API_KEY_PATH=""
CHANGELOG=""
BUILD_ONLY="${SKIP_TESTFLIGHT_UPLOAD:-0}"
BUILD_NUMBER="${HACKERS_BUILD_NUMBER:-}"
KEY_FILE="$PROJECT_ROOT/credentials/KEY_ISSUER_IDS.txt"
APPLE_KEYS_DIR="${APPLE_KEYS_DIR:-$HOME/Developer/Keys/Apple}"
APPLE_KEYS_ENV_FILE="${APPLE_KEYS_ENV_FILE:-$APPLE_KEYS_DIR/apple.txt}"
BUILD_NUMBER_CACHE="${BUILD_NUMBER_CACHE:-$PROJECT_ROOT/fastlane/.build-number-cache.json}"
export FASTLANE_SKIP_UPDATE_CHECK="${FASTLANE_SKIP_UPDATE_CHECK:-1}"

if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  XCODE_APP_PATH="${XCODE_APP_PATH:-}"
  if [[ -z "$XCODE_APP_PATH" && -d /Applications/Xcode.app ]]; then
    XCODE_APP_PATH=/Applications/Xcode.app
  elif [[ -z "$XCODE_APP_PATH" && -d /Applications/Xcode-beta.app ]]; then
    XCODE_APP_PATH=/Applications/Xcode-beta.app
  fi
  [[ -n "$XCODE_APP_PATH" ]] && export DEVELOPER_DIR="$XCODE_APP_PATH/Contents/Developer"
fi

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --build-number)
      BUILD_NUMBER="$2"
      shift 2
      ;;
    --build-only)
      BUILD_ONLY=1
      shift
      ;;
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

ENVIRONMENT="$(printf '%s' "$ENVIRONMENT" | tr '[:upper:]' '[:lower:]')"
if [[ "$ENVIRONMENT" != "sandbox" && "$ENVIRONMENT" != "production" ]]; then
  echo "Error: --environment must be sandbox or production."
  usage
fi
if [[ -n "$BUILD_NUMBER" && ! "$BUILD_NUMBER" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  echo "Error: --build-number must contain period-separated numbers."
  exit 1
fi

# Load local-only Apple deploy values when present. Keep this outside the repo.
if [[ -f "$APPLE_KEYS_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$APPLE_KEYS_ENV_FILE"
fi

# Resolve API key path
if [[ -z "$API_KEY_PATH" && -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]]; then
  API_KEY_PATH="$APP_STORE_CONNECT_API_KEY_PATH"
fi
if [[ -z "$API_KEY_PATH" && -n "${APP_STORE_CONNECT_API_KEY_P8:-}" ]]; then
  API_KEY_PATH="$APP_STORE_CONNECT_API_KEY_P8"
fi
if [[ -z "$API_KEY_PATH" && -d "$APPLE_KEYS_DIR" ]]; then
  shopt -s nullglob
  p8_files=("$APPLE_KEYS_DIR"/AuthKey_*.p8)
  if [[ ${#p8_files[@]} -eq 0 ]]; then
    p8_files=("$APPLE_KEYS_DIR"/*.p8)
  fi
  shopt -u nullglob
  if [[ ${#p8_files[@]} -eq 1 ]]; then
    API_KEY_PATH="${p8_files[0]}"
  fi
fi

cd "$PROJECT_ROOT"

# Check for fastlane via Bundler
if ! bundle exec fastlane --version &>/dev/null; then
  echo "Error: fastlane is not available in Bundler. Run: bundle install"
  exit 1
fi

if [[ "$GROUP" == "Beta Testers" && -n "${EXTERNAL_GROUP:-}" ]]; then
  GROUP="$EXTERNAL_GROUP"
elif [[ "$GROUP" == "Beta Testers" && -n "${EXTERNAL_TESTER_GROUP:-}" ]]; then
  GROUP="$EXTERNAL_TESTER_GROUP"
fi

export EXTERNAL_GROUP="$GROUP"
export HACKERS_ENVIRONMENT="$ENVIRONMENT"
export BUILD_NUMBER_CACHE
export SKIP_TESTFLIGHT_UPLOAD="$BUILD_ONLY"
[[ -n "$BUILD_NUMBER" ]] && export HACKERS_BUILD_NUMBER="$BUILD_NUMBER"
[[ -n "$CHANGELOG" ]] && export CHANGELOG

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
elif [[ "$API_KEY_PATH" =~ AuthKey_([A-Za-z0-9]+)\.p8$ ]]; then
  export APP_STORE_CONNECT_KEY_ID="${BASH_REMATCH[1]}"
fi

if [[ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
  export APP_STORE_CONNECT_ISSUER_ID
elif [[ -n "${ISSUER_ID:-}" ]]; then
  export APP_STORE_CONNECT_ISSUER_ID="$ISSUER_ID"
fi

echo "Building Hackers..."
echo "  Environment: $ENVIRONMENT"
[[ -n "$BUILD_NUMBER" ]] && echo "  Build number: $BUILD_NUMBER"
echo "  Group: $GROUP"
[[ "$BUILD_ONLY" == "1" ]] && echo "  Upload: skipped"
[[ -n "$CHANGELOG" ]] && echo "  Changelog: $CHANGELOG"
echo ""

bundle exec fastlane deploy_testflight
