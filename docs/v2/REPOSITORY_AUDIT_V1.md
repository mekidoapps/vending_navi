> 文書状態: Phase 0 現行リポジトリ監査（一次監査）  
> 監査日: 2026-08-05  
> 対象: `mekidoapps/vending_navi` 公開リポジトリ `main` ブランチ  
> 判定区分: そのまま再利用 / 改修して再利用 / 作り直し / MVP保留 / 要入手・要確認

# 自販機ナビ v2 現行リポジトリ監査

## 1. 監査の目的

現行クローズドテスト版を維持しながら、v2へ引き継ぐ資産と作り直す範囲をファイル単位で明確にする。

本監査は、公開GitHub上のソースツリー、主要Dartファイル、`pubspec.yaml`、`firebase.json`、`firestore.rules`を確認した一次監査である。ローカルでの`flutter analyze`、ビルド、テスト実行、依存関係の完全な参照解析はまだ行っていない。そのため、内容を直接確認できていない小規模ファイルには「暫定判定」を付ける。

## 2. 結論

### 2.1 全体判断

現行コードを一括改修するのではなく、**v2用の新しいFeature-first構造を作り、利用価値のある処理だけを移植する**方針が妥当である。

再利用価値が高いものは次のとおり。

- Firebase、Google Maps、Google Play、アプリ署名などの外部設定
- App Check初期化の考え方
- 位置情報取得、外部地図起動などの小さなサービス
- 商品マスタの元データ、検索キーワード、メーカー候補
- 旧データの揺れを吸収している読み取り処理
- フィードバックのCallable Functions呼び出しとエラー分類
- 現在のテーマ、アイコン、フォント等の素材

作り直しが必要な中心部分は次のとおり。

- `main_shell_screen.dart`を中心とするホーム・検索・下部パネル・タブ管理
- 現行フォーム型の自販機登録フロー
- 現行自販機詳細画面
- Flutterクライアントからの自販機データ直接書き込み
- 文字列商品・配列商品を前提にしたデータモデル
- 現行Firestore Rules

### 2.2 主要リスク

| 優先度 | リスク | 現状 | v2対応 |
|---|---|---|---|
| P0相当 | 公開データ書き込み方式 | ログインユーザーによる`vending_machines`直接作成・更新がRulesで許可されている | 自販機登録・更新・報告をFunctions経由に固定し、クライアント書き込みを拒否 |
| P1 | ホーム画面の責務集中 | `main_shell_screen.dart`が約1,600 LOCで、地図・検索・フィルター・パネル・タブ・Firebase参照を管理 | 新規`home_map` featureとして分割して作り直す |
| P1 | データモデルの旧仕様依存 | メーカーが文字列、商品が`List<Map>`・`drinks`・`drinkSlots`等で混在 | 旧DTOとv2 DTOを分離し、共通Domain Modelへ変換 |
| P1 | Functionsソース不足 | クライアントは`submitFeedback`を呼ぶが、公開リポジトリに`functions/`が見当たらない | Functions実体の所在確認・リポジトリ収録・Emulator化 |
| P1 | Storage Rules不足 | `firebase.json`にStorage Rulesの設定が見当たらず、公開リポジトリにも`storage.rules`が見当たらない | 一時画像用Storage Rulesを新規作成し、設定へ追加 |
| P1 | テスト不足 | `test/`では`widget_test.dart`のみ確認 | Phaseごとの単体・Widget・Emulatorテストを新規整備 |
| P2 | 直接書き込みへのフォールバック | Feedback Function未配備時にFirestoreへ直接保存する処理がある | フォールバック廃止。Function未配備は明示エラーにする |
| P2 | Utilityの重複 | `core/utils`と`utils`に検索・タグ系の似た処理が存在 | v2移植時に一つの責務へ統合 |
| P2 | StorageServiceの責務混在 | 最近使った商品と画像アップロードを同一Serviceが管理 | Local historyとTemporary photo storageへ分割 |

## 3. 判定基準

### そのまま再利用

役割・データ契約・セキュリティ方針がv2でも変わらず、依存注入後も修正がほぼ不要なもの。

### 改修して再利用

中核ロジックや外部設定は有用だが、v2のRepository、Product ID、エラー型、Functions経由などへ合わせる必要があるもの。

### 作り直し

