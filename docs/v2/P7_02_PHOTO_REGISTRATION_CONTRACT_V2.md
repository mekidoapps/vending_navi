# P7-02 写真AI登録 Contract v2

> 対象: 自販機ナビ / VendingNavi v2
> Phase: 7 写真AI登録
> 状態: P7-02 固定
> 日付: 2026-08-12

## 1. 目的

Phase 7では、Phase 6で成立した非AI登録ルートを壊さずに、

```text
撮影
→ 本人専用一時Storage
→ AI認識
→ Product / Manufacturer master ID照合
→ ユーザー確認・修正
→ createVendingMachine
→ 正式写真・公開データ反映
```

を追加する。

AI結果は候補であり、ユーザーが確認する前に公開自販機・商品データへ保存しない。

## 2. Phase 7で維持する原則

- 写真登録はログイン必須。
- 公開自販機データへの書き込みはCallable Functions経由。
- 一時写真だけ本人専用Storageへクライアントから直接アップロードする。
- AI生レスポンスをFirestore・ログへ保存しない。
- `recognitionProvider`、`evidenceType`、`manufacturerStatus`はクライアント指定値を信用しない。
- AI認識失敗を自販機登録全体の失敗にしない。
- Phase 6のmanufacturer / locationOnly routeを継続利用可能にする。
- App Check強制はPhase 9で行う。

## 3. 写真入力

新規自販機登録1回につきPhase 7では写真1枚を扱う。

アップロード前に次へ正規化する。

```text
形式: JPEG
長辺最大: 2048 px
JPEG quality: 85
最大ファイルサイズ: 5 MiB
```

正式保存する`original.jpg`は端末カメラの未加工フル解像度原本ではなく、
VendingNaviが上記条件へ正規化したアップロード画像を指す。

P7-02 Contractは画像の取得元には依存しない。
production UIはまずカメラ撮影を成立させ、ギャラリー対応はOI-018として別途決定する。

## 4. 一時Storage

写真ごとにUUID v4 `uploadId`を生成する。
createVendingMachine用`requestId`とは別物とする。

再撮影時は新しい`uploadId`を生成する。

```text
machine_uploads/{uid}/{uploadId}/original.jpg
```

制約:

```text
Authentication必須
path uid == request.auth.uid
contentType == image/jpeg
size <= 5 MiB
同一path上書き禁止
他人read禁止
本人のみread可
client metadata update禁止
clientから正式領域write禁止
```

一時画像の有効期限は24時間。
FunctionsはStorage objectのserver-side作成時刻で期限を検証する。

## 5. AI認識requestId

AI認識操作にはcreateVendingMachineとは別のUUID v4 `recognitionRequestId`を使用する。

```text
uid + recognitionRequestId + recognizeVendingMachinePhoto
```

を冪等性キーとする。

- 通信再試行: 同じrecognitionRequestId
- 意図した再解析: 新recognitionRequestId
- 再撮影: 新uploadId + 新recognitionRequestId

## 6. recognizeVendingMachinePhoto

input:

```json
{
  "requestId": "recognition request UUID v4",
  "uploadId": "temporary upload UUID v4"
}
```

server validation:

```text
Authentication
accountStatus
input schema
UUID
一時object存在
owner path
MIME
size
24時間以内
requestId冪等性
AI呼び出し上限
```

処理:

```text
一時画像
→ AI provider
→ provider response parser
→ Manufacturer/Product master照合
→ 無効ID除外
→ 重複除外
→ normalized result
```

response:

```json
{
  "manufacturerCandidates": [
    {"manufacturerId": "coca_cola"}
  ],
  "productCandidates": [
    {"productId": "ayataka_regular"}
  ],
  "unresolvedLabels": [],
  "recognitionStatus": "completed"
}
```

statusは既存enumを維持する。

```text
notRequested
processing
completed
failed
```

部分成功は新statusを増やさず、
`completed`かつ`unresolvedLabels`ありで表す。

MVPではprovider固有の数値confidenceをUI契約にしない。
候補順序だけserver側で有用そうな順に正規化してよい。

## 7. Server-side recognition session

create時の信頼性判定に必要な最小情報だけをAdmin専用Firestoreへ保存する。

```text
photo_recognition_sessions/{sessionId}
```

