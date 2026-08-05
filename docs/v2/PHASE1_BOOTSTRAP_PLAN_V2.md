> 文書状態: Phase 1 実装前計画案  
> 作成日: 2026-08-05  
> 対象: 自販機ナビ / VendingNavi v2  
> パッケージID: `com.mekidoapps.vendingnavi`  
> リポジトリ: `mekidoapps/vending_navi`

# Phase 1 基盤コミット計画

## 1. 監査結果の確定事項

公開リポジトリの`main`ブランチを再確認した結果、次を確認した。

- 公開ブランチは`main`のみ。
- `firebase.json`は現時点で`firestore.rules`だけを参照している。
- 公開ツリーに`functions/`と`storage.rules`は存在しない。
- FirebaseプロジェクトIDは`vendingnavi`。
- 現行`main.dart`はFirebaseとApp Checkを初期化し、`MaterialApp`から`StartupRouterScreen`を開く。
- 現行テーマは水色・白・青を基調としており、v2の方向性と近い。
- 現行依存はProviderであり、Riverpod、go_router、Freezed、json_serializableは未導入。
- 現行Firestore Rulesは、ログインユーザーによる`vending_machines`の直接作成・更新を許可している。

既存FunctionsやStorage Rulesがローカルや別管理先に存在する可能性は残る。ただし、それらが見つかるまでPhase 1全体を停止せず、v2用の安全な空基盤を新設する。

## 2. Phase 1の目的

Phase 1では、v2機能を実装する前に次を成立させる。

1. 現行クローズドテスト版を壊さない。
2. v2用のFeature-first構造を追加する。
3. Riverpod、go_router、Freezedの利用基盤を作る。
4. Firebase初期化を画面コードから分離する。
5. v1画面とv2画面を同じブランチ内で切り替えて起動できる。
6. v2用テーマと共通UIの最小セットを作る。
7. 本番Firebase設定とローカルEmulator設定を分離する。
8. 単体・Widgetテストを実行できる最小構成を作る。

## 3. Phase 1で行わないこと

- 現行ホーム画面の改修
- 商品検索の実装
- 自販機登録・更新の実装
- Firestoreデータモデルの移行
- 本番Firestore Rulesの置き換え
- 本番Functionsのデプロイ
- Providerや通知パッケージの即時削除
- v1画面や旧モデルの移動・削除
- AI認識機能の実装

既存コードを整理することより、v2の新しい入口と安全な実装場所を先に作る。

# 4. 着手前の手動作業

## 4.1 現行版の固定

実行前に必ず作業ツリーを確認する。

```bash
git status
git checkout main
git pull
```

クローズドテストへ配信しているコミットを確認し、復帰用タグを付ける。

```bash
git tag -a v1-closed-test-baseline-20260805 -m "Closed test baseline before v2 rebuild"
git push origin v1-closed-test-baseline-20260805
```

タグ名の日付は、実際の実施日に合わせて変更してよい。

## 4.2 v2ブランチ

```bash
git checkout -b develop-v2
git push -u origin develop-v2
```

Phase 1完了までは`main`へマージしない。

## 4.3 Firebaseの保全

コード変更前に次を保存する。

- Firebase Consoleで現在デプロイされているFirestore Rules
- Firebase Consoleで現在デプロイされているStorage Rules
- デプロイ済みFunctions一覧、リージョン、ランタイム
- Firestore indexes
- App Checkのenforcement状態
- Firestoreデータのバックアップまたは復元手順

公開リポジトリにないFunctionがデプロイ済みの場合、v2実装前にソースを同一リポジトリまたは明示した管理先へ回収する。

# 5. コミット分割

## P1-01: Phase 0文書をリポジトリへ配置

### コミット

```text
docs(v2): add phase 0 specifications and repository audit
```

### 対象

