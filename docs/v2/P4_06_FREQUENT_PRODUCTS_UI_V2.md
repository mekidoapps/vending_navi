# P4-06 よく飲む商品 表示領域

> 更新日: 2026-08-09
> 対象: VendingNavi v2 Phase 4

## 1. 目的

商品検索パネルに「よく飲む商品」の表示領域を確保する。

P4-06ではユーザー認証・ユーザー保存をまだ実装しない。

Phase 5でユーザー固有のProduct一覧を取得したとき、
検索UIを作り直さずそのまま接続できる状態にする。

## 2. 表示位置

検索パネルの構成:

```text
商品を探す
[ 商品名を入力 ]

ジャンルから探す
[お茶][緑茶][コーヒー]...

よく飲む商品
（ユーザーデータがあれば商品一覧）
```

商品名を入力すると下部領域は、

```text
候補
- 検索候補
```

へ切り替わる。

空欄へ戻すと「よく飲む商品」へ戻る。

## 3. P4-06のデータ境界

`V2ProductSearchPanel`は、

```text
List<Product> frequentProducts
```

を受け取る。

P4-06のデフォルト値:

```text
[]
```

固定の商品や架空のお気に入りを入れない。

Phase 5で認証・userデータ側から実データを渡す。

## 4. 空状態

実データがない場合:

```text
よく飲む商品はまだありません
```

だけを表示する。

以下はP4-06で表示しない。

- 仮の商品
- デモ用お気に入り
- ログイン済みと誤解させる情報
- Premium上限
- 利用回数ランキング

## 5. 商品選択

よく飲む商品を押した場合も、
既存Product検索と同じ`onProductSelected`を利用する。

そのため後続フローは既存のP4-04をそのまま再利用する。

```text
よく飲む商品
→ Product選択
→ ProductSearchSelectionController
→ machine_product_index
→ HomeMap Marker filter
```

専用の検索経路を増やさない。

## 6. selectable

表示時に`Product.isSelectable`を確認する。

inactiveなProductが将来ユーザー保存側に残っていた場合でも、
検索入口として表示しない。

正式なユーザーデータ整合処理はPhase 5で扱う。

## 7. レイアウト

P4-05のoverflow修正を維持する。

下部領域はListViewまたはcompact empty stateとして、
小型画面で固定高さFlexを増やさない。

## 8. P4-07へ

次は検索条件を固定カード・自販機詳細へ引き継ぐ。

Product検索:

```text
検索対象商品を詳細の商品一覧先頭へ
```

Genre検索:

```text
検索対象Genreの商品を詳細の商品一覧先頭へ
```

`確認済み` / `あるかも`のevidence差は維持する。
