> 文書状態: Phase 3 実装中（P3-02完了）  
> 更新日: 2026-08-07  
> 対象: 自販機ナビ / VendingNavi v2  
> パッケージID: `com.mekidoapps.vendingnavi`  
> リポジトリ: `mekidoapps/vending_navi`


# 実装計画

## Phase 0: 文書固定・監査準備

### 作業

- 本ドキュメント一式をリポジトリへ配置
- 現行コード・Functions・Rules・依存関係の監査
- Firebase環境の確認
- 本番データバックアップ
- 現行安定タグ・ブランチ確認
- 未確定事項の優先順位付け

### 完了条件

- 実装時の参照文書が揃う
- 現行版へ戻せる
- 復元方法が確認できる
- MVP対象外が明確

## Phase 1: 共通基盤（完了確認）

- [x] Feature-first構造
- [x] Riverpod 3
- [x] go_router
- [x] Freezed / json_serializable / build_runner
- [x] Firebase初期化のBootstrap分離
- [x] 本番設定から分離したFirebase Emulator構成
- [x] AppFailure / AppResult / FailureMapper
- [x] プライバシー安全なログ
- [x] v2デザインシステム
- [x] 共通UI
- [x] Firebase SDK Provider
- [x] legacy / v2起動切替
- [x] deny-by-default RulesとFunctions管理領域
- [x] 自動品質ゲートとWidget／単体テスト

**完了判定:** `PHASE1_QUALITY_GATE.md`と`PHASE1_COMPLETION_REPORT.md`に従い、自動ゲート、legacy／v2実機起動、Emulator分離接続、タグ作成を確認する。既存v1のAnalyzer warning／infoは別コミットで扱い、v2追加範囲をstrict analyzeする。

## Phase 2: マスタ・旧データ互換

- [x] P2-01 Product ID／Manufacturer ID規約
- [x] P2-01 Product／Manufacturer Domain Model
- [x] P2-01 固定ジャンルenum
- [x] P2-02 Firestore DTO／Mapper
- [x] P2-03 v1自販機・旧商品文字列の互換Mapper
- [x] P2-04 Product／Manufacturer Repositoryと固定fixture
- [x] P2-05 Emulator seed・Phase 2品質ゲート

**完了:** 旧・新を同一Domainで取得し、対応不能商品でもクラッシュしない。

## Phase 3: ホーム地図・通常閲覧

- [x] P3-01 自販機Domain／DTO／Mapper
- [x] P3-02 Repository・v1/v2互換読取・Emulator read
- [ ] P3-03 現在地Service／Controller
- [ ] P3-04 全面HomeMapScreen
- [ ] P3-05 周辺自販機・状態ピン
- [ ] P3-06 固定吹き出し・詳細
- [ ] P3-07 外部経路・Phase 3品質ゲート

**完了条件:** 起動→周辺→ピン→吹き出し→詳細→経路が実機で成立。

## Phase 4: 商品検索

1. 商品検索
2. Product候補
3. `machine_product_index`
4. 選択中ラベル
5. 検索解除
6. ジャンル
7. よく飲む商品
8. 検索対象の詳細優先表示

**完了:** 商品・ジャンル検索が地図・吹き出し・詳細まで成立。

## Phase 5: 認証・ユーザー

- メール・Googleログイン
- ログアウト
- 初回user作成
- 中断フロー復帰
- よく飲む商品
- MVPマイページ
- accountStatus処理
- フィードバック導線

**完了:** 未ログイン閲覧、ログイン後復帰、本人データ保護が成立。

## Phase 6: メーカー簡単登録

1. 登録開始
2. ログイン
3. 位置調整
4. 重複候補
5. 方法選択
6. メーカー選択
7. 推定表示
8. 最終確認
9. createVendingMachine
10. 詳細・検索反映

**完了:** メーカー不明・位置のみを含め、確実な非AI登録ルートが成立。

## Phase 7: 写真AI登録

1. 撮影案内
2. カメラ
3. 一時Storage
4. AI認識
5. ID照合
6. 候補編集
7. 最終確認
8. 正式保存
9. 一時画像整理

**完了:** 成功・部分成功・失敗の全ルートで登録を完了できる。

## Phase 8: 更新・報告

1. 手動商品更新
2. 売り切れ
3. 推定→確認済み
4. 写真追加
5. 写真一括更新
6. 基本情報修正提案
7. 状態報告
8. Firebase Console運用

**完了:** 履歴・index・更新日時が整合し、報告が自動非表示を起こさない。

## Phase 9: セキュリティ最終化

- Firestore / Storage Rules
- Functions共通チェック
- App Check強制
- Rate limit
- accountStatus
- 冪等性
- 一時画像削除
- ログのプライバシー確認
- Emulator権限テスト

**完了:** 不正な直接書込・他人データアクセス・重複処理を拒否できる。

## Phase 10: 全体統合

- 全必須シナリオ
- 旧新混在
- 小型・基準・大型画面
- AI実写真評価
- P0/P1修正
- デザイン実機調整

## Phase 11: クローズドテスト

### 第1サイクル

- 検索の理解
- 3ボタンの理解
- 確認済み／あるかもの理解
- 登録負担
- AIの補助価値
- 0件時の次行動

### 修正

- P0/P1必須修正
- 複数人が迷ったUXをP2以上として修正
- MVP外機能は追加しない

### 第2サイクル

- 回帰
- 異なる端末
- リリース候補判定

## 共通Definition of Ready

- 目的
- 画面仕様
- 入出力
- 保存先
- エラー時動作
- ログイン要否
- テスト項目
- 実装を妨げる未確定事項なし
- MVP対象

## 共通Definition of Done

- 実装
- 静的解析
- 単体テスト
- Widgetテスト
- 必要なEmulatorテスト
- Pixel 6a実機
- 回帰
- 仕様書更新
- CHANGELOG更新
- Gitコミット

## 作業単位

1つの変更は1つの目的に限定する。ホーム、登録、データ構造、テーマを一つの変更で同時に作り直さない。
