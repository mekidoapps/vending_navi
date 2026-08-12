# P6-07 メーカー選択

> 状態: 実装中
> 日付: 2026-08-11

## 目的

メーカー簡単登録で使用するManufacturer IDを、既存のManufacturer masterから選択する。

固定文字列のメーカー一覧は新しく持たない。

## データ源

```text
ManufacturerRepository.getManufacturers(activeOnly: true)
```

から取得し、`Manufacturer.isSelectable == true`だけを表示する。

## 選択

メーカーを選択:

```text
MachineRegistrationController.selectManufacturer(id)
→ registrationMethod = manufacturer
→ manufacturerId = 選択ID
→ step = confirm
```

「分からない」を選択:

```text
MachineRegistrationController.chooseLocationOnly()
→ registrationMethod = locationOnly
→ manufacturerId = null
→ confirmedProductIds = []
→ step = confirm
```

## 推定商品

`presetProductIds`は画面で参考件数のみ表示できるが、create requestへ推定商品として送信しない。

正式登録時にFunctionsがManufacturer masterから`presetProductIds`を読み、`manufacturer_inferred`として生成する。

## 「その他」の扱い

画面仕様にある「その他」は、Manufacturer masterに有効な`other`等の正式エントリが存在する場合に通常のメーカーとして表示する。

クライアント側だけで存在しないManufacturer IDを作らない。
FunctionsではManufacturer IDの実在確認を行うため、master未登録の「その他」を擬似IDとして送信しない。

メーカー自体が分からない場合は「分からない」＝locationOnlyを使用する。

## 次工程

P6-08で最終確認画面を実装する。

表示対象:

- 位置
- 自販機名
- メーカー
- 確認済み商品
- メーカー推定商品の説明

写真欄はPhase 7で追加する。
