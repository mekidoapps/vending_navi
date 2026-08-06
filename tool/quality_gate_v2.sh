#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

step() {
  printf '\n==> %s\n' "$1"
}

step "Phase 1 required files"
required_files=(
  "lib/app/bootstrap/app_bootstrap.dart"
  "lib/app/router/app_router.dart"
  "lib/app/theme/v2_theme.dart"
  "lib/core/errors/app_failure.dart"
  "lib/core/result/app_result.dart"
  "lib/core/logging/app_logger.dart"
  "lib/core/firebase/firebase_emulator_connector.dart"
  "lib/features/foundation/presentation/v2_foundation_screen.dart"
  "firebase.v2.json"
  "firebase/v2/firestore.rules"
  "firebase/v2/storage.rules"
  "functions/package.json"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    printf 'Missing required file: %s\n' "$file" >&2
    exit 1
  fi
done

step "Deny-by-default rules"
grep -Eq 'allow[[:space:]]+read,[[:space:]]*write:[[:space:]]*if[[:space:]]+false;' \
  firebase/v2/firestore.rules
grep -Eq 'allow[[:space:]]+read,[[:space:]]*write:[[:space:]]*if[[:space:]]+false;' \
  firebase/v2/storage.rules

step "Flutter dependencies"
flutter pub get

step "Generated code"
# build_runner 2.15.xでは競合削除オプションを使わず、通常buildを実行する。
dart run build_runner build

step "Whole-project analyzer (legacy warnings are reported but non-fatal)"
flutter analyze --no-fatal-infos --no-fatal-warnings

step "Strict analyzer for Phase 1 v2 scope"
strict_targets=(
  "lib/app"
  "lib/core"
  "lib/features/foundation"
  "test/app"
  "test/core"
  "test/features/foundation"
  "test/widget_test.dart"
)

for target in "${strict_targets[@]}"; do
  if [[ -e "$target" ]]; then
    printf '\n-- dart analyze %s\n' "$target"
    dart analyze "$target"
  fi
done

step "Flutter tests"
flutter test

if [[ -f functions/package-lock.json ]]; then
  step "Functions install/build/test"
  (
    cd functions
    npm ci
    npm run build
    npm test
  )
else
  printf '\n[skip] functions/package-lock.json is missing; Functions gate was not run.\n'
fi

step "Production Firebase configuration safety"
if ! git diff --quiet -- firebase.json firestore.rules; then
  printf 'firebase.json or root firestore.rules has an uncommitted change. Review before continuing.\n' >&2
  git diff -- firebase.json firestore.rules
  exit 1
fi

printf '\nPhase 1 quality gate passed.\n'
