# P7-03 Vertex AI 写真認識PoC

> 日付: 2026-08-12
> 状態: MVP採用決定

## 目的

写真1枚から、後段のManufacturer / Product master照合へ渡せる候補ラベルをStructured JSONで取得できるか確認する。

本段階では本番Functions・Firestore・Storageへ接続しない。

## 第一候補

```text
Provider: Google Cloud Vertex AI
SDK: @google/genai 2.16.0
Model: gemini-3.5-flash-lite
Location: global
API version: v1
```

比較対象:

```text
gemini-3.5-flash
```

## PoC出力

```text
machineManufacturerLabels
productLabels
unresolvedLabels
notes
```

AIの数値confidenceはP7 Domain Contractへ採用しない。

## 判定

実写で最低限次を確認してからproviderを固定する。

- メーカー名を候補として取れる
- 主要商品名を1件以上取れるケースがある
- 読めない商品を無理に確定せずunresolvedへ逃がせる
- Structured JSONが安定してparseできる
- Flash-Liteで不足するケースをFlashと比較できる
- API失敗時にエラー分類できる

## 次段

PoC成立後、P7-04でManufacturer / Product master照合ロジックをFake providerから実装する。
provider接続はFunctions内部のadapter境界に閉じ込める。

## PoC結果・MVP採用決定

2026-08-12、同一の実写自販機写真をPrompt v2で比較した。

### gemini-3.5-flash-lite

- machineManufacturerLabels: Asahi
- 複数ブランドの商品候補を抽出
- 日本語商品名を概ね維持
- 「ドデカミン ストロング」を候補として抽出
- Structured JSON正常

### gemini-3.5-flash

- machineManufacturerLabels: Asahi
- 一部の商品名はFlash-Liteより詳細
- 一方、「ドデカミン ストロング」を「デカビタC ストロング」と別商品へ誤認するケースを確認
- Structured JSON正常

### MVP決定

```text
Provider: Google Cloud Vertex AI
Model: gemini-3.5-flash-lite
Prompt: v2
Location: global
SDK: @google/genai
```

Flashへの自動fallbackはMVPでは実装しない。

理由:

- Flash-Liteで候補生成用途として十分な結果が得られた
- 上位モデルでも誤認がなくなるわけではない
- AI結果はユーザー確認前に公開しない
- AI失敗時には再解析・撮り直し・手動・メーカー簡単登録の代替経路がある
- コストと処理複雑性を抑える

実写真30〜50枚による最終評価はPhase 10まで継続する。

## recognitionProvider

MVPの保存値は次とする。

```text
vertex_gemini_3_5_flash_lite
```

モデル変更時に既存写真の認識元を識別できるよう、providerだけでなくモデル系列まで含める。
