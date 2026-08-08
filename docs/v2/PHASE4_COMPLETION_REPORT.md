# Phase 4 完了レポート

> 完了判定日: 2026-08-09
> 対象: VendingNavi v2

## Phase 4で成立した主フロー

```text
探す
→ Product / Genreを選択
→ machine_product_index
→ 検索結果Marker
→ 固定カード
→ 自販機詳細
→ 検索対象を優先表示
```

## Product検索

Product masterを検索正本とする。

候補優先順位:

```text
1. Product ID完全一致
2. 商品名完全一致
3. keyword完全一致
4. 商品名前方一致
5. keyword前方一致
6. 商品名部分一致
7. keyword部分一致
```

表記揺れは`searchKeywords`で明示管理する。

AI推測や意味検索は行わない。

## Genre検索

固定`ProductGenre`を利用する。

```text
Genre
→ Product master
→ active Product ID群
→ machine_product_index
→ machine ID統合
```

同一machineに複数商品が一致した場合は、
Markerを1個へ縮約する。

代表evidenceは:

```text
confirmed > inferred
```

## 地図検索スコープ

Phase 4では現在viewportを利用する。

```text
Google Map visible region
→ geohash query
→ 最終coordinate filter
```

固定検索半径はまだ設定しない。

## v1互換

旧データはP2/P3でProduct IDへ解決できたものだけ検索対象へ合流する。

曖昧な旧文字列をP4で再推測しない。

## よく飲む商品

Phase 4ではUI接続口だけ作成した。

```text
List<Product> frequentProducts
```

初期値は空。

Phase 5の認証・ユーザーデータ実装後に正式接続する。

## 検索対象の優先表示

固定カード:

```text
検索商品 / 検索Genre
+ 確認済み / あるかも
```

詳細:

```text
検索一致商品
→ 非一致商品
```

Genre検索では一致商品群を上部へまとめる。

## Phase 5へ持ち越すもの

Phase 5は認証・ユーザー。

主対象:

```text
メール / Googleログイン
→ user作成
→ 中断フロー復帰
→ よく飲む商品の実データ接続
→ マイページ
```

Phase 4の検索UIを作り直さず、
既存`frequentProducts`接続口へユーザーデータを流す。

## 未確定事項

OI-003:

```text
固定検索半径 / 最大取得件数 / 範囲拡張UX
```

Phase 4ではviewport検索を正として仮値を置かない。

OI-004:

```text
「以前の情報」とする具体期間
```

Phase 8の更新データとクローズドテストを材料にする。

これらはPhase 5開始を妨げる未確定事項ではない。