`sessionId`は`uid + uploadId`からserver側で決定論的に生成する。

保存候補:

```text
uid
uploadId
recognitionStatus
recognitionProvider
manufacturerCandidateIds
productCandidateIds
recognizedAt
expiresAt
```

保存しない:

```text
AI生レスポンス
画像内容
一時download URL
詳細prompt
providerの生confidence一式
```

clientからこのcollectionを直接read/writeさせない。

## 8. AI provider境界

P7-02ではAI providerをDomain contractへ固定しない。

```text
PhotoRecognitionProvider
  recognize(image) -> ProviderRecognitionResponse

ProviderRecognitionMapper
  ProviderRecognitionResponse
  -> normalized candidate IDs
```

`recognitionProvider`はFunctionsだけが設定する。

OI-006のprovider / model / 費用 / timeout / 画像保持条件はP7-03 PoCで固定する。

## 9. 候補確認UI

ユーザーができること:

```text
メーカー候補を採用
メーカー候補を変更
メーカー不明
商品候補を採用
誤候補を外す
Product masterから商品を追加
候補が空でも続行
AI失敗後に手動選択
メーカー簡単登録へ切替
位置のみ登録へ切替
撮り直し
```

AI候補の自動確定保存は禁止。

## 10. MachineRegistrationDraft

Phase 6のfieldを継続利用する。

```text
requestId
location
registrationMethod
name
manufacturerId
confirmedProductIds
temporaryPhotoUploadId
placeDescription
installationType
```

photo route:

```text
registrationMethod = photo
temporaryPhotoUploadId = uploadId
```

を必須とする。

`confirmedProductIds`には最終的にユーザーが採用したProduct IDだけを保持する。

## 11. photo routeの保存可否

Phase 7以降のphoto submission ready条件:

```text
requestIdあり
locationあり
registrationMethod == photo
temporaryPhotoUploadIdあり
```

manufacturerIdはnull可。
confirmedProductIdsは空でもよい。

AI結果が空・部分成功でも続行できる。
AI認識failedでも、ユーザーが写真を見ながら手動確認したうえでphoto routeを続行できる。

manufacturer/locationOnlyへ切り替えた場合はtemporaryPhotoUploadIdをdraftから外す。
不要な一時画像はcleanup対象とする。

## 12. createVendingMachine input

Phase 6で固定した外部shapeを維持する。

```json
{
  "requestId": "uuid",
  "registrationMethod": "photo|manufacturer|locationOnly",
  "location": {"latitude": 0, "longitude": 0},
  "name": "string|null",
  "manufacturerId": "string|null",
  "confirmedProductIds": ["productId"],
  "temporaryPhotoUploadId": "string|null",
  "placeDescription": "string|null",
  "installationType": "outdoor|indoor|unknown"
}
```

clientから次は送信しない。

```text
evidenceType
manufacturerStatus
recognitionProvider
recognitionStatus
storagePath
photoId
primaryPhotoId
```

## 13. photo route server validation

createVendingMachineでphoto routeを受けた場合:

```text
temporaryPhotoUploadId必須
本人一時画像
JPEG / 5 MiB以下
24時間以内
recognition session存在
recognitionStatusがcompletedまたはfailed
processingは拒否
Manufacturer/Product IDをactive masterで再検証
confirmedProductIdsをdedupe
```

## 14. manufacturerStatus

selected manufacturerIdがserver-side recognition sessionの候補に含まれる場合:

```text
recognized_and_confirmed
```

manufacturerIdはあるがAI候補と一致しない場合:

```text
confirmed
```

manufacturerIdがnull:

```text
unknown
```

## 15. Product evidenceType

confirmedProductIdがserver-side recognition sessionの候補に含まれる場合:

```text
photo_confirmed
```

AI候補にはなく、ユーザーがProduct masterから追加した場合:

```text
manual_confirmed
```

AI失敗時に手動選択した商品も`manual_confirmed`とする。

## 16. availability

photo registrationでユーザーが確認した商品:

```text
availability = available
isActive = true
confirmedBy = uid
confirmedAt = server timestamp
```

AI未確認候補は保存しない。

## 17. dataLevel

既存enumを増やさない。

```text
confirmedProductIdsあり
→ productsConfirmed

confirmedProductIdsなし + manufacturerIdあり
→ manufacturerOnly

confirmedProductIdsなし + manufacturerIdなし
→ locationOnly
```

