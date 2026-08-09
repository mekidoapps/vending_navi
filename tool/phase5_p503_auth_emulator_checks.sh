#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${1:-vendingnavi}"
AUTH_HOST="${FIREBASE_AUTH_EMULATOR_HOST:-127.0.0.1:9099}"
BASE="http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts"
API_KEY="p503-emulator-key"
EMAIL="p503_$(date +%s)_${RANDOM}@example.com"
PASSWORD="P503test123"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

post_json() {
  local url="$1"
  local body="$2"
  local output="$3"

  curl \
    --silent \
    --show-error \
    --fail-with-body \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$body" \
    "$url" \
    > "$output"
}

echo "Auth Emulator: ${AUTH_HOST}"
echo "Project: ${PROJECT_ID}"

post_json \
  "${BASE}:signUp?key=${API_KEY}" \
  "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\",\"returnSecureToken\":true}" \
  "${TMP_DIR}/signup.json"

node -e '
  const fs = require("fs");
  const data = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  if (!data.localId || !data.idToken) {
    throw new Error("signUp response did not contain localId/idToken");
  }
' "${TMP_DIR}/signup.json"

echo "PASS email register"

post_json \
  "${BASE}:signInWithPassword?key=${API_KEY}" \
  "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\",\"returnSecureToken\":true}" \
  "${TMP_DIR}/signin.json"

node -e '
  const fs = require("fs");
  const data = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  if (!data.localId || !data.idToken) {
    throw new Error("signIn response did not contain localId/idToken");
  }
' "${TMP_DIR}/signin.json"

echo "PASS email sign-in"

post_json \
  "${BASE}:sendOobCode?key=${API_KEY}" \
  "{\"requestType\":\"PASSWORD_RESET\",\"email\":\"${EMAIL}\"}" \
  "${TMP_DIR}/reset.json"

node -e '
  const fs = require("fs");
  const data = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  if (data.email && data.email !== process.argv[2]) {
    throw new Error("password reset response email mismatch");
  }
' "${TMP_DIR}/reset.json" "${EMAIL}"

echo "PASS password reset request"
echo "P5-03 Auth Emulator checks passed."
