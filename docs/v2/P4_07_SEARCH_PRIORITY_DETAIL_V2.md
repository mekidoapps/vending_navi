# P4-07 検索対象の固定カード・詳細優先表示

> 更新日: 2026-08-09
> 対象: VendingNavi v2 Phase 4

## 1. 目的

検索結果の自販機を開いた時に、

```text
なぜこの自販機が検索結果に出たのか
```

を固定カードと詳細画面で明確にする。

Product検索とGenre検索の条件は、
HomeMapから詳細画面へ移動しても保持する。

## 2. HomeMap固定カード

検索中にMarkerを選択した場合、
通常の自販機情報より先に検索一致情報を表示する。

Product検索:

```text
🔍 BOSS ブラック   確認済み
```

Genre検索:

```text
🔍 コーヒーの商品   あるかも
```

Badgeはその検索条件に対応するevidenceを使用する。

別商品のconfirmed状態で検索一致Badgeを強くしない。

通常の自販機全体Badge・商品件数・場所は従来どおり残す。

## 3. 詳細画面

検索条件がある場合、
ドリンク一覧の上に:

```text
検索条件「BOSS ブラック」に合う商品を先に表示しています
```

または:

```text
検索条件「コーヒー」に合う商品を先に表示しています
```

を表示する。

一致商品の行には:

```text
検索対象
```

を追加する。

## 4. 並び順

### Product検索

```text
選択Product
→ その他
```

を最優先する。

検索対象Productが`あるかも`で、
非検索商品が`確認済み`でも、
検索対象Productを先頭にする。

### Genre検索

```text
選択Genreの商品群
→ その他
```

の順にする。

同じ検索一致グループ内では従来どおり:

```text
confirmed
→ inferred
→ other
→ 商品名
```

で安定化する。

## 5. Product master Genre

詳細画面のGenre優先表示のため、
`VendingMachineProductDetailItem`にProduct masterのGenreを保持する。

Product master取得失敗時は:

```text
productName = Product ID fallback
genres = []
```

とし、推測でGenreを補わない。

## 6. Route

新しいroute parameterは増やさない。

HomeMapと詳細画面は同じRiverpod scope内にあり、
既存の:

- ProductSearchSelectionController
- GenreSearchSelectionController

を詳細側でも参照する。

直接URLで詳細を開いた場合、
検索selectionがなければ従来の詳細表示になる。

## 7. 情報の古さ

P4-07では具体的な stale 判定期間を追加しない。

使用する状態:

- 確認済み
- あるかも

`以前の情報`へ切り替える日数はOI-004のまま未決定。

検索優先表示のために、
根拠のない期限を新設しない。

## 8. P4-08へ

次はPhase 4品質ゲート。

確認対象:

- Product検索
- Genre検索
- よく飲む商品空状態
- Marker filter
- fixed card priority
- detail priority
- small/base/large responsive
- 全回帰
- OI-003 / OI-004の扱いを明文化
