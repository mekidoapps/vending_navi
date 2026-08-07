# P3-02 自販機Repository・v1/v2互換読取

> 更新日: 2026-08-07
> 対象: VendingNavi v2 Phase 3

## 1. 目的

`vending_machines`にv1旧文書とschemaVersion=2文書が同居している期間でも、
UIより上の層では`VendingMachine` Domainとして扱える読取境界を作る。

## 2. 読取経路

### v2

```text
vending_machines/{machineId}
  -> VendingMachineMapper
vending_machines/{machineId}/products/{productId}
  -> VendingMachineProductMapper
  -> VendingMachine.products
```

v2正式データは厳格に扱う。
壊れたrootまたはproduct文書を黙って除外しない。

### v1

```text
vending_machines/{machineId}
  -> LegacyVendingMachineCompatibilityMapper
  -> LegacyVendingMachineDomainBridge
  -> VendingMachine
```

P2で確定したProduct／Manufacturerマスタと手動aliasを利用する。

## 3. legacy商品

解決できた旧商品だけを`VendingMachineProduct`へ変換する。

```text
evidenceType = manual_confirmed
```

同じProduct IDが複数スロットに存在する場合は1商品へ集約する。

availability:

```text
1スロットでも購入可能 -> available
すべて売切           -> soldOut
```

未解決商品は推測でProduct IDを作らず、互換snapshotの
`unresolvedLegacyProductCount`へ件数だけ残す。

## 4. legacy位置欠損

`VendingMachine`は地図表示可能な位置を必須とする。

そのため位置を持たない旧文書は、

- 単体`getMachine()`ではValidationFailure
- migration用`getCompatibilitySnapshot()`では除外して件数を記録

とする。

v2正式データの不正位置は除外せずFailureにする。

## 5. compatibility snapshot

`getCompatibilitySnapshot()`はv1/v2共存確認用であり、
HomeMapの最終周辺検索APIではない。

全件取得をHomeMapから呼ばない。

P3-05でOI-003の周辺検索方針を決めたあと、
位置ベースのRepository APIを追加する。

## 6. Security Rules

P3-02でpublic readを開く範囲:

```text
/products/{productId}
/manufacturers/{manufacturerId}
/vending_machines/{machineId}
/vending_machines/{machineId}/products/{productId}
```

すべてclient writeは禁止。

次はまだdeny:

```text
/vending_machines/{machineId}/photos
/vending_machines/{machineId}/revisions
/machine_product_index
```

## 7. Emulator

Emulator fixtureに以下を置く。

- schemaVersion=2自販機
- v2 productsサブコレクション
- v1旧形式自販機

Rules検証では、

- v1 root read
- v2 root read
- v2 product read
- root write deny
- product write deny
- revisions read deny

を確認する。
