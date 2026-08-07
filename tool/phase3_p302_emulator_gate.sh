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
  echo "Usage: bash tool/phase3_p302_emulator_gate.sh <projectId>"
  exit 1
fi

export GCLOUD_PROJECT="$PROJECT_ID"

echo "P3-02 emulator gate"
echo "project=$PROJECT_ID"

firebase emulators:exec \
  --project "$PROJECT_ID" \
  --config firebase.v2.json \
  --only firestore \
  "cd functions && npm run build && node lib/scripts/seed_master_fixture.js && node lib/scripts/seed_vending_machine_fixture.js && node lib/scripts/verify_vending_machine_rules.js"

echo "P3-02 emulator gate passed."
