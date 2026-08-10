#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PLAN="docs/v2/PHASE5_AUTH_USER_PLAN_V2.md"
CHANGELOG="docs/v2/CHANGELOG_V2.md"

mark_done() {
  local text="$1"
  local tmp
  tmp="$(mktemp)"

  awk \
    -v target="- [ ] $text" \
    -v replacement="- [x] $text" \
    '
      $0 == target {
        print replacement
        next
      }
      {
        print
      }
    ' "$PLAN" > "$tmp"

  mv "$tmp" "$PLAN"
}

mark_done "実Auth Emulator email test（P5-03で実施）"
mark_done "Android実機acceptance（P5-05接続直後）"

mark_done "認証必須Action abstraction"
mark_done "HomeMap登録"
mark_done "ログイン後復帰"
mark_done "二重実行防止"
mark_done "back/cancel"

mark_done "users schema互換"
mark_done "profile read"
mark_done "displayName"
mark_done "ログイン状態表示"
mark_done "logout"

MARKER="## 2026-08-09 - Phase 5 P5-06 users / v2マイページ基礎"

if ! grep -Fq "$MARKER" "$CHANGELOG"; then
  TMP="$(mktemp)"

  {
    head -n 1 "$CHANGELOG"

    cat <<'CHANGELOG_EOF'

## 2026-08-09 - Phase 5 P5-06 users / v2マイページ基礎

- `users/{uid}`を置換せず、v1 legacy fieldsを保持するprofile bridgeを追加。
- `appDisplayName → displayName → Firebase Auth`の表示名fallbackを実装。
- 未作成user documentはMyPage初回表示時に最小schemaで作成。
- v2 MyPageにゲスト表示、ログイン導線、ユーザー情報、表示名変更、ログアウトを追加。
- HomeMap「マイ」を`/v2/my`へ接続。
- private user profileは本人document・表示名field限定でdirect Firestore writeを採用。
- `firebase/v2/firestore.rules`へ本人profile Rulesを追加。
- production `firestore.rules` / `firebase.json`は未変更。統合はP5-08で実施。
- `favorite_products`実装はP5-07へ継続。
CHANGELOG_EOF

    tail -n +2 "$CHANGELOG"
  } > "$TMP"

  mv "$TMP" "$CHANGELOG"
fi

echo "P5-05/P5-06 documentation status updated."