旧UI、旧データ構造、直接Firebaseアクセス、複数責務へ強く結合しており、修正より新規実装の方が安全なもの。

### MVP保留

現行版には存在するが、v2 MVP対象外の機能。削除せず、旧ブランチまたはlegacy資産として保持する。

### 要入手・要確認

公開リポジトリに存在しない、またはWeb上の一次監査だけでは判断できないもの。

## 4. ルート・設定ファイル監査

| 対象 | 現在の役割・確認内容 | 判定 | v2での対応 | 状態 |
|---|---|---|---|---|
| `android/` | Androidビルド、パッケージ、署名、Maps等 | 改修して再利用 | 現行package IDと署名を維持し、App Check・権限・Flavor設定を確認 | 確定判定 |
| `ios/` | iOSビルド設定 | 改修して再利用 | MVPはAndroid先行だが、削除せずビルド可能性を維持 | 暫定判定 |
| `assets/` | フォント、画像、アイコン等 | 改修して再利用 | v2デザインシステムに合う素材のみ移植 | 暫定判定 |
| `docs/images/` | README等の画像 | そのまま再利用 | プロダクト資料として保持 | 暫定判定 |
| `firebase.json` | Firestore RulesとFlutter Firebase設定 | 改修して再利用 | Functions、Storage、Emulator設定を追加 | 確定判定 |
| `firestore.rules` | `vending_machines`の公開read、ログインcreate/update、delete拒否 | 作り直し | v2コレクション全体を対象にし、公開データへのクライアントwriteを原則拒否 | 確定判定 |
| `storage.rules` | 公開リポジトリで確認できず | 要入手・要確認 | 一時画像・正式画像のRulesを新規作成 | 確定判定 |
| `functions/` | 公開リポジトリで確認できず | 要入手・要確認 | 既存`submitFeedback`の実体を回収し、v2 Functions群と同じ管理下へ置く | 確定判定 |
| `pubspec.yaml` | Provider、Firebase、Maps、通知等の現行依存 | 改修して再利用 | Riverpod、go_router、Freezed、json_serializable、build_runnerを追加。不要依存は段階的に除去 | 確定判定 |
| `README.md` | 現行v1の構成・機能・Firebase直接接続を説明 | 改修して再利用 | v2着手後、現行版とv2のブランチ・開発手順を明記 | 確定判定 |
| `test/widget_test.dart` | テストファイルが1件のみ | 作り直し | feature単位のテスト構成を新設 | 確定判定 |
| 各デスクトップ/Webフォルダ | Flutterテンプレート由来 | MVP保留 | Android MVPに不要な変更を加えず保持 | 暫定判定 |

## 5. `lib/main.dart`・起動基盤

| ファイル | 現在の役割 | 判定 | v2対応 | 状態 |
|---|---|---|---|---|
| `lib/main.dart` | Firebase初期化、App Check初期化、`MaterialApp`、Startup Router、起動失敗画面 | 改修して再利用 | `bootstrap.dart`へFirebase/App Check/Emulator/ログ設定を分離し、`ProviderScope`と`MaterialApp.router`へ変更 | 確定判定 |
| `lib/screens/startup_router_screen.dart` | 起動時の画面分岐 | 改修して再利用 | go_routerのredirectと初回起動Providerへ責務を分割 | 暫定判定 |
| `lib/screens/auth_gate.dart` | 認証状態による表示分岐 | 改修して再利用 | AuthRepositoryのStreamとgo_router redirectへ統合 | 暫定判定 |

## 6. 画面ファイル監査

