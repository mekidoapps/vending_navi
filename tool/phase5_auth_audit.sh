#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

OUT="${1:-phase5_auth_audit_output.txt}"
: > "$OUT"

section() {
  printf "\n===== %s =====\n" "$1" | tee -a "$OUT"
}

run_safe() {
  "$@" 2>&1 | tee -a "$OUT" || true
}

section "Repository"
run_safe git branch --show-current
run_safe git rev-parse --short HEAD
run_safe git status --short

section "Relevant pubspec dependencies"
grep -nEi \
  'firebase_auth|google_sign_in|sign_in_with_apple|firebase_core|cloud_firestore|cloud_functions|firebase_app_check|shared_preferences' \
  pubspec.yaml | tee -a "$OUT" || true

section "Auth/User/Favorite source files"
find lib test \
  -type f \
  \( -name '*.dart' -o -name '*.yaml' \) \
  \( \
    -iname '*auth*' -o \
    -iname '*login*' -o \
    -iname '*sign_in*' -o \
    -iname '*user*' -o \
    -iname '*profile*' -o \
    -iname '*favorite*' -o \
    -iname '*my_page*' \
  \) \
  -print \
  | sort \
  | tee -a "$OUT" || true

section "FirebaseAuth API references"
grep -RniE \
  --include='*.dart' \
  --exclude='firebase_options.dart' \
  'FirebaseAuth|authStateChanges|userChanges|idTokenChanges|currentUser|signInWithEmailAndPassword|createUserWithEmailAndPassword|sendPasswordResetEmail|signOut\(|UserCredential' \
  lib test \
  | tee -a "$OUT" || true

section "Google sign-in references"
grep -RniE \
  --include='*.dart' \
  'GoogleSignIn|GoogleAuthProvider|signInWithCredential|google_sign_in|googleSignIn' \
  lib test \
  | tee -a "$OUT" || true

section "Auth presentation/routes"
grep -RniE \
  --include='*.dart' \
  'login|sign.?in|register|create.?account|auth required|ログイン|新規登録|アカウント' \
  lib/app lib/features lib/screens test \
  | tee -a "$OUT" || true

section "User document references"
grep -RniE \
  --exclude-dir=node_modules \
  --include='*.dart' \
  --include='*.rules' \
  --include='*.ts' \
  --include='*.js' \
  "collection\(['\"]users['\"]\)|/users/|users/\{uid\}|document\(['\"]users" \
  lib functions firebase 2>/dev/null \
  | tee -a "$OUT" || true

section "Favorite/frequent product references"
grep -RniE \
  --exclude-dir=node_modules \
  --include='*.dart' \
  --include='*.rules' \
  --include='*.ts' \
  --include='*.js' \
  'favorite_products|favoriteProducts|favorites|favorite_drinks|frequentProducts|よく飲む' \
  lib test functions firebase 2>/dev/null \
  | tee -a "$OUT" || true

section "SharedPreferences auth-like references"
grep -RniE \
  --include='*.dart' \
  'SharedPreferences|isLoggedIn|loggedIn|loginState|userId|uid' \
  lib \
  | tee -a "$OUT" || true

section "Firestore rules auth/user references"
grep -RniE \
  'request\.auth|users|favorite' \
  firebase/v2 2>/dev/null \
  | tee -a "$OUT" || true

section "Platform configuration existence (contents are NOT printed)"
for path in \
  android/app/google-services.json \
  ios/Runner/GoogleService-Info.plist
do
  if [[ -f "$path" ]]; then
    echo "PRESENT $path" | tee -a "$OUT"
  else
    echo "MISSING $path" | tee -a "$OUT"
  fi
done

section "Google services Gradle references"
grep -RniE \
  --include='*.gradle' \
  --include='*.gradle.kts' \
  'google-services|com\.google\.gms\.google-services' \
  android \
  | tee -a "$OUT" || true

section "Auth-related tests"
find test \
  -type f \
  -name '*.dart' \
  | grep -Ei 'auth|login|user|favorite|profile|my_page' \
  | sort \
  | tee -a "$OUT" || true

section "Potential v1 files worth manual review"
for path in \
  lib/screens/login_screen.dart \
  lib/screens/register_screen.dart \
  lib/screens/my_page_screen.dart \
  lib/screens/favorite_drinks_screen.dart \
  lib/services/auth_service.dart \
  lib/services/firestore_service.dart \
  lib/screens/main_shell_screen.dart
do
  if [[ -f "$path" ]]; then
    echo "PRESENT $path" | tee -a "$OUT"
  fi
done

section "Audit complete"
echo "Output: $OUT" | tee -a "$OUT"
echo "Do not paste secrets or Firebase config contents."
