# Phase 2 完了レポート

> 完了予定日: 2026-08-07  
> 対象: VendingNavi v2

## Phase 2で確立したもの

### Master Domain
- Product ID
- Manufacturer ID
- Product
- Manufacturer
- ProductGenre

### Firestore境界
- ProductDto
- ManufacturerDto
- Timestamp変換
- Mapper
- Repository
- MasterDocumentSource

### v1互換
- 旧自販機ドキュメント読取
- 旧商品文字列解決
- メーカーalias
- 商品alias
- 未解決商品の保持

### 初期マスタ
- Manufacturer: 7件
- Product: 33件
- Dart固定fixture
- Emulator seed snapshot

### Security
- products: public read / client write deny
- manufacturers: public read / client write deny
- その他: deny-by-default

## Phase 3へ持ち越すもの

Phase 3では自販機本体のv2 Domain／Repositoryへ進む。

主対象:

```text
vending_machines
vending_machines/{machineId}/products
vending_machines/{machineId}/photos
vending_machines/{machineId}/revisions
machine_product_index
```

Phase 2ではこれらの公開read/write Rulesは開放しない。
