# 旧データ互換Mapper規約

> 文書状態: Phase 2 P2-03 固定版  
> 更新日: 2026-08-07  
> 対象: 自販機ナビ / VendingNavi v2

## 1. 目的

現行`vending_machines`には、位置・メーカー・商品・日時に複数世代のフィールドが混在している。v2では旧ドキュメントを破壊的に更新せず、読み取り境界で揺れを吸収する。

P2-03はv2自販機Domain Modelを先行して固定する工程ではない。旧Firestore文書をread-onlyのLegacy型へ読み、Product／Manufacturer Domainへ解決できる部分だけを安定IDへ変換する。

## 2. 旧自販機フィールド

位置は次の順で読む。

1. `lat` / `lng`
2. `latitude` / `longitude`
3. `location: GeoPoint`

値が欠損・不正の場合は`null`として保持し、`0,0`へ自動補正しない。

日時はFirestore `Timestamp`、`DateTime`、ISO形式文字列を受け入れる。欠損日時は`DateTime.now()`で埋めず`null`として保持する。

## 3. 旧商品配列

次の順で、最初に有効な商品を1件以上取得できたフィールドを採用する。

1. `products`
2. `drinkSlots`
3. `slots`
4. `drinks`

Map形式では`name`、`drinkName`、`productName`を旧表示名候補として読み、`productId`または`id`があれば明示ID候補として保持する。

`isSoldOut` / `soldOut`と`tags`は移行判断用の補助情報として保持する。棚配置そのものはv2 MVPへ移植しない。

## 4. Manufacturer ID解決

解決順は次とする。

1. Manufacturer ID完全一致
2. 正規化した正式名／短縮表示名の一意一致
3. P2-04で固定する手動対応表
4. 未解決

`不明`、`未設定`等を`unknown`という架空Manufacturer IDへ変換しない。

## 5. Product ID解決

`MIGRATION_PLAN_V2.md`に従い、次の順で確定する。

1. Product ID完全一致
2. 正規化した旧商品名の一意一致
3. メーカー＋正規化商品名で一意一致
4. P2-04で固定する手動対応表
5. 未解決

検索キーワードによる曖昧一致、部分一致、類似度による自動確定は行わない。誤ったProduct IDへの変換より未解決を優先する。

## 6. 未解決商品

Product IDへ変換できない旧商品は削除しない。

保持する情報:

- `rawName`
- 元フィールド種別
- 旧tags
- 旧売切情報
- `productId: null`
- `resolutionKind: unresolved`

これにより、マスタ外商品が存在しても自販機全体を表示対象から落とさず、後続の移行・運営確認で追跡できる。

## 7. 読み取り専用

Legacy MapperからFirestoreへのwriteは提供しない。

- 読み込みだけで`schemaVersion`を変更しない
- 旧`drinks`等を削除しない
- Product IDを推測で書き戻さない
- 移行writeはdry-run・revision・件数ログを備えた別ツールで行う

## 8. P2-04への引き継ぎ

P2-04で次を固定する。

- Product fixture
- Manufacturer fixture
- v1旧ID／旧名称の手動対応表
- Product／Manufacturer Repository

P2-03のResolverは、そのfixture／対応表を入力として受け取る純粋な変換処理として維持する。
