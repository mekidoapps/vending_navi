> 文書状態: Phase 0 正式版（実装前基準）  
> 更新日: 2026-08-04  
> 対象: 自販機ナビ / VendingNavi v2  
> パッケージID: `com.mekidoapps.vendingnavi`  
> リポジトリ: `mekidoapps/vending_navi`


# Cloud Functions仕様

## 1. 共通契約

### 呼び出し方式

Firebase Callable Functionsを基本とする。

### 共通必須条件

- Firebase Authentication
- App Check（開発中はdebug provider、強制は段階導入）
- `users/{uid}.accountStatus == active`
- 入力スキーマ検証
- 文字数・件数上限
- Product ID / Manufacturer ID / Machine IDの実在確認
- `requestId`による冪等性
- サーバー時刻の使用

### クライアントから信用しない値

- createdBy / updatedBy
- createdAt / updatedAt
- geohash
- evidenceType
- status / dataLevel
- メーカー推定商品
- 管理状態
- 更新履歴
- recognitionProvider
- 検索インデックス

### エラーコード候補

```text
unauthenticated
app-check-required
account-restricted
invalid-argument
not-found
permission-denied
resource-exhausted
already-processed
duplicate-candidate
recognition-failed
temporary-unavailable
internal
```

Flutter側では内部例外をそのまま表示せず、次の行動を含む文言へ変換する。

## 2. `createVendingMachine`

### 目的

写真登録、メーカー簡単登録、位置のみ登録を一つのサーバー契約で処理する。

### 入力候補

```json
{
  "requestId": "uuid",
  "registrationMethod": "photo|manufacturer|locationOnly",
  "location": {"latitude": 0, "longitude": 0},
  "name": "任意または自動生成用null",
  "manufacturerId": "string|null",
  "confirmedProductIds": ["productId"],
  "temporaryPhotoUploadId": "string|null",
  "placeDescription": "string|null",
  "installationType": "outdoor|indoor|unknown"
}
```

### サーバー処理

1. 共通チェック
2. 位置・文字数・商品数を検証
3. 重複処理済み`requestId`を確認
4. メーカー・商品マスタを取得
5. 登録方法から`manufacturerStatus`と`evidenceType`を決定
6. メーカー簡単登録なら`presetProductIds`を推定として追加
7. 写真登録なら一時画像の所有者・状態を検証
8. 自販機、商品、写真、revision、検索インデックスを整合させて作成
9. 一時画像を正式領域へ反映
10. 冪等性記録を保存

### 戻り値

```json
{
  "machineId": "string",
  "created": true,
  "duplicateCandidates": []
}
```

重複候補の検索は登録前画面で行うが、サーバー側でも最低限の異常な連続登録を検知できる設計にする。

## 3. `recognizeVendingMachinePhoto`

### 目的

一時保存画像からメーカー・商品候補を返す。公開データへは書き込まない。

### 入力

```json
{
  "requestId": "uuid",
  "uploadId": "string"
}
```

### 処理

1. 一時画像が本人所有か確認
2. 画像形式・サイズ・期限を確認
3. AI認識サービスを呼び出す
4. 応答をProduct ID / Manufacturer IDへ照合
5. 重複・無効商品・未解決候補を整理
6. 生レスポンスをそのまま返さない
7. 必要な処理ログのみ保存

### 戻り値

```json
{
  "manufacturerCandidates": [
    {"manufacturerId": "coca_cola", "needsConfirmation": false}
  ],
  "productCandidates": [
    {"productId": "ayataka_regular", "needsConfirmation": false}
  ],
  "unresolvedLabels": [],
  "recognitionStatus": "completed"
}
```

ユーザー確認前の候補は公開商品データではない。

## 4. `updateVendingMachineProducts`

### 目的

商品追加、無効化、売り切れ、推定から確認済みへの変更を処理する。

### 入力候補

```json
{
  "requestId": "uuid",
  "machineId": "string",
  "operations": [
    {"type": "addConfirmed", "productId": "...", "source": "manual|photo"},
    {"type": "deactivate", "productId": "..."},
    {"type": "setSoldOut", "productId": "...", "soldOut": true},
    {"type": "confirmInferred", "productId": "..."}
  ],
  "temporaryPhotoUploadId": "string|null"
}
```

### ルール

- 既存の確認済み情報を推定へ格下げしない。
- 写真に写らなかっただけの既存商品を自動無効化しない。
- 追加Product IDが有効か確認する。
- 商品、`updatedAt`、`lastProductUpdatedAt`、revision、indexを一括更新する。

## 5. `addVendingMachinePhoto`

### 入力

```json
{
  "requestId": "uuid",
  "machineId": "string",
  "uploadId": "string",
  "setAsPrimary": true
}
```

### 処理

- 一時画像所有権・期限・形式の確認
- 正式保存
- photoドキュメント作成
- 主写真更新
- revision作成
- 一時領域整理

## 6. `submitMachineCorrection`

### 目的

一般ユーザーが直接上書きしない基本情報の修正案を受け付ける。

### 入力候補

```json
{
  "requestId": "uuid",
  "machineId": "string",
  "changes": {
    "name": "string|null",
    "manufacturerId": "string|null",
    "location": {"latitude": 0, "longitude": 0},
    "placeDescription": "string|null",
    "installationType": "outdoor|indoor|unknown|null"
  },
  "message": "string|null"
}
```

### 結果

- 修正提案を`new`で保存
- 自販機本体は自動変更しない
- `updatedAt`を変更しない

## 7. `submitMachineReport`

### 入力

```json
{
  "requestId": "uuid",
  "machineId": "string",
  "photoId": "string|null",
  "category": "machineRemoved|duplicate|inaccessible|inappropriatePhoto|inappropriateText|other",
  "message": "string|null"
}
```

### 処理

- 対象の存在確認
- 連投・重複報告の制限
- `new`として保存
- 1件の報告だけで自動非表示にしない
- 自販機の`updatedAt`を変更しない

## 8. `submitFeedback`

既存共通運営基盤を継続する。

### 入力

```json
{
  "appId": "vending_navi",
  "category": "bug",
  "message": "...",
  "screen": "home_map",
  "stepsToReproduce": "...",
  "replyRequested": false,
  "appVersion": "...",
  "platform": "android",
  "locale": "ja-JP"
}
```

### 制限候補

- 本文10〜2000文字
- 30秒以内の連投禁止
- 1日20件まで
- URL過多は拒否またはスパム疑い

## 9. 定期・イベント処理

### 一時画像削除

- 期限切れ`machine_uploads/{uid}/{uploadId}`を削除する。
- 保存期限は`OPEN_ISSUES.md`で確定する。

### 検索インデックス再構築

- 元データから`machine_product_index`を再生成できる管理用スクリプトまたはFunctionsを用意する。
- MVP専用管理UIは作らず、CLIまたはFirebase側の運用を想定する。

## 10. トランザクション境界

Firestoreの整合が必要な次の書き込みを、可能な範囲でトランザクションまたはバッチにまとめる。

- 自販機本体
- 商品サブコレクション
- revision
- `machine_product_index`
- 冪等性記録

Storageファイル操作はFirestoreトランザクション外となるため、一時保存→正式反映→失敗時の再処理可能状態を明示する。
