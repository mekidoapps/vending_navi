# P6-09 createVendingMachine Backend

> 状態: 実装中
> 日付: 2026-08-11

## 1. 目的

Phase 6の非AI登録ルートについて、公開データの正式書き込みをCallable Functionsへ集約する。

対象:

- メーカーから簡単登録
- メーカー不明 / 位置のみ登録

Phase 7の写真登録はまだ保存しない。

## 2. 監査から固定したこと

### geohash

既存Flutter `GeoHashCodec`と同じbase32アルゴリズムをFunctions側にも実装する。

Phase 3/4のfixtureと一致する精度6を使用する。

例:

```text
35.681236, 139.767125
→ xn76ur
```

クライアントからgeohashは受け取らない。

### machine_product_index ID

新規Functions書き込みでは次を正式形式とする。

```text
{machineId}_{productId}
```

検索はdocument IDに依存せずフィールドqueryで行うため、既存fixtureの任意IDは互換上そのまま利用できる。

### request_deduplication ID

要件の:

```text
uid + requestId + operation
```

を直接document IDにせず、次をSHA-256化する。

```text
uid|createVendingMachine|requestId
```

保存:

```text
request_deduplication/{sha256}
  uid
  operation
  requestId
  status
  result
  createdAt
  updatedAt
```

同一requestId再送時はエラーではなく、最初に保存したresultを返す。

### accountStatus互換

正式仕様では`users/{uid}.accountStatus`が必須だが、Phase 5の現行profile作成は:

```text
createdAt
updatedAt
```

のみで、現行client RulesもaccountStatus作成を許可していない。

そのためP6-09ではCallable/Admin SDK側で互換移行する。

- user documentなし → `accountStatus: active`で作成
- user documentあり / accountStatusなし → `active`をserver側で追加
- active → 許可
- restricted / suspended → 公開書き込み拒否
- その他の未知状態 → 安全側で拒否

これにより、既存Phase 5ユーザーを全員投稿不能にせず、accountStatusをサーバー管理値へ移行できる。

Phase 9でRules/profile作成契約を最終整理する。

### 自販機名自動生成（OI-012）

クライアントがnameを送らない場合:

```text
manufacturer:
  {displayShortName}の自販機

locationOnly:
  自販機
```

具体的な場所名等を推測して自動生成しない。

### 入力上限（OI-013最小サーバー制約）

Phase 6の安全上限:

```text
name                  60文字
placeDescription     120文字
confirmedProductIds   50件
```

50件はUIスロット数を定義する値ではなく、Callableへの異常入力を防ぐサーバー上限。

クローズドテストでUX上限が必要になれば別途調整する。

## 3. createVendingMachine処理

```text
Authentication
↓
request schema validation
↓
Phase 6でphoto requestを拒否
↓
requestId dedupe確認
↓
users/{uid}.accountStatus確認 / 互換初期化
↓
Manufacturer master確認
↓
Product master確認
↓
server geohash生成
↓
VendingMachine作成
↓
products作成
↓
revision作成
↓
machine_product_index作成
↓
request_deduplication保存
```

Firestore transaction内で一貫して確定する。

## 4. 商品evidence

### confirmedProductIds

```text
evidenceType = manual_confirmed
availability = available
confirmedBy = uid
confirmedAt = server time
```

### manufacturer preset

Manufacturer masterの`presetProductIds`をFunctionsが読み直す。

active Productだけを採用する。

```text
evidenceType = manufacturer_inferred
availability = unknown
confirmedBy = null
confirmedAt = null
```

同じProduct IDがpresetとconfirmedの両方に存在する場合、`manual_confirmed`を優先する。

## 5. machine dataLevel

```text
confirmedProductIdsあり
→ productsConfirmed

manufacturer登録 / confirmedなし
→ manufacturerOnly

locationOnly
→ locationOnly
```

メーカー推定だけでは`productsConfirmed`にしない。

## 6. revision

作成時:

```text
updateType = machineCreated
source = manufacturerPreset | manual
requestId = request requestId
```

完全document copyではなく、作成時の公開内容に必要な差分だけを`afterSnapshot`へ保存する。

## 7. App Check

P6-09では:

```ts
enforceAppCheck: false
```

とする。

理由:

- SECURITY_V2の導入順はdebug provider → 本番provider → metrics → Functions強制
- Phase 9が共通セキュリティ最終化フェーズ

Authentication・入力検証・accountStatus・冪等性はP6-09から実装する。
App Check強制を前倒しして実機開発導線を破壊しない。

## 8. サーバー側重複候補

30m近接自販機はP6-05で登録前に候補表示する。

近いという理由だけでFunctionsは登録拒否しない。
同一送信の二重作成はrequestId transactionで防止する。

異常な短時間大量登録はPhase 9のoperation rate limitで扱う。

## 9. Emulator verification

前提:

```text
Auth        9099
Functions   5001
Firestore   8080
```

master seed後:

```bash
cd functions

FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
FUNCTIONS_EMULATOR_HOST=127.0.0.1:5001 \
GCLOUD_PROJECT=vendingnavi \
npm run verify:create-machine
```

確認内容:

- Auth emulator userでCallable実行
- accountStatus未作成ユーザーをactiveへserver移行
- manufacturer quick registration
- geohash
- inferred product
- revision
- machine_product_index
- request_deduplication
- 同一requestId再送でmachine増加なし
- locationOnly
- restricted拒否

## 10. Production保護

P6-09では変更しない:

```text
firebase.json
firestore.rules
```

`firebase/v2/firestore.rules`もFunctions Admin SDK書き込みには変更不要。

本番deployはP6-09完了条件に含めない。
