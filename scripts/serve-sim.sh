#!/usr/bin/env bash
set -euo pipefail

DEVICE="${HACKERS_SIM_DEVICE:-iPhone 17}"
PORT="${SERVE_SIM_PORT:-3200}"

npx --yes serve-sim@0.1.18 "$DEVICE" --port "$PORT"
