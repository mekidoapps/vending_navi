# P5-07 favorite_products / よく飲む商品

## 1. 目的

Phase 4で用意した「よく飲む商品」表示領域へ、
ユーザー本人の実データを接続する。

保存の正本は商品名ではなくProduct IDとする。

```text
users/{uid}/favorite_products/{productId}
```

## 2. 保存schema

```text
productId: string
sortOrder: int
createdAt: timestamp
```

Product IDをdocument IDにも使用して重複登録を防止する。

Product本体の名称・ジャンル・画像等はユーザー配下へ複製せず、
`products/{productId}`を正本として解決する。

## 3. 読み書き

`favorite_products`は本人専用データのため、
P5-06 profileと同様に本人のみFirestore直接読み書きを許可する。

公開・コミュニティデータのwriteは引き続きCallable Functions経由とする。

production root `firestore.rules`はP5-07では変更しない。
P5-08品質ゲートでdev Rulesとまとめて統合確認する。

## 4. v1 favoriteDrinkNames互換

v1では次の文字列配列を使用していた。

```text
users/{uid}.favoriteDrinkNames
```

P5-07では、v2 `favorite_products`がまだ存在せず、
migration完了記録もない場合だけfallback候補として読む。

旧名称は`LegacyNameNormalizer`で正規化し、
現行Product masterの`name`または`searchKeywords`へ
完全一致し、かつ対応Productが一意なものだけ表示する。

曖昧候補は自動変換しない。

fallback表示だけではFirestoreを書き換えない。
ユーザーが追加または削除を行ったタイミングで、
解決済みProduct IDを`favorite_products`へmaterializeし、

```text
favoriteProductsMigratedAt
```

を`users/{uid}`へ記録する。

これにより、全件削除した後に旧`favoriteDrinkNames`が再表示されない。

旧`favoriteDrinkNames`自体は削除しない。
v1互換データをP5-07で破壊しないためである。

## 5. マイページ

ログイン済みMyPageに以下を追加する。

- よく飲む商品一覧
- 商品検索から追加
- Product ID重複防止
- 削除確認
- 読込失敗時の再試行
- legacy fallback表示中の軽い案内

自由入力によるお気に入り追加は行わない。

## 6. Home検索

Phase 4の

```text
V2ProductSearchPanel.frequentProducts
```

へ`FavoriteProductsController.products`を接続する。

選択後は既存P4 Product ID検索フローをそのまま再利用する。

未ログイン時は固定の架空商品を表示せず、
ログインして登録する導線を表示する。

## 7. 上限

P5-07では無料10 / premium100等の新しい上限制御を実装しない。

技術上限・課金設計はOI-011の判断後に決定する。

## 8. テスト観点

- Product ID保存
- document IDとの一致
- 重複防止
- sortOrder
- 削除
- 本人のみRules
- legacy nameの一意解決
- 曖昧legacy nameは移行しない
- migration marker
- Home検索への実データ接続
- guest導線
- responsive
- v1 production Rules非変更

## 9. P5-08へ持ち越すもの

- production `firestore.rules`統合
- Auth / favorite_productsのEmulator総合rules test
- Phase 5 full regression
- OI-011上限制御の最終判断
