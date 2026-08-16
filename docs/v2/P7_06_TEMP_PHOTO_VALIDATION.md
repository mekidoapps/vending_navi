# P7-06 一時写真サーバー検証

> 日付: 2026-08-12
> 状態: pure validation core

## 目的

AIへ画像を渡す前に、認証済みユーザーの一時Storage画像が
P7-02契約を満たしていることをFunctions側でも検証する。

## 固定path

```text
machine_uploads/{uid}/{uploadId}/original.jpg
```

pathはclient入力として受け取らない。

Functionsは、

```text
authenticated uid
+
validated uploadId
```

から必ず生成する。

これにより別uid/別uploadIdのobjectを指定させない。

## サーバー検証

Storage object metadataについて次を確認する。

```text
objectPath   = expected path
contentType  = image/jpeg
size         = 1..5 MiB
timeCreated  = server metadata
age          <= 24 hours
```

5 MiBちょうど、24時間ちょうどは有効。

24時間を1 msでも超えたものはexpired。

## original.jpgの意味

`original.jpg`はカメラの未加工raw原本ではなく、
P7-02で固定したアプリ正規化後のJPEGを意味する。

```text
JPEG
long side <= 2048 px
quality = 85
<= 5 MiB
```

Functions metadataだけでは画像のpixel dimensionやJPEG qualityは証明できない。
2048 px / quality 85はFlutter upload側で保証し、
Functions側はMIME/size/age/pathを再検証する。

必要になれば将来画像decodeによるdimension validationを追加できるが、
MVPでは必須にしない。

## Error boundary

pure coreでは詳細codeを持つ。

```text
temporary-photo-path-invalid
temporary-photo-content-type-invalid
temporary-photo-size-invalid
temporary-photo-too-large
temporary-photo-created-at-invalid
temporary-photo-expired
```

Callableではこれらを安全なappCodeへ変換する。

AI失敗と異なり、別ユーザーpathや不正ファイルは認識処理を開始しない。

## Storage Rules

この実装単位では`firebase/v2/storage.rules`はまだ変更しない。

client一時uploadを実装する段階で、

```text
auth required
uid == path uid
image/jpeg
<= 5 MiB
create only / overwrite禁止
own temporary read
formal path client write禁止
```

をRules test付きで開放する。

## 次段

次はAdmin Storage adapterを作り、

```text
uid + uploadId
↓
expected object path
↓
Storage metadata/read
↓
temporary photo validation
↓
RecognitionProvider
```

へ接続する。
