# Phase 3 完了レポート

> 完了予定日: 2026-08-07
> 対象: VendingNavi v2

## Phase 3で完成した閲覧フロー

```text
APP_ENTRY=v2
→ 全面HomeMap
→ 現在地取得
→ viewport自販機取得
→ 状態Marker
→ Marker選択
→ 固定情報カード
→ 自販機詳細
→ 外部徒歩経路
```

## データ読取

### v2

```text
vending_machines/{machineId}
vending_machines/{machineId}/products/{productId}
```

rootはgeohashでviewport候補を絞る。

### v1

geohashを持たないため、移行期間のみ互換読取を残す。

旧データ全件互換経路は恒久仕様ではない。

## UI

HomeMap:

- 全面Google Map
- 小型アプリラベル
- 現在地
- 探す
- 登録
- マイ
- 位置状態案内
- 自販機読込状態
- 自販機Marker
- 固定選択カード

詳細:

- 自販機名
- メーカー
- 場所
- 位置
- 商品
- 確認済み / あるかも
- 販売中 / 売切 / 在庫不明
- 外部徒歩経路

## Phase 4へ持ち越すもの

Phase 4は商品検索。

主対象:

```text
探すボタン
→ 左へ検索パネル
→ 商品名 / Product ID / genre
→ よく飲む商品
→ machine_product_index
→ 検索結果Marker
```

Phase 4で決めるもの:

- OI-003 検索半径・最大取得件数
- OI-004 情報古さの具体期間
- 商品検索時のconfirmed / inferred優先順位
- 0件時の検索範囲拡張UX

Phase 3ではこれらを先取りしない。