```text
docs/v2/
├ README.md
├ REQUIREMENTS_V2.md
├ USER_FLOWS_V2.md
├ SCREEN_SPEC_V2.md
├ DESIGN_SYSTEM_V2.md
├ DATA_MODEL_V2.md
├ FUNCTIONS_SPEC_V2.md
├ SECURITY_V2.md
├ ARCHITECTURE_V2.md
├ MIGRATION_PLAN_V2.md
├ TEST_PLAN_V2.md
├ IMPLEMENTATION_PLAN_V2.md
├ DECISIONS.md
├ OPEN_ISSUES.md
├ CHANGELOG_V2.md
├ REPOSITORY_AUDIT_V1.md
└ PHASE1_BOOTSTRAP_PLAN_V2.md
```

### 条件

- コード変更を含めない。
- 現行READMEはまだ大きく書き換えない。

---

## P1-02: 依存パッケージと空のv2構造を追加

### コミット

```text
chore(v2): add architecture dependencies and feature skeleton
```

### 追加候補

通常依存:

```text
flutter_riverpod
go_router
freezed_annotation
json_annotation
```

開発依存:

```text
build_runner
freezed
json_serializable
mocktail
```

パッケージの具体的なバージョンは、実装時点のFlutter/Dart SDKと互換する安定版を`flutter pub add`で解決し、`pubspec.lock`をコミットする。

### 空構造

```text
lib/
├ app/
│  ├ bootstrap/
│  ├ router/
│  └ theme/
├ core/
│  ├ errors/
│  ├ logging/
│  ├ result/
│  ├ firebase/
│  └ ui/
└ features/
   └ foundation/
      └ presentation/
```

### 注意

- 現行`provider`は削除しない。
- 現行`lib/screens`、`lib/services`、`lib/models`を移動しない。
- Freezed生成物が正常に作れる最小モデルだけ用意する。

---

## P1-03: BootstrapとRiverpodの入口を作る

### コミット

```text
refactor(app): add v2 bootstrap and provider scope
```

### 新規ファイル候補

```text
lib/app/bootstrap/app_bootstrap.dart
lib/app/bootstrap/bootstrap_config.dart
lib/app/bootstrap/bootstrap_result.dart
lib/app/vending_navi_app.dart
lib/core/firebase/firebase_providers.dart
```

### 変更

`main.dart`の責務を次に限定する。

```text
WidgetsFlutterBinding.ensureInitialized
→ bootstrap()
→ ProviderScope
→ VendingNaviApp
```

Firebase初期化、App Check、Emulator接続、起動エラー変換は`app_bootstrap.dart`へ移す。

### 互換方針

- Firebase初期化方法とApp Check providerは現行挙動を維持する。
- 起動失敗時の画面はv2共通エラー画面へ移す。
- このコミット時点では現行`StartupRouterScreen`を引き続き表示する。

### 完了条件

- 現行の起動フローが変わらず利用できる。
- `ProviderScope`が最上位に存在する。
- Bootstrap成功・失敗の単体テストが通る。

---

## P1-04: go_routerとv1/v2共存ルートを追加

### コミット

```text
feat(router): add v1 compatibility and v2 foundation routes
```

### ルート案

```text
/       → 現行StartupRouterScreen
/v2     → V2FoundationScreen
```

ルート名:

```text
legacyRoot
v2Foundation
```

### 起動切替

Dart defineで開発中の初期ルートを切り替えられるようにする。

```text
APP_ENTRY=legacy  // 既定値
APP_ENTRY=v2
```

起動例:

```bash
flutter run --dart-define=APP_ENTRY=v2
```

### 目的

- v1画面を壊さずv2画面を独立して確認する。
- Phase 3までは既定起動を`legacy`に保つ。
- v2 MVPが成立した段階で既定値を切り替える。

### 完了条件

- `/`で現行アプリが起動する。
- `/v2`でv2基盤確認画面が起動する。
- 戻る操作とディープリンクでクラッシュしない。

---

## P1-05: v2デザインシステムの最小実装

### コミット

```text
feat(theme): add v2 color tokens and shared components
```

### 新規ファイル候補

