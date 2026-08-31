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
  echo "Usage: bash tool/phase4_p403_emulator_gate.sh <projectId>"
  exit 1
fi

export GCLOUD_PROJECT="$PROJECT_ID"

echo "P4-03 emulator gate"
echo "project=$PROJECT_ID"

firebase emulators:exec \
  --project "$PROJECT_ID" \
  --config firebase.json \
  --only firestore \
  "cd functions && npm run build && node lib/scripts/seed_master_fixture.js && node lib/scripts/seed_vending_machine_fixture.js && node lib/scripts/seed_machine_product_index_fixture.js && node lib/scripts/verify_vending_machine_rules.js && node lib/scripts/verify_machine_product_index_rules.js"

echo "P4-03 emulator gate passed."