| ファイル | 現在の役割 | 判定 | v2での扱い | 状態 |
|---|---|---|---|---|
| `screens/main_shell_screen.dart` | 地図、現在地、距離、商品・気分・タグ検索、メーカー色、下部パネル、タブ、広告等を集約 | 作り直し | `home_map`、`product_search`、`machine_popup`へ分割。地図移動等の小さな処理だけ抽出 | 確定判定 |
| `screens/machine_create_screen.dart` | 現行自販機作成フロー | 作り直し | 位置確認→重複→方法選択→確認の段階式フローを新規作成 | 確定判定 |
| `screens/register_vending_machine_screen.dart` | 旧登録・編集UI | 作り直し | v2登録フローへ置換。棚UIや自由入力は移植しない | 確定判定 |
| `screens/drink_registration_screen.dart` | 商品・棚登録系画面 | MVP保留 | 商品選択ロジックだけ候補として抽出し、棚画面はlegacy保持 | 暫定判定 |
| `screens/machine_detail_screen.dart` | 現行自販機詳細 | 作り直し | v2の写真・検索対象・確認済み/推定・更新導線に合わせて新規作成 | 確定判定 |
| `screens/login_screen.dart` | ログインUI | 改修して再利用 | v2デザイン、Googleログイン、戻り先保持、AuthViewModelへ接続 | 暫定判定 |
| `screens/favorite_drinks_screen.dart` | お気に入り飲料管理 | 改修して再利用 | 「よく飲む商品」へ名称とデータ契約を変更し、Product ID限定にする | 暫定判定 |
| `screens/my_page_screen.dart` | マイページ | 改修して再利用 | MVP対象外のレベル・称号・通知・課金表示を外し、アカウント・よく飲む商品・フィードバック中心へ変更 | 暫定判定 |
| `screens/onboarding_screen.dart` | 初回案内 | 改修して再利用 | v2の「探す」「登録」「あるかも」の説明へ差し替え | 暫定判定 |
| `screens/feedback/feedback_form_screen.dart` | フィードバック入力・送信 | 改修して再利用 | FeedbackRepository/ViewModelへ接続し、Callable Function必須にする | 確定判定 |
| `screens/checkin_screen.dart` | チェックイン | MVP保留 | v2 MVPへ移植しない | 確定判定 |
| `screens/notification_settings_screen.dart` | 近接・更新通知設定 | MVP保留 | v2 MVPへ移植しない | 確定判定 |

## 7. モデル監査

| ファイル | 現在の役割 | 判定 | v2での扱い | 状態 |
|---|---|---|---|---|
| `models/vending_machine.dart` | Firestore依存の自販機モデル。lat/lng揺れ、文字列manufacturer、配列products、旧フィールド等を吸収 | 改修して再利用 | `LegacyVendingMachineDocument`として読み取り互換に残し、v2 DTO/Domain Modelとは分離 | 確定判定 |
| `models/product.dart` | id、名称、メーカー、category、tags、searchKeywordsと文字列検索 | 改修して再利用 | Freezed化し、`manufacturerId`、`genreIds`へ変更。検索処理はRepository/UseCaseへ移動 | 確定判定 |
| `models/drink_item.dart` | 旧商品表示・入力モデル | MVP保留 | Product ID移行補助としてのみ利用可能性を確認 | 暫定判定 |
| `models/drink_slot_data.dart` | 棚・スロット情報 | MVP保留 | v2 MVPへ移植しない。旧データ変換の入力型として保持 | 確定判定 |
| `models/position_data.dart` | 位置入力・登録用データ | 改修して再利用 | immutableな`SelectedLocation` Value Objectへ再構成 | 暫定判定 |
| `models/machine_create_result.dart` | 作成結果 | 改修して再利用 | Callable Functionの戻り値DTOへ置換 | 暫定判定 |
| `models/feedback_category.dart` | フィードバック種別 | 改修して再利用 | v2でも利用。サーバー仕様とenumを同期 | 暫定判定 |
| `models/feedback_submit_result.dart` | 送信結果 | 改修して再利用 | Function DTOとしてFreezed化 | 暫定判定 |
| `models/app_progress.dart` | 経験値・レベル等 | MVP保留 | v2 MVPへ接続しない | 確定判定 |

## 8. Service監査

