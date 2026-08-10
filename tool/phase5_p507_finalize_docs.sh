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

mark_done "Product ID保存"
mark_done "重複防止"
mark_done "削除"
mark_done "P4-06表示領域へ実データ接続"
mark_done "未ログイン導線"

MARKER="## 2026-08-10 - Phase 5 P5-07 favorite_products / よく飲む商品"

if ! grep -Fq "$MARKER" "$CHANGELOG"; then
  TMP="$(mktemp)"

  {
    head -n 1 "$CHANGELOG"

    cat <<'CHANGELOG_EOF'

## 2026-08-10 - Phase 5 P5-07 favorite_products / よく飲む商品

- `users/{uid}/favorite_products/{productId}`をProduct ID正本として実装。
- Product ID=document IDにより重複を防止。
- MyPageから商品マスタ検索で追加・一覧・削除を実装。
- P4-06「よく飲む商品」表示領域へ実データを接続。
- guest時は架空商品を出さずログイン導線を表示。
- v1 `favoriteDrinkNames`は一意に解決できる名称だけfallback表示。
- legacy fallbackは初回mutation時にProduct IDへmaterializeし、`users/{uid}/migration_state/favorite_products`へmigration完了を記録。
- `firebase/v2/firestore.rules`へ本人限定`favorite_products` Rulesを追加。
- production `firestore.rules` / `firebase.json`は未変更。統合確認はP5-08。
CHANGELOG_EOF

    tail -n +2 "$CHANGELOG"
  } > "$TMP"

  mv "$TMP" "$CHANGELOG"
fi

echo "P5-07 documentation status updated."