## 18. 正式Storage

photoIdはserver生成。

```text
vending_machines/{machineId}/{photoId}/original.jpg
```

Phase 7 MVPではthumbnailを生成しない。

```text
thumbnailPath = null
```

正式写真最大枚数は1自販機5枚。
Phase 7新規登録では1枚だけ作成し、Phase 8写真追加も同じ上限を使う。

## 19. photo document

```text
storagePath
thumbnailPath = null
status = active
uploadedBy = uid
uploadedAt = server timestamp
recognitionStatus = recognition session status
recognitionProvider = server-side provider value
isPrimary = true
```

machine root:

```text
primaryPhotoId = photoId
```

## 20. revision

```text
updateType = machineCreated
source = photoRecognition
updatedBy = uid
updatedAt = server timestamp
requestId = create requestId
```

## 21. machine_product_index

ユーザーが確定した商品だけindexへ作成する。

AI候補として出ただけで外されたProduct IDはindexへ入れない。

## 22. 正式写真read

正式写真はclient write不可。

Storage RulesからFirestore公開状態を確認する。

概念条件:

```text
parent vending machine が公開対象
かつ
photos/{photoId}.status == active
```

参照するFirestore documentは:

```text
vending_machines/{machineId}
vending_machines/{machineId}/photos/{photoId}
```

の2件以内とする。

## 23. Storage finalizationと再試行

Storage操作はFirestore transaction外なので、
photo createではserver-side operation recordを状態付きで利用する。

```text
uid + requestId + createVendingMachine
```

photo routeではoperation recordに:

```text
machineId
photoId
status
```

を予約する。

概念フロー:

```text
1. idempotency operationをclaim
2. machineId / photoIdを予約
3. temp object検証
4. temp → formal pathへAdmin copy
5. Firestore transaction
   - vending machine
   - products
   - photo
   - revision
   - machine_product_index
   - operation completed result
6. temp delete best effort
```

retryでは同じreserved machineId/photoIdを再利用する。

期限切れ・孤立object cleanupはPhase 9で最終化する。

## 24. AI失敗時

UI:

```text
うまく読み取れませんでした
```

選択肢:

```text
もう一度解析
撮り直す
写真を見ながら手動で選ぶ
メーカーから簡単登録
メーカー不明で登録
```

認識失敗だけで位置・create requestId・入力済み項目を破棄しない。

手動photo fallback:

```text
registrationMethod = photo
recognitionStatus = failed
selected products = manual_confirmed
```

として登録可能にする。

## 25. 一時画像cleanup

正常完了後はtemp objectをbest effortで削除する。
削除失敗はcreateVendingMachine全体の失敗にしない。

cancel / route switch時の即時削除は必須にせず、24時間cleanup対象とする。

Phase 9で:

```text
期限切れmachine_uploads
参照されない孤立formal object
processingのまま期限超過したoperation
```

を整理する。

## 26. OI-007 決定

```text
一時画像最大サイズ: 5 MiB
最大解像度: 長辺2048 px
JPEG quality: 85
MIME: image/jpeg
一時保存期限: 24時間
新規登録写真: 1枚
正式写真最大: 5枚 / machine
thumbnail: MVPでは生成しない
正式配信: Firestore公開状態を参照するStorage Rules
```

## 27. OI-006

AI providerはP7-03 PoCで固定する。

比較対象:

```text
API / model
画像入力方式
structured output
ID照合のしやすさ
timeout
1回費用
rate limit
画像保持・学習利用条件
Fake差し替え
recognitionProvider wire value
```

Provider変更でFlutter Domain Contractが変わらないことを前提とする。

## 28. OI-018

ギャラリー画像選択は未決のまま維持する。

Phase 7 production最初の成立条件は現地カメラ撮影。
ギャラリー対応がなくても写真AI登録のDone条件は満たせる。

## 29. P7-03へ渡すもの

P7-03ではAI provider PoCを行い、次を固定する。

```text
provider
model
timeout
provider request
provider response parser
structured response schema
recognitionProvider wire value
失敗分類
費用上限方針
画像保持・学習利用条件
```

Storage / Flutter / createVendingMachineの外部ContractはP7-02を維持する。
