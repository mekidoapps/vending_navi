> 文書状態: Phase 0 正式版（実装前基準）  
> 更新日: 2026-08-04  
> 対象: 自販機ナビ / VendingNavi v2  
> パッケージID: `com.mekidoapps.vendingnavi`  
> リポジトリ: `mekidoapps/vending_navi`


# データモデル

## 1. 基本方針

- 現行`vending_machines`を維持し、v2フィールドとサブコレクションを追加する。
- `schemaVersion`で旧・新形式を判別する。
- 商品はProduct IDで管理する。
- 自販機本体、商品、写真、履歴、報告を分離する。
- 確認済みと推定の由来を保存する。
- 旧フィールドは移行完了まで削除しない。
- 公開データの正式な書き込みはCloud Functionsが行う。

## 2. コレクション構成

```text
products/{productId}
manufacturers/{manufacturerId}
vending_machines/{machineId}
  products/{productId}
  photos/{photoId}
  revisions/{revisionId}
machine_product_index/{indexId}
machine_reports/{reportId}
machine_corrections/{correctionId}
users/{uid}
  favorite_products/{productId}
feedback_items/{feedbackId}
feedback_rate_limits/{uid}
operation_rate_limits/{uid}
request_deduplication/{dedupeId}
```

`machine_corrections`と`machine_reports`は分離する。

- 名前・メーカー・位置・場所メモ・設置場所の修正提案は`machine_corrections`へ保存する。
- 商品の追加・売り切れ・非表示・推定商品の確認は`updateVendingMachineProducts`で正式データを更新する。
- 撤去・重複・立入不可・不適切な写真/文章などの状態報告は`machine_reports`へ保存する。

## 3. `products/{productId}`

| フィールド | 型 | 必須 | 説明 |
|---|---|---:|---|
| name | string | ○ | 表示名 |
| searchKeywords | array<string> | ○ | ひらがな、英字、別表記等 |
| manufacturerId | string | ○ | メーカーID |
| genreIds | array<string> | ○ | ジャンル |
| imageUrl | string/null |  | 商品画像 |
| isActive | boolean | ○ | 検索・選択で使用可能か |
| createdAt | timestamp | ○ | 作成日時 |
| updatedAt | timestamp | ○ | 更新日時 |

Product IDはドキュメントIDと同一とする。

## 4. ジャンル

MVPでは固定値としてコードまたは設定ファイルで管理し、必要になった段階でコレクション化する。

```text
tea
green_tea
coffee
water
carbonated
juice
sports_drink
energy_drink
other
```

無糖、甘い、ホット、カフェイン等はMVP検索ジャンルに含めない。

## 5. `manufacturers/{manufacturerId}`

| フィールド | 型 | 必須 | 説明 |
|---|---|---:|---|
| name | string | ○ | 正式表示名 |
| displayShortName | string | ○ | 短縮表示 |
| searchKeywords | array<string> | ○ | 検索用 |
| presetProductIds | array<string> | ○ | 簡単登録の推定商品 |
| isActive | boolean | ○ | 選択可能か |
| createdAt | timestamp | ○ | 作成日時 |
| updatedAt | timestamp | ○ | 更新日時 |

企業ロゴ画像は必須項目としない。

## 6. `vending_machines/{machineId}`

| フィールド | 型 | 必須 | 説明 |
|---|---|---:|---|
| schemaVersion | number | ○ | 1=旧、2=v2 |
| name | string | ○ | 自販機名 |
| manufacturerId | string/null |  | メーカー |
| manufacturerStatus | string | ○ | confirmed / recognized_and_confirmed / unknown |
| location | GeoPoint | ○ | 位置 |
| geohash | string | ○ | 周辺検索 |
| placeDescription | string/null |  | 場所メモ |
| installationType | string | ○ | outdoor / indoor / unknown |
| status | string | ○ | active / underReview / hidden / removed / merged |
| mergedIntoMachineId | string/null |  | 統合先 |
| dataLevel | string | ○ | locationOnly / manufacturerOnly / productsConfirmed |
| primaryPhotoId | string/null |  | 主写真 |
| createdBy | string | ○ | 作成UID |
| createdAt | timestamp | ○ | 作成日時 |
| updatedAt | timestamp | ○ | ユーザー向け最終更新 |
| lastProductUpdatedAt | timestamp/null |  | 商品更新日時 |

`updatedAt`は実際の公開内容が受理・反映された時だけ更新する。報告受付や審査状態だけでは更新しない。

## 7. `vending_machines/{machineId}/products/{productId}`

| フィールド | 型 | 必須 | 説明 |
|---|---|---:|---|
| productId | string | ○ | ドキュメントIDと同一 |
| evidenceType | string | ○ | manual_confirmed / photo_confirmed / manufacturer_inferred |
| availability | string | ○ | available / soldOut / unknown |
| isActive | boolean | ○ | 現在有効な商品情報か |
| confirmedBy | string/null |  | 確認UID |
| confirmedAt | timestamp/null |  | 確認日時 |
| createdAt | timestamp | ○ | 作成日時 |
| updatedAt | timestamp | ○ | 更新日時 |

### ルール

