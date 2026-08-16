# P7-05 Recognition Core + Fake Provider

> 日付: 2026-08-12
> 状態: Callable接続前のpure core

## 目的

`recognizeVendingMachinePhoto` Callableを公開する前に、

```text
request validation
provider boundary
Master resolution
normalized response
AI失敗fallback
```

をFirebase transportから分離してunit testする。

## Request

P7-02契約に従い、認識リクエストIDとupload IDは別UUID v4とする。

```json
{
  "recognitionRequestId": "uuid-v4",
  "uploadId": "uuid-v4"
}
```

clientはprovider/modelを指定できない。

同じ分析のretryでは同じ`recognitionRequestId`を使う。
意図的な再解析では新しい`recognitionRequestId`を使う。

## Provider boundary

```text
RecognitionProvider
└ recognize(uid, uploadId)
   ├ machineManufacturerLabels
   ├ productLabels
   └ unresolvedLabels
```

MVP production providerはP7-03で決定した:

```text
Google Cloud Vertex AI
gemini-3.5-flash-lite
providerKey = vertex_gemini_3_5_flash_lite
```

この段階では実Vertexを接続せずFake providerでcoreを検証する。

## Normalized response

```json
{
  "manufacturerCandidates": [
    {"manufacturerId": "asahi"}
  ],
  "productCandidates": [
    {"productId": "otsuka_pocari_sweat"}
  ],
  "unresolvedLabels": [],
  "recognitionStatus": "completed"
}
```

数値confidenceは公開contractへ含めない。

`completed`は「全商品が解決できた」という意味ではない。
部分成功は`completed + unresolvedLabels`で表す。

## Failure

providerまたはMaster lookupが失敗しても、coreは次を返せる。

```json
{
  "manufacturerCandidates": [],
  "productCandidates": [],
  "unresolvedLabels": [],
  "recognitionStatus": "failed"
}
```

これによりAI障害を登録全体の障害にしない。
Flutterは手動・メーカー簡単登録・撮り直し等へ継続できる。

## 未接続

この段階ではまだ次を行わない。

- `functions/src/index.ts`からCallable export
- Firebase Storage temporary photo validation
- recognition request idempotency
- recognition session Firestore保存
- Vertex AI実接続
- App Check enforcement

次段では一時Storageの所有者・MIME・5 MiB・24時間制限をFunctions側で検証する境界を作る。
