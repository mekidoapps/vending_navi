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
  echo "Usage: bash tool/phase4_quality_gate.sh <projectId>"
  exit 1
fi

echo "Phase 4 quality gate"
echo "project=$PROJECT_ID"

echo "[1/7] Flutter analyze"
flutter analyze --no-fatal-infos --no-fatal-warnings

echo "[2/7] Flutter tests"
flutter test

echo "[3/7] Strict Phase 4 analyze"
dart analyze lib/features/product_master
dart analyze test/features/product_master
dart analyze lib/features/product_search
dart analyze test/features/product_search
dart analyze lib/features/home_map
dart analyze test/features/home_map
dart analyze lib/features/vending_machine
dart analyze test/features/vending_machine

echo "[4/7] Phase 4 responsive regression"
flutter test \
  test/features/home_map/presentation/v2_home_map_product_search_responsive_test.dart \
  test/features/vending_machine/presentation/v2_vending_machine_detail_search_responsive_test.dart

echo "[5/7] Functions build/test"
(
  cd functions
  npm run build
  npm test
)

echo "[6/7] machine_product_index Emulator integration"
bash tool/phase4_p403_emulator_gate.sh "$PROJECT_ID"

echo "[7/7] Production Firebase config guard"
if ! git diff --quiet -- firebase.json firestore.rules; then
  echo "Production Firebase config/rules have uncommitted changes."
  git diff -- firebase.json firestore.rules
  exit 1
fi

echo "Phase 4 quality gate passed."
