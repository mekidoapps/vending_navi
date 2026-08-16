# P7-03 Vertex AI Photo Recognition PoC

Phase 7のprovider選定用の隔離PoCです。本番Functionsにはまだ接続しません。

## 前提

- Node.js 20以上
- Google Cloud project: `vendingnavi`
- Vertex AI API有効
- ADC (`gcloud auth application-default login`)
- 課金アカウントが利用可能
- JPEG 5 MiB以下

## Install

```bash
cd ~/vending_app/tools/p7_vertex_poc
npm install
```

## Run

Git BashではWindowsパスを`C:/...`形式で渡せます。

```bash
npm run recognize -- "C:/Users/domek/Pictures/vending_test.jpg"
```

default:

```text
project  = vendingnavi
location = global
model    = gemini-3.5-flash-lite
```

比較用にモデルだけ差し替えられます。

```bash
VENDING_POC_MODEL=gemini-3.5-flash npm run recognize -- "C:/Users/domek/Pictures/vending_test.jpg"
```

## Output

PoCではProduct IDへまだ変換せず、providerが画像から読み取った候補ラベルだけをJSONで確認します。

```json
{
  "manufacturerLabels": [],
  "productLabels": [],
  "unresolvedLabels": [],
  "notes": []
}
```

数値confidenceはP7のFlutter contractへ持ち込まないため、PoCにも含めません。

## Safety

- API keyをファイルへ保存しません。ADCを使います。
- 画像base64やAI生レスポンスをファイルへ保存しません。
- 本番Firestore / Storageへ書き込みません。
- このPoC結果を公開データとして扱いません。