```text
lib/app/theme/v2_color_tokens.dart
lib/app/theme/v2_spacing.dart
lib/app/theme/v2_radius.dart
lib/app/theme/v2_theme.dart
lib/core/ui/buttons/v2_primary_button.dart
lib/core/ui/buttons/v2_secondary_button.dart
lib/core/ui/buttons/v2_map_action_button.dart
lib/core/ui/badges/v2_status_badge.dart
lib/core/ui/states/v2_empty_state.dart
lib/core/ui/states/v2_error_state.dart
lib/core/ui/states/v2_loading_state.dart
```

### 方針

- 既存`AppTheme`と`app_colors.dart`はv1用として残す。
- v2用テーマを別ファイルで作り、段階的に置き換える。
- デフォルトは白・水色・淡い青・濃すぎない青。
- `NotoSansJP`の同梱フォントを使用する。
- 既存`google_fonts`は、この段階では削除しない。
- 確認済み・推定・古い情報は色だけで区別しない。

### v2基盤確認画面

`V2FoundationScreen`に次を並べ、実機で見た目を確認する。

- 第一ボタン
- 第二ボタン
- 探す用の大きい丸ボタン
- 登録・マイ用の小さい丸ボタン
- 確認済み／あるかも／以前の情報ラベル
- Loading／Empty／Error状態

ここでの調整はデザイン方針内の「実機調整可能」とする。

---

## P1-06: 共通エラー・結果・ログ基盤

### コミット

```text
feat(core): add failure result and privacy safe logging
```

### 新規ファイル候補

```text
lib/core/errors/app_failure.dart
lib/core/errors/failure_mapper.dart
lib/core/result/app_result.dart
lib/core/logging/app_logger.dart
lib/core/logging/log_event.dart
```

### AppFailure初期セット

```text
NetworkFailure
AuthenticationFailure
PermissionFailure
ValidationFailure
RateLimitFailure
NotFoundFailure
FirebaseFailure
UnknownFailure
```

AI認識や重複登録専用Failureは、該当Phaseで追加する。

### ログ規則

記録してよいもの:

- 処理名
- 成功・失敗
- エラーコード
- 処理時間
- requestId
- アプリバージョン

記録しないもの:

- メールアドレス
- 写真URL
- 画像内容
- 正確な緯度経度
- フィードバック本文
- AIの生レスポンス

---

## P1-07: 本番と分離したFirebase Emulator基盤

### コミット

```text
chore(firebase): add isolated v2 emulator configuration
```

### 重要方針

現行`firebase.json`と`firestore.rules`は、v1運用との互換のためPhase 1では変更しない。

代わりに、ローカル開発専用設定を追加する。

```text
firebase.v2.json
firebase/v2/firestore.rules
firebase/v2/firestore.indexes.json
firebase/v2/storage.rules
functions/
```

### 初期Rules

Phase 1のv2用Rulesはdeny-by-defaultとする。

```text
Firestore: すべて拒否
Storage: すべて拒否
```

読み取り・書き込み権限は、各featureのテストと一緒に必要最小限だけ追加する。

### Functions

公開リポジトリに既存ソースがないため、v2用の新しいFunctionsプロジェクト構造を作る。

```text
functions/
├ src/
│  └ index.ts
├ test/
├ package.json
├ tsconfig.json
└ .gitignore
```

Phase 1では業務Functionを公開しない。`createVendingMachine`等は仕様とテストが揃ったPhaseで追加する。

既存`submitFeedback`のソースが回収できた場合は、内容を監査してから別コミットで統合する。

### Emulator接続

Dart define:

```text
USE_FIREBASE_EMULATORS=true
FIREBASE_EMULATOR_HOST=<開発PCのホスト>
```

- Android Emulator: 通常`10.0.2.2`
- 実機Pixel 6a: 開発PCのLAN IPを明示
- 本番ビルドではEmulator接続を強制的に無効化

### 起動コマンド例

```bash
firebase emulators:start --config firebase.v2.json \
  --only auth,firestore,functions,storage
```

