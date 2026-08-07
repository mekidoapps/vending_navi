# P4-02 HomeMap 商品検索パネルUI

> 更新日: 2026-08-07
> 対象: VendingNavi v2 Phase 4

## 1. 目的

HomeMapの主操作「探す」を、
Product masterの商品候補選択へ接続する。

P4-02で成立させる流れ:

```text
HomeMap
→ 探す
→ 検索パネル
→ 商品名入力
→ Product候補
→ 商品選択
→ パネルを閉じる
→ 選択商品ラベルを地図上に残す
```

この時点では自販機Markerをまだ絞らない。

## 2. 検索パネル

右下の「探す」の左側に展開する。

通常端末では最大幅360px。
小型端末では画面幅に合わせて縮める。

Google Mapの上にFlutter widgetとして表示し、
Map自体は破棄しない。

表示:

```text
商品を探す
[ 商品名を入力 ]

候補
- Product
- Product
- Product
```

候補はP4-01のProductSearchControllerを利用する。

## 3. 入力

入力変更から250ms後に候補検索する。

目的:

- 1文字入力ごとの過剰readを抑える
- 入力途中の表示揺れを減らす

キーボードの検索操作ではdebounceを待たず即時検索する。

空欄ではP4-01の仕様どおりProduct Repositoryを読まない。

## 4. 候補

最大8件をUIに表示する。

候補順はP4-01のscore順をそのまま使い、
UI側で並べ替えない。

商品名とGenreを表示する。

Manufacturer表示はP4-02では追加しない。
候補1行ごとにManufacturer masterを追加readしないため。

## 5. 商品選択

選択時:

```text
Product
→ ProductSearchSelectionController
→ 検索パネルを閉じる
→ 検索候補stateをclear
```

選択Product自体は保持する。

P4-03/P4-04がこの選択Product IDを利用して
`machine_product_index`検索とMarker filteringを行う。

## 6. 選択商品ラベル

検索パネルを閉じた後も地図上に小ラベルを残す。

表示:

```text
🔍 綾鷹 ×
```

×で商品検索条件を解除する。

P4-02では条件解除してもMarkerはまだ変化しない。
Marker filteringはP4-04。

位置情報のエラー／許可案内が表示されている間は
重なりを避けるためラベル表示だけ一時的に隠す。
選択state自体は消さない。

## 7. 「よく飲む商品」

P4-02ではまだ表示しない。

ユーザー固有データを仮値で作らず、
P4-06で正式な表示領域を追加する。

## 8. まだ実装しないもの

- `machine_product_index`
- 自販機Marker filtering
- Genre検索
- よく飲む商品
- 検索半径
- 0件時の範囲拡張
- 情報古さ判定
- 気分検索