| ファイル | 現在の役割・問題 | 判定 | v2での扱い | 状態 |
|---|---|---|---|---|
| `services/auth_service.dart` | FirebaseAuthのメール登録・ログイン・匿名ログイン等を薄く包む | 改修して再利用 | DI対応の`FirebaseAuthService`へ移し、GoogleログインとAppFailure変換を追加。匿名ログインはMVP方針を再確認 | 確定判定 |
| `services/firestore_service.dart` | 自販機stream/get/create/updateとチェックインを直接実行 | 作り直し | 公開read専用ServiceとLegacy adapterに分け、writeはCallable Functionsへ移す | 確定判定 |
| `services/vending_machine_service.dart` | 旧フィールドを含む自販機ドキュメントを直接作成 | 作り直し | 移行時の旧スキーマ資料として保持。v2登録には使わない | 確定判定 |
| `services/location_service.dart` | 権限確認、現在地、逆ジオコード、safe取得 | 改修して再利用 | timeout、設定画面誘導、AppFailure、DIを追加して`core/location`へ移す | 確定判定 |
| `services/map_launcher_service.dart` | 外部地図起動 | そのままに近い改修再利用 | Interface化・エラー結果型追加後に再利用 | 確定判定 |
| `services/storage_service.dart` | SharedPreferencesの最近飲料とFirebase Storage画像アップロードを混在 | 作り直し | `RecentProductLocalService`と`TemporaryPhotoStorageService`へ分割。一時ユーザーパス方式へ変更 | 確定判定 |
| `services/drink_candidate_service.dart` | メーカー別文字列seed、旧自販機`drinks`/`drinkSlots`集計、最近飲料から候補生成 | 改修して再利用 | seedをProduct/Manufacturerマスタ移行素材に使用。実行時の旧文字列集計は廃止 | 確定判定 |
| `services/drink_catalog_service.dart` | 商品カタログ取得・検索・整形 | 改修して再利用 | ProductRepositoryへ分割し、Product ID・genreIds・検索インデックスへ対応 | 暫定判定 |
| `services/favorite_drink_service.dart` | お気に入り飲料の保存・取得 | 改修して再利用 | `favorite_products` Repositoryへ変更し、Product IDのみ許可 | 暫定判定 |
| `services/favorite_service.dart` | お気に入り系の小規模サービス | 要確認 | お気に入り自販機ならMVP保留、商品ならfavorite_productsへ統合 | 暫定判定 |
| `services/feedback_service.dart` | `submitFeedback` Callable呼出し、入力検証、エラー変換。not-found時にFirestore直接保存 | 改修して再利用 | Callable部分とエラー分類を残し、直接保存フォールバックとメール等のクライアント保存を廃止 | 確定判定 |
| `services/local_progress_service.dart` | ローカル進捗 | MVP保留 | v2 MVPへ接続しない | 暫定判定 |
| `services/user_progress_service.dart` | 経験値・ユーザー進捗 | MVP保留 | v2 MVPへ接続しない | 確定判定 |
| `services/nearby_favorite_notification_service.dart` | 近接通知 | MVP保留 | v2 MVPへ移植しない | 確定判定 |
| `services/notification_settings_service.dart` | 通知設定 | MVP保留 | v2 MVPへ移植しない | 確定判定 |

## 9. Data・Utility・Theme監査

| ファイル/領域 | 現在の役割 | 判定 | v2での扱い | 状態 |
|---|---|---|---|---|
| `data/drink_master_data.dart` | 現行商品マスタ元データ | 改修して再利用 | Product ID、Manufacturer ID、genreIds、keywordsを持つseedへ変換 | 暫定判定 |
| `data/drink_presets.dart` | メーカー・商品プリセット | 改修して再利用 | `manufacturers.presetProductIds`の初期データへ移行 | 暫定判定 |
| `theme/app_colors.dart` | 現行カラー定義 | 改修して再利用 | v2の白・水色・淡青デザイントークンへ再定義 | 暫定判定 |
| `theme/app_theme.dart` | ThemeData | 改修して再利用 | ThemeExtensionまたは独自tokensを追加し、将来テーマ切替に対応 | 暫定判定 |
| `utils/distance_util.dart` | 距離計算 | 改修して再利用 | 単体テストを追加し、Domain utilityへ移す | 暫定判定 |
| `utils/freshness_util.dart` | 情報鮮度判定 | 改修して再利用 | 「古い情報」の期間が確定後、Domain ruleへ移す | 暫定判定 |
| `utils/map_marker_factory.dart` | 地図マーカー生成 | 改修して再利用 | メーカー色依存を外し、確認済み・推定・古さ・選択状態へ対応 | 確定判定 |
| `utils/drink_name_nomalizer.dart` | 商品名正規化（ファイル名にtypoあり） | 改修して再利用 | 旧文字列→Product ID移行専用へ限定し、名称を修正 | 暫定判定 |
| `utils/search_token_util.dart` | 検索トークン | 改修して再利用 | Productマスタ用検索正規化へ統合 | 暫定判定 |
| `utils/drink_tag_util.dart` | 飲料タグ処理 | MVP保留/統合 | 気分・特徴タグ検索はMVP外。genre変換に必要な部分だけ移植 | 暫定判定 |
| `core/utils/search_normalizer.dart` | 検索正規化 | 改修して再利用 | `search_token_util`等と統合し、1実装へ限定 | 暫定判定 |
| `core/utils/drink_tag_util.dart` | タグ処理の別実装 | MVP保留/統合 | 重複を解消。MVPではgenreに必要な部分のみ | 暫定判定 |
| `core/utils/prefecture_util.dart` | 都道府県処理 | 改修して再利用 | v2で住所表示に必要ならcoreへ維持 | 暫定判定 |
| `tool/seed_product.dart` | 商品seed補助 | 改修して再利用 | v2 products/manufacturers seed・検証ツールへ拡張 | 暫定判定 |

