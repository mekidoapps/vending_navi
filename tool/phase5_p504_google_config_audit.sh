#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "P5-04 Google Sign-In configuration audit"

echo
echo "[dependency]"
grep -nE '^[[:space:]]*google_sign_in:' pubspec.yaml

echo
echo "[Firebase platform files - contents are NOT printed]"
for path in \
  android/app/google-services.json \
  ios/Runner/GoogleService-Info.plist
do
  if [[ -f "$path" ]]; then
    echo "PRESENT $path"
  else
    echo "MISSING $path"
    exit 1
  fi
done

echo
echo "[Android Google Services plugin]"
grep -RniE \
  --include='*.gradle' \
  --include='*.gradle.kts' \
  'com\.google\.gms\.google-services|google-services' \
  android/app android/settings.gradle.kts

echo
echo "[Android signing report]"
(
  cd android
  ./gradlew signingReport
)

echo
echo "Local Google configuration audit completed."
echo "Firebase Console still must be checked for:"
echo "  - Authentication > Sign-in method > Google enabled"
echo "  - debug SHA-1 registered for the Android app"
