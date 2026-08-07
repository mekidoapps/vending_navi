# P4-01 商品検索Core

> 更新日: 2026-08-07
> 対象: VendingNavi v2 Phase 4

## 目的

Product masterを利用して、
ユーザー入力から選択可能なProduct候補を安定して返す。

P4-01は検索UIではなく、
今後すべての検索入口から共通利用するCore。

## 入力

```text
ProductSearchQuery(rawText)
```

個人情報や位置情報は持たない。

## 出力

```text
ProductSearchCandidate
- Product
- matchKind
- score
```

## matchKind

```text
productIdExact
nameExact
keywordExact
namePrefix
keywordPrefix
nameContains
keywordContains
```

## 例

```text
綾鷹
→ 綾鷹

あやたか
→ searchKeywords
→ 綾鷹

BOSS BLACK
→ searchKeywords
→ BOSS ブラック

ブラック
→ BOSS ブラック
→ FIRE ブラック
→ ワンダ ブラック
```

候補順は固定scoreで決定し、
Firestoreの返却順に依存しない。

## 非同期競合

ユーザーが短時間で入力を変えた場合、
遅れて返った古いquery結果で最新候補を上書きしない。

Controllerはrequest serialで最新検索だけを採用する。

## 0文字

空欄ではProduct Repositoryを読まない。

検索画面を閉じた時も`clear()`で初期状態へ戻せる。

## 未実装

P4-01では以下はまだ接続しない。

- HomeMap検索パネル
- Product選択
- machine_product_index
- 地図Marker filtering
- Genre
- よく飲む商品
- 検索半径
- 情報古さ
