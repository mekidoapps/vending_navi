#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'Production deploy blocked: %s\n' "$1" >&2
  exit 1
}

if [[ $# -ne 1 ]]; then
  fail "pass one explicit --only scope (for example: functions:v2)"
fi

deploy_scope="$1"
IFS=',' read -r -a requested_targets <<< "$deploy_scope"
allowed_targets=(
  "functions:v2"
  "firestore:rules"
  "firestore:indexes"
  "storage"
)

for requested_target in "${requested_targets[@]}"; do
  allowed=false
  for allowed_target in "${allowed_targets[@]}"; do
    if [[ "$requested_target" == "$allowed_target" ]]; then
      allowed=true
      break
    fi
  done
  [[ "$allowed" == true ]] || fail "unsupported deploy target: $requested_target"
done

command -v firebase >/dev/null 2>&1 || fail "Firebase CLI is not installed"
[[ -z "$(git status --short)" ]] || fail "git working tree must be clean"

current_sha="$(git rev-parse HEAD)"
[[ "${VENDING_NAVI_RELEASE_SHA:-}" == "$current_sha" ]] \
  || fail "VENDING_NAVI_RELEASE_SHA must equal current HEAD ($current_sha)"
[[ "${VENDING_NAVI_DEPLOY_PROJECT:-}" == "vendingnavi" ]] \
  || fail "VENDING_NAVI_DEPLOY_PROJECT must be vendingnavi"

tool/verify_firebase_release_config.sh

printf 'Deploying %s from %s to Firebase project vendingnavi.\n' \
  "$deploy_scope" "$current_sha"
firebase deploy \
  --config firebase.json \
  --project vendingnavi \
  --only "$deploy_scope"
