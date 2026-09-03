#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'Firebase release config verification failed: %s\n' "$1" >&2
  exit 1
}

required_files=(
  ".firebaserc"
  "firebase.json"
  "firebase/v2/firestore.rules"
  "firebase/v2/firestore.indexes.json"
  "firebase/v2/storage.rules"
  "functions/package.json"
  "functions/package-lock.json"
  "functions/src/index.ts"
)

for file in "${required_files[@]}"; do
  [[ -f "$file" ]] || fail "missing $file"
done

obsolete_files=(
  "firebase.v2.json"
  "firebase.v2.production.json"
  "firestore.rules"
  "firebase/v2/storage.emulator.rules"
)

for file in "${obsolete_files[@]}"; do
  [[ ! -e "$file" ]] || fail "obsolete deploy source still exists: $file"
done

node <<'NODE'
const fs = require("node:fs");

const firebase = JSON.parse(fs.readFileSync("firebase.json", "utf8"));
const projects = JSON.parse(fs.readFileSync(".firebaserc", "utf8"));

const errors = [];
if (projects?.projects?.default !== "vendingnavi") {
  errors.push(".firebaserc default project must be vendingnavi");
}
if (firebase?.firestore?.rules !== "firebase/v2/firestore.rules") {
  errors.push("firebase.json must use the v2 Firestore rules");
}
if (firebase?.firestore?.indexes !== "firebase/v2/firestore.indexes.json") {
  errors.push("firebase.json must use the v2 Firestore indexes");
}
if (firebase?.storage?.rules !== "firebase/v2/storage.rules") {
  errors.push("firebase.json must use the production Storage rules");
}
if (!Array.isArray(firebase?.functions) || firebase.functions.length !== 1) {
  errors.push("firebase.json must define exactly one Functions codebase");
} else {
  const codebase = firebase.functions[0];
  if (codebase.source !== "functions" || codebase.codebase !== "v2") {
    errors.push("firebase.json Functions source/codebase must be functions/v2");
  }
}

if (errors.length > 0) {
  for (const error of errors) console.error(error);
  process.exit(1);
}
NODE

expected_exports=(
  "createVendingMachine"
  "recognizeVendingMachinePhoto"
  "updateVendingMachineProducts"
  "addVendingMachinePhoto"
  "submitMachineCorrection"
  "submitMachineReport"
  "deleteAccount"
)

for function_name in "${expected_exports[@]}"; do
  grep -Eq "export const ${function_name}[[:space:]]*=" functions/src/index.ts \
    || fail "missing Callable export: $function_name"
done

printf 'Firebase release config verification passed for project vendingnavi.\n'
