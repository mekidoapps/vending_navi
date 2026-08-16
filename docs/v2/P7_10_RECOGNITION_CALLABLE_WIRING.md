# P7-10 recognizeVendingMachinePhoto Callable Wiring

> 日付: 2026-08-12
> 状態: Functions結線

## 経路

```text
Authenticated Callable
↓
request validation
↓
recognitionRequestId idempotency reservation
↓
temporary Storage metadata + JPEG bytes validation
↓
VertexRecognitionProvider
↓
Firestore active Master lookup
↓
MasterLabelResolver
↓
normalized response
↓
request dedupe result + private recognition session
```

## Callable

```text
recognizeVendingMachinePhoto
```

設定:

```text
auth required
App Check enforcement = false (P9で有効化予定)
timeoutSeconds = 60
```

## Idempotency

key:

```text
uid + recognitionRequestId + recognizeVendingMachinePhoto
```

同じrequest IDの再送は保存済みresponseを返し、
新しいAI呼び出しを行わない。

同一requestがprocessing中の場合は、

```text
appCode = recognition-in-progress
```

で終了する。

processingが2分以上更新されていない場合のみstale reservationとして再取得可能にする。
Cloud Functions timeout等でprocessingのまま残った場合の復旧用。

## Recognition session

private collection:

```text
photo_recognition_sessions/{sha256(uid + uploadId)}
```

保存するのは最小限:

```text
uid
uploadId
status
provider
manufacturerCandidateIds
productCandidateIds
recognizedAt
expiresAt
```

raw AI response、画像base64、prompt、numeric confidenceは保存しない。

session TTLは認識完了から24時間。
後続の`createVendingMachine` photo routeで、
userが確定したIDがAI候補だったかをサーバー側で判定する材料にする。

## Multiple-brand vending machine

machine manufacturer candidateとproduct candidateは独立。

```text
machine = asahi
product = otsuka_pocari_sweat
```

は正常。

## 次段

1. emulatorでCallable idempotency/sessionを確認
2. Storage Rulesをtemporary uploadだけ開放
3. Flutter camera/normalization/upload
4. 実端末からCallable E2E

その後photo create routeへ接続する。
