> 文書状態: Phase 2 実装中  
> 更新日: 2026-08-06  
> 対象: 自販機ナビ / VendingNavi v2  
> パッケージID: `com.mekidoapps.vendingnavi`  
> リポジトリ: `mekidoapps/vending_navi`


# 変更履歴


## 2026-08-07 - Phase 3 P3-01 自販機Domain／DTO／Mapper

### 追加

- `VendingMachineId`
- Firestore SDK非依存の`GeoCoordinate`
- `VendingMachine`
- `VendingMachineProduct`
- 自販機・商品情報の固定enum
- `vending_machines/{machineId}` DTO／Mapper
- `products/{productId}` DTO／Mapper
- Domain／Mapper単体テスト
- Phase 3詳細実装計画

### 方針

- Phase 0 `DATA_MODEL_V2.md`のv2フィールド名・固定値をそのまま採用。
- `schemaVersion=2`は必須項目を厳格に検証する。
- 未知のstatus、evidenceType等を既知値へ自動補正しない。
- AI未確認候補を表す公開evidence値は追加しない。
- Product document IDと`productId`の不一致を拒否する。
- 旧データ互換用の橋渡しはP3-02で行う。
- OI-003周辺検索範囲とOI-004情報古さの期間は未決定のまま維持する。
- v1 UI、Functions、Firestore RulesはP3-01では変更しない。



## 2026-08-07 - Phase 2 P2-05 Emulator seed／品質ゲート

### 追加

- Product／ManufacturerのEmulator seed snapshot
- Firebase Admin SDKを使うEmulator専用seed script
- public read／client write denyをRESTで確認するRules検証script
- Dart固定fixtureとseed snapshotの同期テスト
- Phase 2 Emulator自動結合ゲート
- Phase 2品質ゲート
- Phase 2完了レポート

### Security Rules

- `products/{productId}` はpublic readのみ許可。
- `manufacturers/{manufacturerId}` はpublic readのみ許可。
- 上記2コレクションへのクライアントwriteは禁止。
- `vending_machines`を含むその他のパスはdeny-by-defaultを維持。

### 安全策

- seedはFirestore Emulator localhost系以外への接続を拒否する。
- seed scriptから本番Firestoreへ書き込む導線を持たせない。
- FunctionsのNode.js 20を維持するためFirebase Admin SDK 13.10.0を固定する。



## 2026-08-07 - Phase 2 P2-04 Repository／固定fixture

### 追加

- Product／Manufacturer Repository interface
- Firestoreを隠蔽するMasterDocumentSource
- Firestore MasterDocumentSource実装
- Product／Manufacturer Repository実装
- Riverpod Repository Provider
- 現行v1プリセットを起点とした固定Product／Manufacturer fixture
- 旧メーカー名・旧商品名の手動alias
- Repository、fixture、aliasの単体テスト
- 固定fixture・Repository運用規約

### 方針

- 正式マスタの不正文書は黙って除外せずRepository Failureとする。
- 一覧は既定で`isActive: true`のみ返す。
- `その他`を架空Manufacturer IDとして追加しない。
- 現行v1の`AQUO`はP2-04では正式メーカーに確定せず未解決を維持する。
- `BOSS`、`ジョージア`、`ファンタ`等の曖昧なブランド単独表記を特定商品へ自動変換しない。
- 公開マスタのwriteは提供せず、P2-05でEmulator seedとread権限を検証する。



## 2026-08-07 - Phase 2 P2-03 旧データ互換Mapper

### 追加

- v1 `vending_machines` の混在フィールドを読み取る read-only Legacy Document
- `products` / `drinkSlots` / `slots` / `drinks` の順序付きフォールバック
- `lat/lng` / `latitude/longitude` / `GeoPoint` の位置情報互換
- Timestamp / DateTime / ISO文字列と欠損日時の安全な読み取り
- 旧メーカー文字列からManufacturer IDへの解決
- Product ID完全一致、正規化名称、メーカー＋名称、手動対応表による旧商品解決
- 対応不能商品をrawName付き未解決データとして保持する表現
- 旧名称正規化・Legacy Mapperの単体テスト
- 旧データ互換規約

### 方針

- Legacy Mapperは読み取り専用とし、旧ドキュメントを書き換えない。
- 不明メーカーを`unknown`等の架空Manufacturer IDへ変換しない。
- 一意に確定できない商品を推測でProduct IDへ紐付けない。
- 未解決商品が含まれていても自販機全体の読み込みを失敗させない。
- 実Product／Manufacturer fixtureと手動対応表はP2-04で固定する。

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
