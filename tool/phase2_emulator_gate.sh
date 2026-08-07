#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT_ID="${1:-}"

if [[ -z "$PROJECT_ID" && -f ".firebaserc" ]]; then
  PROJECT_ID="$(
    node -e '
      const fs = require("fs");
      const value = JSON.parse(fs.readFileSync(".firebaserc", "utf8"))
        ?.projects?.default;
      if (typeof value === "string") process.stdout.write(value);
    '
  )"
fi

if [[ -z "$PROJECT_ID" ]]; then
  echo "Firebase project ID could not be resolved."
  echo "Usage: bash tool/phase2_emulator_gate.sh <projectId>"
  exit 1
fi

export GCLOUD_PROJECT="$PROJECT_ID"

echo "Phase 2 emulator gate"
echo "project=$PROJECT_ID"

firebase emulators:exec \
  --project "$PROJECT_ID" \
  --config firebase.v2.json \
  --only firestore \
  "cd functions && npm run seed:master && npm run verify:master"

echo "Phase 2 emulator gate passed."
