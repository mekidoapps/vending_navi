> 文書状態: Phase 1 完了確認版  
> 更新日: 2026-08-06  
> 対象: 自販機ナビ / VendingNavi v2  
> パッケージID: `com.mekidoapps.vendingnavi`  
> リポジトリ: `mekidoapps/vending_navi`


# 変更履歴

## 2026-08-06 - Phase 1 共通基盤

### 追加

- Phase 0仕様書・実装計画・現行リポジトリ監査
- Riverpod 3、go_router、Freezed、json_serializable、build_runnerの依存関係
- Feature-first＋レイヤード構成のv2骨格
- Firebase／App Check初期化を分離したBootstrap
- アプリ最上位の`ProviderScope`
- `APP_ENTRY=legacy|v2`による起動切替
- legacy互換ルートとv2基盤確認ルート
- v2用カラー、余白、角丸、影、テーマ
- 第一・第二ボタン、地図アクション、状態ラベル、Loading／Empty／Error UI
- 共通`AppFailure`、`AppResult<T>`、例外Mapper
- 個人情報を記録しない共通ログ基盤
- 本番設定から分離した`firebase.v2.json`
- deny-by-defaultのv2 Firestore／Storage Rules
- Auth／Firestore／Functions／Storage Emulator接続基盤
- TypeScript Functions管理領域とEmulatorヘルスチェック
- Bootstrap、ルーター、テーマ、Failure、Result、ログ、UI、Emulatorのテスト
- 文字拡大、直接パス、戻る操作、必須ファイル契約の品質テスト
- Phase 1自動品質ゲート

### 方針

- 通常起動は現行版を維持する。
- v2は明示的な`APP_ENTRY=v2`で起動する。
- 既存v1コードのAnalyzer警告は別コミットで扱い、Phase 1基盤変更と混在させない。
- Phase 1では業務Functionや本番Rulesを公開しない。
- 本番Firebaseへのdeployは行わない。

## 2026-08-04 - Phase 0 正式文書初版

### 追加

- v2のコンセプト、対象ユーザー、MVP範囲
- 全面地図ホームと右下3ボタン
- 左へ展開する検索パネル
- 固有商品・ジャンル・よく飲む商品検索
- 固定吹き出しと独立詳細画面
- 写真登録・メーカー簡単登録
- AI候補のユーザー確認と失敗時フォールバック
- 確認済み／推定／古い情報の区別
- コミュニティ共同更新、履歴、報告
- `machine_product_index`
- Callable Functions経由の書き込み
- 一時Storage方式
- Feature-first＋レイヤードMVVM
- Riverpod 3、go_router、Freezed、json_serializable
- テスト計画と実装フェーズ
- 仕様変更ルール

### 変更

- 現行の一画面集約から、地図＋必要時パネル＋独立詳細へ変更
- 商品文字列中心からProduct ID中心へ変更
- 自販機登録フォームから段階式フローへ変更
- 作成者編集期限から共同更新・高影響提案方式へ変更
- AIを自動確定ではなく入力補助へ変更
- 写真を正式領域へ直接保存せず一時領域経由へ変更

### MVP対象外へ移動

- チェックイン
- 経験値、レベル、称号
- 通知
- 広告、プレミアム
- 気分・タグ検索
- 棚スロット
- Appleログイン
- 専用管理UI
- 編集期限

### 保留

- 検索半径、重複距離、鮮度期間
- AIサービスと費用
- 一時画像期限・上限
- 初期商品・メーカーマスタ
- 複数テーマ・メーカー色ピン
