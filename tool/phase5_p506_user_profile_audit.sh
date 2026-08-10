#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

OUT="${1:-phase5_p506_user_profile_audit_output.txt}"
: > "$OUT"

section() {
  printf "\n===== %s =====\n" "$1" | tee -a "$OUT"
}

run_safe() {
  "$@" 2>&1 | tee -a "$OUT" || true
}

print_file_if_present() {
  local path="$1"
  if [[ -f "$path" ]]; then
    echo "----- $path -----" | tee -a "$OUT"
    sed -n '1,260p' "$path" | tee -a "$OUT"
  else
    echo "MISSING $path" | tee -a "$OUT"
  fi
}

section "Repository"
run_safe git branch --show-current
run_safe git rev-parse --short HEAD
run_safe git status --short

section "P5-06 relevant source files"
find lib test \
  -type f \
  \( -name '*.dart' -o -name '*.rules' \) \
  \( \
    -iname '*user*' -o \
    -iname '*profile*' -o \
    -iname '*my_page*' -o \
    -iname '*auth*' -o \
    -iname '*router*' \
  \) \
  -print | sort | tee -a "$OUT" || true

section "users/{uid} reads/writes with field names"
grep -RniE \
  --exclude-dir=node_modules \
  --include='*.dart' \
  --include='*.rules' \
  --include='*.js' \
  --include='*.ts' \
  "collection\(['\"]users['\"]\)|users/\{uid\}|defaultDistanceMeters|displayName|favoriteDrinkNames|notification|registeredMachineCount|registeredDrinkCount|createdAt|updatedAt" \
  lib test functions firebase firestore.rules 2>/dev/null \
  | tee -a "$OUT" || true

section "v1 MyPage state and Firestore operations"
grep -nE \
  "FirebaseAuth|FirebaseFirestore|collection\('users'\)|displayName|defaultDistanceMeters|signOut|ログアウト|ログイン中|ゲスト利用中|favorite|notification|progress" \
  lib/screens/my_page_screen.dart 2>/dev/null \
  | tee -a "$OUT" || true

section "v1 user services"
for path in \
  lib/services/user_progress_service.dart \
  lib/services/favorite_drink_service.dart \
  lib/services/auth_service.dart
do
  print_file_if_present "$path"
done

section "v2 Auth domain/repository/provider"
for path in \
  lib/features/auth/domain/entities/auth_user.dart \
  lib/features/auth/domain/entities/auth_session.dart \
  lib/features/auth/domain/repositories/auth_repository.dart \
  lib/features/auth/application/providers/auth_providers.dart \
  lib/features/auth/data/repositories/auth_repository_impl.dart
do
  print_file_if_present "$path"
done

section "v2 Router / HomeMap profile hook"
for path in \
  lib/app/router/app_route.dart \
  lib/app/router/app_router.dart
do
  print_file_if_present "$path"
done

grep -nE \
  "onProfilePressed|profileMapAction|myPage|my_page|マイ|_handleRegisterPressed|V2HomeMapScreen" \
  lib/features/home_map/presentation/v2_home_map_screen.dart 2>/dev/null \
  | tee -a "$OUT" || true

section "Firestore rules: auth/users/favorite references"
grep -RniE \
  --exclude-dir=node_modules \
  "match /users|request\.auth|favorite_products|favoriteDrinkNames|allow (read|write|create|update|delete)" \
  firestore.rules firebase/v2 2>/dev/null \
  | tee -a "$OUT" || true

section "User/MyPage/Auth tests"
find test -type f -name '*.dart' \
  | grep -Ei 'user|profile|my_page|auth|home_map' \
  | sort \
  | tee -a "$OUT" || true

section "Production files tracked state"
run_safe git diff -- firestore.rules firebase.json firebase/v2 functions pubspec.yaml

section "Audit complete"
echo "Output: $OUT" | tee -a "$OUT"
echo "This audit does not print Firebase configuration files, API keys, OAuth secrets, or keystores." | tee -a "$OUT"
