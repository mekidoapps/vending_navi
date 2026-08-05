# core

複数Featureから実際に共有される基盤コードを置く。

- `errors`: 共通失敗型
- `logging`: 個人情報を含めないログ
- `result`: 成功・失敗の共通表現
- `firebase`: Firebase依存の共通Providerや設定
- `ui`: 2機能以上で共有する共通Widget

将来使いそうという理由だけで、Feature固有コードをここへ移さない。
