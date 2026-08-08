# P4-05 ジャンル検索

> 更新日: 2026-08-09
> 対象: VendingNavi v2 Phase 4

## 1. 目的

商品名が分からない場合でも、

```text
お茶
緑茶
コーヒー
水
炭酸飲料
ジュース
スポーツドリンク
エナジードリンク
その他
```

から、そのジャンルの商品を持つ自販機を探せるようにする。

既存のProduct検索は維持する。

## 2. 検索パネル

商品名入力欄の下に横スクロールのジャンル候補を追加する。

固定GenreはProduct masterで定義済みの9種をそのまま利用し、
別の文字列マスタを重複定義しない。

## 3. 検索方式

Genre自体をProduct IDとして扱わない。

```text
ProductGenre
→ Product master
→ そのGenreを持つactive Product ID群
→ 各Product IDでmachine_product_index検索
→ machineIdを統合
```

P4-03の既存Product index read経路を再利用する。

## 4. 重複

同じ自販機に同ジャンルの商品が複数ある場合、
Markerは1個だけにする。

代表evidenceは、

```text
confirmed > inferred
```

とする。

これはMarker状態のための縮約であり、
正本の商品データを消すものではない。

## 5. legacy互換

schemaVersion=1はindexを持たない。

P2/P3でProduct IDへ解決済みのactive productsについて、

```text
Genreに属するProduct ID集合
∩ legacy activeProducts
```

で検索結果へ合流する。

旧商品名文字列からの再推測はしない。

## 6. Product検索との排他

Product検索とGenre検索は同時に有効にしない。

Product選択:

```text
Genre selection clear
→ Product selection set
```

Genre選択:

```text
Product selection clear
→ Genre selection set
```

検索解除すると通常HomeMapへ即時復帰する。

## 7. 地図範囲

P4-05でもGoogle Mapのvisible regionを検索範囲として使う。

固定距離はまだ決めない。
OI-003は未確定のまま維持する。

## 8. 0件・Failure

0件:

```text
この範囲では「コーヒー」が見つかりませんでした
```

通常自販機読込FailureとGenre検索Failureは区別する。

Genreに属する複数Product IDのうち一部だけindex取得に失敗した場合、
不完全な結果を成功として表示しない。

## 9. read数

初期Product masterは小規模なため、
P4-05ではGenre所属Product IDごとに
既存index queryを再利用する。

Product masterが大幅に増えた場合は、
実測後にwhereIn batchやGenre専用派生index等を検討する。

MVP段階で別indexを先に増やさない。

## 10. OI-004

売切・情報古さの具体期間はP4-05でも決めない。

`soldOut`をGenre検索結果から機械的に除外する処理は追加しない。

## 11. P4-06へ

次は「よく飲む商品」の表示領域を追加する。

Phase 5でユーザー固有データを接続するまでは、
架空のお気に入りデータは作らない。
