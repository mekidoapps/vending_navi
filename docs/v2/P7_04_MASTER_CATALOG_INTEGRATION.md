# P7-04 Firestore Master Catalog Integration

> 日付: 2026-08-12
> 状態: Functions内部接続

## 目的

P7-04 pure resolverを、既存Firestore Masterの読み取り境界へ接続する。

対象:

```text
manufacturers
products
```

認識用に別Masterは作らない。

## Firestore reader

Functions/Admin SDKでactive Masterを読む。

```text
manufacturers.where(isActive == true)
products.where(isActive == true)
```

認識照合に必要なfieldだけをadapterで取り出す。

```text
id
name
searchKeywords
isActive
```

Productの`manufacturerId`はProduct Master自身の属性として残るが、
AI文字列からProduct IDを照合するための条件にはしない。

理由:

- 自販機本体ブランドと商品メーカーは独立
- 複数メーカー商品が同じ自販機に混在してよい
- machineManufacturerLabelsを商品照合のfilterに使わない

## 整合性

active Masterで`name`が欠損している場合は、
認識処理のMaster不整合として失敗させる。

AI認識失敗は登録全体の失敗にはしないため、
Callable側では将来このエラーを安全な認識失敗へ変換し、
手動登録へfallbackできるようにする。

## Resolution service

入力:

```text
machineManufacturerLabels
productLabels
unresolvedLabels
```

出力:

```text
manufacturerCandidateIds
productCandidateIds
unresolvedLabels
```

providerが返したunresolvedと、
Masterへ解決できなかったmanufacturer/product labelを統合する。

## Firestore Rulesとの関係

FunctionsのAdmin SDKはFirestore Security Rulesに依存せずMasterを読める。

既存v2 Rulesでは`manufacturers` / `products`は公開read、
client write禁止のままであり、本変更ではRulesを変更しない。

## 次段

次はFake Recognition Providerを使い、

```text
recognizeVendingMachinePhoto Callable
→ request validation
→ provider
→ Firestore Master reader
→ resolver
→ normalized response
```

を接続する。

Vertex AI実接続はFake provider経路が通った後に行う。