## 10. Widget監査

| ファイル | 現在の役割 | 判定 | v2での扱い | 状態 |
|---|---|---|---|---|
| `widgets/app_bottom_info_card.dart` | 現行下部情報カード | 作り直し | v2固定吹き出し`MachinePopupCard`へ置換 | 確定判定 |
| `widgets/drink_picker_sheet.dart` | 商品選択UI | 改修して再利用 | Product ID検索・選択Widgetとして再構成 | 暫定判定 |
| `widgets/drink_slot_tile.dart` | 棚スロット | MVP保留 | v2 MVPへ移植しない | 確定判定 |
| `widgets/freshness_badge.dart` | 鮮度表示 | 改修して再利用 | 状態ラベルコンポーネントへ統合 | 暫定判定 |
| `widgets/machine_freshness_badge.dart` | 自販機鮮度表示 | 改修して再利用 | `freshness_badge`と統合し、重複Widgetをなくす | 暫定判定 |
| `widgets/login_required_sheet.dart` | ログイン要求 | 改修して再利用 | 登録・更新・報告の共通ログイン導線としてv2デザインへ変更 | 暫定判定 |
| `widgets/my_page_feedback_section.dart` | マイページのフィードバック導線 | 改修して再利用 | 新マイページへ移植 | 暫定判定 |
| `widgets/simple_tutorial_dialog.dart` | 簡易チュートリアル | 改修して再利用 | 初回のピン・検索・推定表示説明へ差し替え | 暫定判定 |
| `widgets/checkin_success_overlay.dart` | チェックイン演出 | MVP保留 | v2 MVPへ移植しない | 確定判定 |
| `widgets/title_unlock_overlay.dart` | 称号演出 | MVP保留 | v2 MVPへ移植しない | 確定判定 |

## 11. Firebase・セキュリティ監査

### 11.1 現行Firestore Rules

確認できたRulesは主に`vending_machines/{machineId}`を対象としており、公開read、ログインユーザーのcreate/update、delete拒否を定義している。これは現行版の運用には沿っているが、v2で確定した以下の方針とは一致しない。

- 公開自販機データは共有コミュニティデータとする
- 登録・更新・報告はCallable Functions経由とする
- 更新履歴を必ず残す
- 高影響変更は提案・報告として扱う
- クライアントは`machine_product_index`等を直接変更できない

そのため、現行Rulesを継ぎ足して使わず、v2コレクション構成に合わせて新規設計する。

### 11.2 Feedback

クライアント側には`submitFeedback` Callable Functionの利用が実装されている。ただしFunctionが`not-found`の場合、Firestoreの`feedback_items`へ直接保存するフォールバックがあり、UID、表示名、メールアドレス等もクライアントから書き込む。v2ではFunctions必須方針と矛盾するため、このフォールバックを廃止する。

### 11.3 Functions・Storage

公開リポジトリのルートでは`functions/`と`storage.rules`を確認できなかった。次のいずれかを確認する必要がある。

- 別リポジトリで管理している
- ローカルにのみ存在する
- Firebase Consoleや別環境からデプロイしている
- 現在は未デプロイまたは一部だけ存在する

v2着手前に、既存Functionのソースと現在のStorage Rulesを必ず回収する。

## 12. 依存パッケージ監査

### 継続候補

- `firebase_core`
- `cloud_firestore`
- `firebase_auth`
- `firebase_storage`
- `cloud_functions`
- `firebase_app_check`
- `google_maps_flutter`
- `google_sign_in`
- `geolocator`
- `geocoding`
- `image_picker`
- `url_launcher`
- `shared_preferences`（用途を限定）
- `package_info_plus`

