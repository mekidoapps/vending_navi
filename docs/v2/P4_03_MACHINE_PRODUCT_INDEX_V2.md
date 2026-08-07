# P4-03 machine_product_index read

> 更新日: 2026-08-07
> 対象: VendingNavi v2 Phase 4

## 1. 目的

選択済みProduct IDから、
地図範囲内でその商品を持つ自販機候補を検索するための
派生index read層を作る。

P4-03ではまだHomeMap Markerへ接続しない。

## 2. Collection

```text
machine_product_index/{indexId}
```

派生データであり、正本ではない。

正本:

```text
vending_machines/{machineId}
  products/{productId}
```

indexはFunctions/Admin SDK側で同期する前提。

クライアント:

```text
read  OK
write NG
```

## 3. indexId

P4-03ではdocument ID形式を公開契約として固定しない。

Repositoryは`indexId`に依存せず、

```text
productId
geohash
```

のフィールドで検索する。

fixtureのdocument IDはテスト識別用であり、
本番ID規則の決定ではない。

## 4. 読み取りQuery

```text
productId == selectedProductId
geohash >= prefix
geohash <= prefix + \uf8ff
```

P3-05で使用したviewport geohash plannerを再利用する。

Firestore v2 emulator用に複合index:

```text
productId ASC
geohash ASC
```

を追加する。

本番index deployはまだ行わない。

## 5. Domain

`MachineProductIndexEntry`:

- machineId
- productId
- genreIds
- location
- geohash
- evidenceType
- availability
- isActive
- machineStatus
- machineUpdatedAt
- updatedAt

既存Domain enum/value objectへ変換する。

未知Genre、未知evidence、未知status等は
静かに推測せずValidation Failureとする。

## 6. Repository filter

Firestore query後に必ず再確認する。

- Product ID一致
- `isActive == true`
- `machineStatus == active`
- viewport内

`availability == soldOut`はP4-03では除外しない。

理由:

- 売切情報の鮮度PolicyはOI-004と関係する
- P4-03は検索データ取得層
- P4-04以降で表示Policyを決める

## 7. 重複

同一machineIdのentryが複数返った場合:

```text
confirmed
> inferred
```

の順で1件へ縮約する。

正常な派生indexでは同一Product×Machineは1件を想定するが、
重複時にもUIが二重Markerにならないための防御。

## 8. Emulator

P4-03でv2 Emulator Rulesを変更する。

追加:

```text
machine_product_index
read: public
write: deny
```

fixture:

- BOSSブラック confirmed
- サントリー天然水 inferred

Rules gate:

- index read = 200
- client index write = 403

## 9. 本番保護

変更しない:

- root `firebase.json`
- root `firestore.rules`

v2隔離環境だけを更新する。

## 10. P4-04へ

P4-04で、

```text
ProductSearchSelectionController
+ current viewport
+ MachineProductIndexRepository
→ machineId群
→ HomeMap Marker filter
```

へ接続する。

その時点で0件状態と検索解除もHomeMapへ反映する。
