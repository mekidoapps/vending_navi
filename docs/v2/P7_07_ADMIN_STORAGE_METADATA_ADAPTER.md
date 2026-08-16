# P7-07 Admin Storage Metadata Adapter

> 日付: 2026-08-12
> 状態: Functions adapter実装

## 目的

P7-06のpure validation coreを、Firebase Admin Storageのbucket/file境界へ接続する。

本実装単位では画像bytesのdownloadやVertex AI呼び出しはまだ行わない。

## Path ownership

FunctionsはclientからStorage pathを受け取らない。

```text
authenticated uid
+
validated uploadId
↓
machine_uploads/{uid}/{uploadId}/original.jpg
```

をサーバー側で生成し、そのobjectだけを読む。

## Adapter contract

Admin SDKのbucketは構造的interfaceで受ける。

```text
StorageBucketLike
└ file(path)
   └ getMetadata()
```

productionではFirebase Admin Storageのbucketをそのまま渡せる形にする。
unit testではFakeBucket / FakeFileを使う。

## Error mapping

Storage providerの内部エラー詳細はclient向けcontractへ漏らさない。

```text
404
→ temporary-photo-not-found

その他のStorage metadata取得失敗
→ temporary-photo-storage-read-failed
```

取得できたmetadataはP7-06へ渡し、

```text
path
MIME
size
age
```

を再検証する。

## metadata.name

Storage metadataに`name`がある場合はexpected pathと一致することを検証する。

SDK/Fake等で`name`が省略された場合のみ、
サーバーが生成したexpected pathを使用する。

## 未実装

この段階ではまだ次を行わない。

- image bytes download
- Vertex AI実接続
- Storage Rules変更
- Callable export
- recognition session/idempotency

## 次段

次はverified objectからimage bytesを読み、
providerへ渡す境界を作る。

その後、

```text
temporary Storage
→ validation
→ image bytes
→ Vertex provider
→ Master resolution
```

を統合する。
