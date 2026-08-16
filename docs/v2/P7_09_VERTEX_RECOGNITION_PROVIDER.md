# P7-09 Vertex Recognition Provider

> 日付: 2026-08-12
> 状態: Functions production provider adapter実装

## MVP固定値

```text
Provider: Google Cloud Vertex AI
SDK: @google/genai 2.16.0
Model: gemini-3.5-flash-lite
Location: global
API version: v1
recognitionProvider: vertex_gemini_3_5_flash_lite
Prompt: P7-03 prompt v2
```

## 認証

API keyをコード・環境変数へ保存しない。

ローカル:
Application Default Credentials

Firebase Functions production:
Google Cloud service identity / Application Default Credentials

## Provider責務

入力:

```text
validated JPEG bytes
image/jpeg
```

出力:

```text
machineManufacturerLabels[]
productLabels[]
unresolvedLabels[]
```

Storage path、uid、uploadId、Product ID、Manufacturer IDをproviderへ渡さない。

## Structured Output

VertexへJSON schemaを渡す。

```text
machineManufacturerLabels: max 3
productLabels: max 40
unresolvedLabels: max 40
```

公開contractに数値confidenceを含めない。

AIレスポンスはFunctions側でも再parse・field validationする。
unknown field、非string、過大な配列、空label等はprovider failureとする。

raw AI responseやbase64 imageをログ・Firestoreへ保存しない。

## Project ID

production factoryは以下の順にproject IDを解決する。

```text
GCLOUD_PROJECT
GOOGLE_CLOUD_PROJECT
```

clientからproject/model/providerを指定させない。

## 失敗

SDK/API内部のerror detailをRecognitionProvider外へ漏らさない。

provider failureはP7-05 Recognition Serviceで、

```text
recognitionStatus = failed
```

へ変換できる。

## 未決定 / 次段

OI-006のうち、次はCallable統合時に固定する。

- server-side timeout
- recognition request idempotency
- recognition session lifecycle
- per-user abuse/cost control

次は`recognizeVendingMachinePhoto` CallableをFake/production dependency injection可能な形で作り、
Storage・Master・Vertex providerを結線する。
