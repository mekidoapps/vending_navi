> 文書状態: Phase 2 実装中  
> 更新日: 2026-08-06  
> 対象: 自販機ナビ / VendingNavi v2  
> パッケージID: `com.mekidoapps.vendingnavi`  
> リポジトリ: `mekidoapps/vending_navi`


# 変更履歴


## 2026-08-07 - Phase 4 P4-01 商品検索Core

### 追加

- `ProductSearchQuery`
- `ProductSearchNormalizer`
- `ProductSearchCandidate`
- 検索match kind / deterministic score
- Product candidate search Service
- Riverpod ProductSearchController
- 非同期検索のstale response防止
- query／Service／Controller単体テスト
- Phase 4実装計画
- P4-01設計文書

### 方針

- Product IDを検索対象の正規IDとする。
- 商品名・`searchKeywords`はProduct候補選択の入口に利用する。
- Product ID／完全一致／前方一致／部分一致の順を固定する。
- AI意味検索、ふりがな自動推定、気分検索は追加しない。
- 空queryではFirestoreを読まない。
- OI-003検索半径は未決定のまま。
- OI-004情報古さの期間も未決定のまま。
- HomeMap UI／`machine_product_index`接続はP4-02以降。
- Firebase Rules、Functions、v1 UIは変更しない。



## 2026-08-07 - Phase 3 P3-07 外部経路／品質ゲート

### 追加

- `ExternalMapService`
- Google Maps外部徒歩経路Service
- Google Maps URL生成テスト
- 自販機詳細「ここまでの経路を見る」
- 外部地図起動失敗SnackBar
- 経路Service接続Widget test
- HomeMap／詳細の小型・基準・大型画面test
- `tool/phase3_quality_gate.sh`
- Phase 3品質ゲート文書
- Phase 3完了レポート

### 方針

- 現在地はURLへ埋め込まず、外部地図アプリ側の現在地を出発地として利用する。
- destinationは選択自販機の緯度経度のみ渡す。
- `url_launcher`は既存依存を再利用し、新規packageを追加しない。
- 外部地図を開けない場合もアプリをクラッシュさせずSnackBar表示。
- P3-07では本番Firebase Rulesをdeployしない。
- 自動ゲートでは既存のP3-02 Firestore Emulator統合を再実行する。
- OI-003検索半径とOI-004情報古さ期間はPhase 4へ持ち越す。



## 2026-08-07 - Phase 3 P3-06 固定吹き出し・自販機詳細

### 追加

- 選択自販機の固定情報カード
- メーカー表示名provider
- `VendingMachineDetailLoader`
- Product masterとの商品名結合
- `VendingMachineDetailData`
- `/v2/machines/:machineId` route
- `V2VendingMachineDetailScreen`
- 確認済み／あるかも表示
- 販売中／売り切れ／在庫不明表示
- Detail Loader／詳細Widget／選択カード／routeテスト
- P3-06設計文書

### 方針

- Google Maps標準InfoWindowではなくFlutter固定カードを利用。
- Product masterが取得できなくてもProduct IDをfallback表示する。
- Manufacturer masterが取得できなくてもIDをfallback表示する。
- 自販機本体の取得Failureだけは詳細画面Failureとする。
- 詳細へpushする際にHomeMap selectionをclearしない。
- 戻り時は選択Markerと固定カードを維持する。
- OI-004情報古さの具体期間はまだ固定しない。
- 経路案内はP3-07。
- Firebase Rules、Functions、v1 UIは変更しない。



## 2026-08-07 - Phase 3 P3-05 周辺自販機・状態ピン

### 追加

- `MapViewportBounds`
- pure Dart geohash encoder
- viewport用geohash query planner
- Firestore viewport source
- `VendingMachineMapRepository`
- Riverpod `VendingMachineMapController`
- viewport移動時の再読込
- 状態別Marker
- Marker選択状態
- 0件／読込失敗overlay
- HomeMapと実自販機データの接続
- viewport／geohash／Controller／Marker resolverテスト
- P3-05設計文書

### 方針

