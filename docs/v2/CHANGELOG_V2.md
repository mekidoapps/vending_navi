> 文書状態: Phase 0 正式版（実装前基準）  
> 更新日: 2026-08-04  
> 対象: 自販機ナビ / VendingNavi v2  
> パッケージID: `com.mekidoapps.vendingnavi`  
> リポジトリ: `mekidoapps/vending_navi`


# 変更履歴

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

## 2026-08-05

### 追加

- 公開GitHubリポジトリの一次監査を行い、`REPOSITORY_AUDIT_V1.md`を追加。
- Flutter画面、モデル、Service、Widget、Firebase設定を、再利用・改修再利用・作り直し・MVP保留・要確認に分類。
- FunctionsソースとStorage Rulesが公開リポジトリで確認できない点、直接Firestore書き込み、テスト不足を着手前リスクとして記録。

### 追加（Phase 1計画）

- `PHASE1_BOOTSTRAP_PLAN_V2.md`を追加。
- Phase 1を8コミットに分割し、現行画面を維持したままRiverpod、go_router、Freezed、v2テーマ、共通エラー、Emulator基盤を導入する計画を定義。
- 現行`firebase.json`と`firestore.rules`をPhase 1では変更せず、`firebase.v2.json`とdeny-by-defaultのv2 Rulesを追加する安全策を定義。
- 公開リポジトリにFunctionsとStorage Rulesがないため、v2用の空基盤を新設し、既存資産が見つかった場合に監査後統合する方針を追加。
