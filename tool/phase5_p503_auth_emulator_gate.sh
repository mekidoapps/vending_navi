#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT_ID="${1:-vendingnavi}"

firebase emulators:exec \
  --project "$PROJECT_ID" \
  --config firebase.v2.json \
  --only auth \
  "bash tool/phase5_p503_auth_emulator_checks.sh '$PROJECT_ID'"
