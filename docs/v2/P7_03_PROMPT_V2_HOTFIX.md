# P7-03 Prompt v2 Hotfix

写真認識PoCの出力境界を修正する。

変更点:

- `manufacturerLabels`を`machineManufacturerLabels`へ変更。
- 自販機本体のメーカーと商品ブランドを明確に分離。
- 日本語商品名は日本語のまま返すよう指定。
- 翻訳・ローマ字化を禁止。
- メーカーや色からの商品推測を禁止。
- 不確実なラベルは`unresolvedLabels`へ送る。
- 数値confidenceは引き続き使用しない。

同じ実写写真を`gemini-3.5-flash-lite`で再試験し、改善度を確認する。
