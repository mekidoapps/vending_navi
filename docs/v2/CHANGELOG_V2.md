> 文書状態: Phase 2 実装中  
> 更新日: 2026-08-06  
> 対象: 自販機ナビ / VendingNavi v2  
> パッケージID: `com.mekidoapps.vendingnavi`  
> リポジトリ: `mekidoapps/vending_navi`


# 変更履歴

## 2026-08-06 - Phase 2 P2-02 Firestore DTO／Mapper

### 追加

- Product／ManufacturerのFirestore DTO
- Firestore TimestampとUTC DateTimeの変換
- ドキュメントIDを本文から分離するDTO境界
- DTOからDomainへの検証・正規化Mapper
- 不正ID、未知ジャンル、必須値欠損をValidationFailureへ変換する処理
- DTO往復、Timestamp、Mapper失敗経路の単体テスト
- Firestoreマスタ変換規約

### 方針

- 未知ジャンルを`other`へ自動補正しない。
- 不正なFirestore文書を例外のまま画面へ流さない。
- `toFirestoreData()`はfixture・移行・テスト用とし、公開マスタのクライアント直接書き込みには使わない。
- 旧商品文字列の未解決表現はP2-03へ分離する。

## 2026-08-06 - Phase 2 P2-01 マスタDomain

### 追加

- Product ID／Manufacturer IDの小文字snake_case規約
- Product IDを`{manufacturerId}_{productSlug}`とする原則
- Product／ManufacturerのFreezed Domain Model
- MVP固定ジャンルenum
- 無効マスタを削除せず`isActive`で扱う運用
- ID、検索語、ジャンル、選択可否の単体テスト

### 方針

- Product IDは容量・容器・温冷だけでは分けない。
- 自販機のメーカー不明は`null`で表し、架空のunknownメーカーを作らない。
- 不正・未知の旧IDを自動補正して正式マスタへ保存しない。
- Firestore DTO、旧データ互換、実seedは後続コミットへ分離する。

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