```bash
flutter run \
  --dart-define=APP_ENTRY=v2 \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

PowerShell用スクリプトは、実際の開発環境でパスを確認してから追加する。

### 安全条件

- `firebase deploy`をPhase 1の完了条件に含めない。
- `firebase.v2.json`を明示しない限りv2 Rulesを使わない。
- 本番プロジェクトにdeny-all Rulesを誤配備しない。

---

## P1-08: テストと品質ゲート

### コミット

```text
test(v2): add bootstrap router theme and core tests
```

### テスト候補

```text
test/app/bootstrap/app_bootstrap_test.dart
test/app/router/app_router_test.dart
test/app/theme/v2_theme_test.dart
test/core/errors/failure_mapper_test.dart
test/core/result/app_result_test.dart
test/features/foundation/v2_foundation_screen_test.dart
```

### 必須コマンド

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

### Widgetテスト確認内容

- v2基盤画面が表示される。
- 探すボタンが登録・マイより大きい。
- 状態ラベルにアイコンと文言がある。
- テーマの主要色と角丸が適用される。
- 文字拡大時に主要ボタンが操作不能にならない。

# 6. Phase 1完了後のファイル構成

```text
lib/
├ main.dart
├ app/
│  ├ vending_navi_app.dart
│  ├ bootstrap/
│  │  ├ app_bootstrap.dart
│  │  ├ bootstrap_config.dart
│  │  └ bootstrap_result.dart
│  ├ router/
│  │  ├ app_router.dart
│  │  ├ app_route.dart
│  │  └ entry_mode.dart
│  └ theme/
│     ├ v2_color_tokens.dart
│     ├ v2_spacing.dart
│     ├ v2_radius.dart
│     └ v2_theme.dart
├ core/
│  ├ errors/
│  ├ firebase/
│  ├ logging/
│  ├ result/
│  └ ui/
├ features/
│  └ foundation/
│     └ presentation/
└ 既存v1コード一式
```

```text
firebase.v2.json
firebase/
└ v2/
   ├ firestore.rules
   ├ firestore.indexes.json
   └ storage.rules
functions/
docs/v2/
test/
```

# 7. Phase 1の完了条件

- 現行`main`へ復帰できるタグがある。
- `develop-v2`で作業している。
- 現行画面が従来どおり起動する。
- v2基盤画面を明示的に起動できる。
- Riverpodとgo_routerがアプリ入口へ導入されている。
- Freezedとjson_serializableの生成が成功する。
- v2テーマと共通UIの最小セットがある。
- Firebase初期化がBootstrapへ分離されている。
- 本番設定を変更せずEmulatorを起動できる。
- v2用Firestore／Storage Rulesがdeny-by-defaultである。
- Functionsの管理場所がリポジトリ内に作られている。
- `flutter analyze`が成功する。
- Phase 1で追加したテストがすべて成功する。
- Pixel 6aでlegacy起動とv2起動を確認できる。
- `CHANGELOG_V2.md`と`IMPLEMENTATION_PLAN_V2.md`を更新している。

# 8. Phase 1で中止・切り戻しする条件

- 現行クローズドテスト画面が起動しなくなる。
- Firebase本番データへ意図しない書き込みが発生する。
- 既存認証ユーザーがログインできなくなる。
- パッケージ追加によりAndroidビルドが成立しない。
- App Check設定が本番利用へ影響する。
- v1コードを大規模に修正しないと基盤を導入できない。

問題が出た場合はコミット単位で戻し、複数コミットをまとめて修正しない。

# 9. Phase 2へ進む条件

Phase 1完了後、次を確認してから旧データ互換へ進む。

1. 現行Flutterコードのローカル二次監査が完了している。
2. デプロイ済みFunctionsとStorage Rulesの実体を確認している。
3. Product ID命名規則の案を承認している。
4. v1 fixtureをFirestore実データから匿名化して用意できる。
5. DTO／Mapperテストの入力例が揃っている。

