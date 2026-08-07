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
  echo "Usage: bash tool/phase3_quality_gate.sh <projectId>"
  exit 1
fi

echo "Phase 3 quality gate"
echo "project=$PROJECT_ID"

echo "[1/6] Flutter analyze"
flutter analyze --no-fatal-infos --no-fatal-warnings

echo "[2/6] Flutter tests"
flutter test

echo "[3/6] Strict v2 analyze"
dart analyze lib/features/location
dart analyze test/features/location
dart analyze lib/features/home_map
dart analyze test/features/home_map
dart analyze lib/features/vending_machine
dart analyze test/features/vending_machine
dart analyze lib/app/router
dart analyze test/app/router

echo "[4/6] Functions build/test"
(
  cd functions
  npm run build
  npm test
)

echo "[5/6] Firestore Emulator integration"
bash tool/phase3_p302_emulator_gate.sh "$PROJECT_ID"

echo "[6/6] Production config guard"
if ! git diff --quiet -- firebase.json firestore.rules; then
  echo "Production Firebase config/rules have uncommitted changes."
  git diff -- firebase.json firestore.rules
  exit 1
fi

echo "Phase 3 quality gate passed."
