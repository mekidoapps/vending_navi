# P7-08 Photo Bytes → Recognition Provider Boundary

> 日付: 2026-08-12
> 状態: Functions内部境界実装

## 目的

Storageのuid/uploadIdをAI providerへ渡さず、

```text
temporary Storage
→ metadata validation
→ bytes download
→ RecognitionProvider
```

という境界にする。

providerはStorage構造・Firebase uid・uploadIdを知らない。

## Photo content adapter

P7-06/P7-07で検証済みのmetadataに続いて、
同じexpected pathからbytesをdownloadする。

返却:

```text
objectPath
contentType = image/jpeg
bytes
```

download後も次を再確認する。

- bytesが空でない
- bytes.length == metadata size
- 5 MiBを超えない

Storage内部エラー詳細は外へ漏らさない。

## Provider contract変更

旧:

```text
recognize(uid, uploadId)
```

新:

```text
recognize(
  imageBytes,
  mimeType = image/jpeg
)
```

これによりVertex adapterはAI推論だけを担当し、
Storage ownership/securityはStorage adapter側へ閉じ込める。

## Recognition service

```text
loadPhoto(uid, uploadId)
loadCatalog()
        ↓
validated JPEG bytes
        ↓
RecognitionProvider
        ↓
Master resolution
        ↓
normalized response
```

temporary photo検証/読込に失敗した場合、
providerは呼び出さず`recognitionStatus = failed`へ落とす。

## 次段

次は本番provider adapterをFunctionsへ追加する。

```text
VertexRecognitionProvider
- @google/genai
- Vertex AI
- gemini-3.5-flash-lite
- global
- Structured Output
```

PoC prompt v2をproviderへ移植する。

その前にFunctions dependencyへ`@google/genai`を追加し、
SDKのproduction API shapeを固定する。