- AI未確認候補はここへ保存しない。
- メーカー推定は`availability: unknown`を基本とする。
- 「なくなった」は物理削除ではなく`isActive: false`。
- 高確度情報を低確度情報で上書きしない。

## 8. `vending_machines/{machineId}/photos/{photoId}`

| フィールド | 型 | 必須 | 説明 |
|---|---|---:|---|
| storagePath | string | ○ | 正式画像パス |
| thumbnailPath | string/null |  | サムネイル |
| status | string | ○ | active / underReview / hidden / deleted |
| uploadedBy | string | ○ | UID |
| uploadedAt | timestamp | ○ | 投稿日時 |
| recognitionStatus | string | ○ | notRequested / processing / completed / failed |
| recognitionProvider | string/null |  | 使用サービス |
| isPrimary | boolean | ○ | 主写真か |

一般ユーザーは完全削除できない。`deleted`も運営上の論理状態として扱う。

## 9. `vending_machines/{machineId}/revisions/{revisionId}`

| フィールド | 型 | 必須 | 説明 |
|---|---|---:|---|
| updateType | string | ○ | machineCreated / productsUpdated / photoAdded / basicInfoUpdated / adminUpdated / statusChanged |
| source | string | ○ | manual / photoRecognition / manufacturerPreset / admin / migration |
| updatedBy | string | ○ | UIDまたは管理者識別 |
| updatedAt | timestamp | ○ | 更新日時 |
| changedFields | array<string> | ○ | 対象 |
| beforeSnapshot | map |  | 変更前の必要部分 |
| afterSnapshot | map |  | 変更後の必要部分 |
| requestId | string/null |  | 重複追跡 |

全ドキュメントの完全コピーではなく、復元・調査に必要な差分を保存する。

`machine_corrections`への修正提案保存および`machine_reports`への報告保存だけではrevisionを作成しない。
正式な公開データ変更が発生した時点で、その変更内容に対応するrevisionを作成する。

## 10. `machine_product_index/{indexId}`

検索専用の派生データ。Functionsが元データと同期し、クライアントは書き込めない。

| フィールド | 型 | 必須 |
|---|---|---:|
| machineId | string | ○ |
| productId | string | ○ |
| genreIds | array<string> | ○ |
| location | GeoPoint | ○ |
| geohash | string | ○ |
| evidenceType | string | ○ |
| availability | string | ○ |
| isActive | boolean | ○ |
| machineStatus | string | ○ |
| machineUpdatedAt | timestamp | ○ |
| updatedAt | timestamp | ○ |

`indexId`はMVPでは`{machineId}_{productId}`形式を使用する。

## 11. `machine_reports/{reportId}`

| フィールド | 型 | 必須 | 説明 |
|---|---|---:|---|
| machineId | string | ○ | 対象 |
| photoId | string/null |  | 対象写真 |
| category | string | ○ | 報告種別 |
| message | string/null |  | 補足 |
| requestId | string | ○ | 冪等性・追跡用 |
| status | string | ○ | new / reviewing / resolved / rejected |
| reportedBy | string | ○ | UID |
| createdAt | timestamp | ○ | 受付日時 |
| reviewedAt | timestamp/null |  | 審査日時 |
| reviewedBy | string/null |  | 管理者 |
| resolution | string/null |  | 対応結果 |

### category

```text
machineRemoved
duplicate
inaccessible
inappropriatePhoto
inappropriateText
other
```

基本情報の誤りは`submitMachineCorrection`、商品情報の誤りは`updateVendingMachineProducts`を使用し、
`wrongLocation` / `wrongManufacturer` / `wrongProducts`は報告カテゴリとして使用しない。

`submitMachineReport`の受付だけでは`vending_machines`、`machine_product_index`、`revisions`を変更しない。

### resolution例

```text
machineHidden
photoHidden
merged
noAction
```

## 12. `users/{uid}`

| フィールド | 型 | 必須 |
|---|---|---:|
| displayName | string/null |  |
| accountStatus | string | ○ |
| createdAt | timestamp | ○ |
| updatedAt | timestamp | ○ |
| lastActiveAt | timestamp/null |  |

`accountStatus`: active / restricted / suspended

## 13. `users/{uid}/favorite_products/{productId}`

| フィールド | 型 | 必須 |
|---|---|---:|
| productId | string | ○ |
| sortOrder | number | ○ |
| createdAt | timestamp | ○ |

Product IDをドキュメントIDにして重複を防ぐ。

## 14. フィードバック

既存の共通基盤を維持する。

### `feedback_items`

主なフィールド:

```text
appId
category
message
screen
stepsToReproduce
status
priority
uid
userDisplayName
replyRequested
appVersion
platform
locale
labels
attachments
isSpamSuspected
createdAt
updatedAt
```

### 固定値

- category: bug / request / usability / other
- status: new / reviewing / planned / done / closed

## 15. 旧形式互換

読み込み順:

1. v2サブコレクションが存在する場合はv2形式を使用。
2. 存在しない場合は旧`drinks`、`slots`等から変換。
3. 対応不能な商品名は未解決の表示用データとして保持。
4. 読み込みだけで旧データを書き換えない。

移行スクリプトは変換できる項目だけを新形式へ追加し、旧フィールドを即時削除しない。
