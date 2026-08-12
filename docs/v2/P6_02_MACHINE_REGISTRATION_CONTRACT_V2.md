# P6-02 / P6-03 自販機登録契約・状態管理

> 対象: VendingNavi v2 Phase 6
> 状態: 実装基準
> 決定日: 2026-08-11

## 1. Phase 6の範囲

Phase 6は非AIの自販機新規登録を完成させる。

```text
Home「登録」
→ Auth Gate
→ 位置確認・調整
→ 重複候補確認
→ 登録方法選択
→ メーカー選択 または 分からない
→ 最終確認
→ createVendingMachine
→ 自販機詳細
```

写真撮影・一時Storage・AI認識はPhase 7、既存自販機の更新はPhase 8へ分離する。

## 2. createVendingMachine client契約

Callable Function名:

```text
createVendingMachine
```

リクエスト:

```json
{
  "requestId": "uuid-v4",
  "registrationMethod": "photo|manufacturer|locationOnly",
  "location": {
    "latitude": 35.0,
    "longitude": 139.0
  },
  "name": null,
  "manufacturerId": "coca_cola",
  "confirmedProductIds": [],
  "temporaryPhotoUploadId": null,
  "placeDescription": null,
  "installationType": "unknown"
}
```

クライアントが送らない・信用させない値:

- createdBy / updatedBy
- createdAt / updatedAt
- geohash
- evidenceType
- status / dataLevel
- メーカー推定商品
- revision
- machine_product_index

これらはFunctions側で確定する。

Phase 6では`registrationMethod`は`manufacturer`または`locationOnly`のみ送信する。
`photo`はPhase 7用にwire contractだけ保持する。

## 3. メーカー簡単登録

- メーカー選択時、`manufacturerId`を送る。
- `presetProductIds`はクライアントから送らない。
- FunctionsがManufacturer masterから`presetProductIds`を読み、`manufacturer_inferred`として保存する。
- 推定商品は`availability: unknown`を基本とする。
- ユーザーが実物を確認して手動追加したProduct IDのみ`confirmedProductIds`として送る。

## 4. メーカー不明

「分からない」は正式ルート。

```text
registrationMethod = locationOnly
manufacturerId = null
confirmedProductIds = []
```

位置のみの自販機として登録可能にする。

## 5. 重複候補方針 OI-005

2026-08-11決定:

- 候補表示距離は30m以内。
- メーカーに関係なく候補対象にする。
- 近い順に表示する。
- 候補があっても新規登録を禁止しない。
- ユーザーは「既存を見る / 更新する / 別自販機として続ける」を選べる。
- Functions側でも30m以内の近接候補を検出可能にするが、近接だけを理由にcreateを拒否しない。
- 二重送信そのものは`requestId`冪等性で防止する。

隣接した複数台の自販機を正しく登録できることを優先する。

## 6. requestId

- クライアントでUUID v4を1登録フローにつき1つ生成する。
- 戻る・再試行では同じrequestIdを保持する。
- 登録完了またはキャンセル後の新しい登録フローでは新しいrequestIdを生成する。
- Functionsは`uid + requestId + operation`で冪等性を保証する。

## 7. Repository境界

既存`VendingMachineRepository`は公開データのread責務を維持する。

writeは新規の:

```text
MachineRegistrationRepository
```

へ分離する。

```text
Presentation
→ MachineRegistrationController
→ MachineRegistrationRepository
→ MachineRegistrationDataSource
→ Firebase Callable Functions
```

ScreenからFirestore / Cloud Functions SDKを直接呼ばない。

## 8. P6-02 / P6-03で実装するもの

- registration method wire enum
- RegistrationDraft
- create request DTO
- create response DTO
- MachineRegistrationRepository
- Callable data source
- Repository implementation
- UUID v4 requestId generator
- MachineRegistrationState
- MachineRegistrationController
- Riverpod providers
- unit tests

まだ実装しないもの:

- 登録画面
- 30m重複検索UI
- createVendingMachine Functions本体
- Firestore書き込み
- machine_product_index生成
- 写真 / Storage / AI
- 既存自販機更新