- OI-003の固定検索半径をP3-05では決めない。
- Google Mapのvisible regionを取得範囲とする。
- schemaVersion=2は`geohash` prefix queryを使う。
- legacy文書だけは移行期間の互換経路として全rootからviewport filterする。
- legacy全件互換経路はv2位置index移行後に削除対象。
- selected／confirmed／inferred／locationOnlyの状態をピンへ反映。
- ピンタップ時は選択と中心移動のみ。固定吹き出しはP3-06。
- Firebase Rules、Functions、v1 UIは変更しない。



## 2026-08-07 - Phase 3 P3-04 v2 HomeMapScreen

### 追加

- `V2HomeMapScreen`
- 全面Google Map
- 上部小型アプリラベル
- v2デザインの現在地ボタン
- 位置情報状態overlay
- 右下「マイ／登録／探す」action cluster
- GoogleMap PlatformViewを回避できるwidget-test seam
- HomeMap widget tests
- P3-04設計文書

### 変更

- `/v2` production default screenをFoundationからHomeMapへ切り替え。
- root widget testのPlatformView依存を外し、HomeMap専用widget testへ置換。

### 方針

- 「探す」を右下の最大・最下部アクションとする。
- P3-04では探す／登録／マイの遷移先をまだ接続しない。
- 現在地が取れなくても地図は表示し続ける。
- P3-03の位置情報Controllerだけを利用し、UIからGeolocatorを直接呼ばない。
- 自販機marker／周辺query／検索半径はP3-05以降。
- `/v2` pathと既存route identifierはPhase 1互換のため維持する。
- v1 UI、Firestore Rules、Functionsは変更しない。



## 2026-08-07 - Phase 3 P3-03 現在地Service／Controller

### 追加

- `CurrentLocation`
- `AppLocationPermission`
- `LocationService`
- `GeolocatorLocationService`
- Geolocator permission Mapper
- `CurrentLocationState`
- Riverpod `CurrentLocationController`
- app設定／位置情報設定画面導線
- `LocationUnavailableFailure`
- Controller・Domain・permission Mapper単体テスト
- P3-03位置情報アーキテクチャ文書

### 方針

- v2 UIからGeolocator SDKを直接呼ばない。
- 位置サービスOFF、権限拒否、永続拒否、判定不能、取得失敗を区別する。
- `denied`時だけ通常フローで権限requestを1回行う。
- `deniedForever`ではpermission requestを繰り返さない。
- 現在地取得はhigh accuracy・12秒timeoutの1回取得。
- P3-03では位置情報をFirestore／ログ／Analyticsへ保存しない。
- 現行v1の`DistanceUtil`は変更しない。
- P3-04でHomeMapへController状態を接続する。



## 2026-08-07 - Phase 3 P3-02 Repository・v1/v2互換読取

### 追加

- `VendingMachineRepository`
- Firestore `VendingMachineDocumentSource`
- v2 root + productsサブコレクション結合読取
- `LegacyVendingMachineDomainBridge`
- v1/v2共存確認用`VendingMachineReadBatch`
- Riverpod Repository Provider
- v1/v2 Repository単体テスト
- 自販機用Emulator fixture
- 自販機read/write Rules検証script
- P3-02 Emulatorゲート
- Rules contract test

### Rules

- `vending_machines/{machineId}` public read
- `vending_machines/{machineId}/products/{productId}` public read
- 上記client writeは禁止
- photos／revisions／machine_product_indexはdeny継続

### 互換方針

- v2文書はroot／productとも不正値を黙って除外しない。
- v1旧文書はP2互換Mapperと固定マスタを再利用する。
- 解決済み旧商品は`manual_confirmed`としてDomainへ橋渡しする。
- 同一Product IDの旧スロットは1商品へ集約する。
- 未解決旧商品は推測せず件数だけ互換snapshotへ残す。
- 位置なしlegacyは互換snapshotからのみ除外し、件数を記録する。
- compatibility snapshotは移行確認専用で、HomeMapの最終APIには使わない。
- OI-003周辺検索範囲は引き続き未確定。



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