### 新規追加候補

- `flutter_riverpod`
- `go_router`
- `freezed_annotation`
- `json_annotation`
- `freezed`（dev）
- `json_serializable`（dev）
- `build_runner`（dev）
- Firebase Emulator/Functions側で必要なテスト依存

### MVPから外れるため後で削除判断する候補

- 通知専用依存
- 広告専用依存
- Provider（Riverpod移行後）
- ゲーム要素だけで使う依存

依存削除はPhase 1で一括実施せず、参照がなくなった段階で行う。

## 13. 推奨移行マップ

```text
現行 main ブランチ（クローズドテスト版を維持）
        │
        ├─ 外部設定・素材・旧DTOを保持
        │
        └─ develop-v2
             ├─ app / core / features の新骨格
             ├─ 旧データread adapter
             ├─ 新Firestore read repositories
             ├─ Callable Functions write repositories
             └─ feature単位でUIを新規実装
```

現行画面を`features`へそのまま移動してから修正する方法は採用しない。まず空のv2構造を作り、監査表で「改修して再利用」とした処理を小さな単位で移す。

## 14. Phase別の移植順序

### Phase 0残作業

1. 既存Functionsソースの所在確認
2. 現行Storage Rulesの取得
3. Firebase開発環境と本番環境の分離確認
4. Firestore・Storageのバックアップ手順確認
5. リポジトリをローカル取得し、`flutter analyze`とテスト実行
6. 本監査の暫定判定を確定

### Phase 1で最初に移すもの

1. Firebase/App Check初期化
2. AppThemeの元データ
3. AuthServiceの低レベル処理
4. LocationService
5. MapLauncherService
6. Productマスタseed
7. 共通AppFailure・ログ基盤

### Phase 2で移すもの

1. `vending_machine.dart`の旧読み取りロジック
2. 旧`drinks`/`drinkSlots`の変換
3. 商品名正規化
4. Productマスタ・メーカーpreset
5. 旧データfixtureとMapperテスト

### Phase 3以降で参考にするだけのもの

- `main_shell_screen.dart`
- `machine_detail_screen.dart`
- `machine_create_screen.dart`
- `register_vending_machine_screen.dart`

これらはレイアウトや既存挙動の確認資料とし、v2コードへ直接コピーしない。

## 15. v2着手前の必須チェックリスト

- [ ] 現行`main`へ復帰できるtagまたはrelease commitを固定する
- [ ] `develop-v2`を作成する
- [ ] Phase 0 docsをリポジトリの`docs/v2/`へ追加する
- [ ] Functionsソースを同一リポジトリまたは管理先へ回収する
- [ ] 現行Firestore RulesとStorage Rulesのデプロイ状態を保存する
- [ ] Firebase本番データをエクスポートまたは復元可能な形で保全する
- [ ] 開発用Firebase/Emulator接続方法を確定する
- [ ] ローカルで現行版の`flutter pub get`を実行する
- [ ] `flutter analyze`結果を保存する
- [ ] 現行テスト結果を保存する
- [ ] Pixel 6aで現行主要フローの基準動画またはスクリーンショットを保存する
- [ ] 暫定判定のファイルをローカルソースで再監査する

## 16. 最初の実装タスク案

監査結果から、最初のコード変更は機能画面ではなく、以下の基盤コミットとする。

```text
chore(v2): add architecture skeleton and development bootstrap
```

含める範囲：

- `lib/app/`
- `lib/core/`
- `lib/features/`
- Riverpod ProviderScope
- go_routerの最小ルート
- Firebase/Emulator bootstrap
- v2デザインテーマの最小定義
- AppFailure
- 既存画面へ戻れる暫定ルート
- 最小の起動テスト

この時点では現行ホーム・登録・Firestoreモデルを変更しない。

## 17. 監査の未完了範囲

本監査だけでは、次を確定できない。

- ローカルにしか存在しない未pushコード
- Functions実装本体
- 現在デプロイ中のFirestore/Storage Rulesとの差分
- Firebase Console上のindexes、Extensions、scheduled jobs
- Android署名・keystoreの保管状態
- 実際のビルドエラー・lint警告
- 全Dartファイルの参照関係と未使用コード
- 依存パッケージの実使用状況
- 実機でのみ発生する問題

これらはローカルリポジトリとFirebaseプロジェクトを使う二次監査で補完する。
