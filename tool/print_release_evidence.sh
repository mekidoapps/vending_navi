#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -n "$(git status --short)" ]]; then
  printf 'Release evidence requires a clean working tree.\n' >&2
  exit 1
fi

aab_path="${1:-}"
if [[ -n "$aab_path" && ! -f "$aab_path" ]]; then
  printf 'AAB not found: %s\n' "$aab_path" >&2
  exit 1
fi

tool/verify_firebase_release_config.sh

printf 'git_branch=%s\n' "$(git branch --show-current)"
printf 'git_sha=%s\n' "$(git rev-parse HEAD)"
printf 'app_version=%s\n' "$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml)"
printf 'build_timestamp_utc=%s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
printf 'java_version=%s\n' "$(java -version 2>&1 | head -n 1)"
printf 'node_version=%s\n' "$(node --version)"

if command -v flutter >/dev/null 2>&1; then
  printf 'flutter_version=%s\n' "$(flutter --version --machine | node -e '
    let input = "";
    process.stdin.on("data", chunk => input += chunk);
    process.stdin.on("end", () => {
      const value = JSON.parse(input);
      process.stdout.write(value.frameworkVersion ?? "unknown");
    });
  ')"
else
  printf 'flutter_version=unavailable\n'
fi

if command -v dart >/dev/null 2>&1; then
  printf 'dart_version=%s\n' "$(dart --version 2>&1)"
else
  printf 'dart_version=unavailable\n'
fi

if command -v firebase >/dev/null 2>&1; then
  printf 'firebase_cli_version=%s\n' "$(firebase --version)"
else
  printf 'firebase_cli_version=unavailable\n'
fi

sha256sum \
  pubspec.lock \
  functions/package-lock.json \
  firebase/v2/firestore.rules \
  firebase/v2/storage.rules \
  functions/fixtures/master_fixture.json

find functions/src -type f -name '*.ts' -print0 \
  | sort -z \
  | xargs -0 sha256sum \
  | sha256sum \
  | sed 's/[[:space:]]*-[[:space:]]*$/  functions_source_set/'

if [[ -n "$aab_path" ]]; then
  sha256sum "$aab_path"
else
  printf 'aab_sha256=unavailable\n'
fi
