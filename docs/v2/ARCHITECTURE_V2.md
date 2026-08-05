> 文書状態: Phase 0 正式版（実装前基準）  
> 更新日: 2026-08-04  
> 対象: 自販機ナビ / VendingNavi v2  
> パッケージID: `com.mekidoapps.vendingnavi`  
> リポジトリ: `mekidoapps/vending_navi`


# アーキテクチャ

## 1. 採用構成【確定】

- Feature-first
- レイヤードMVVM
- Riverpod 3 (`Notifier` / `AsyncNotifier`)
- `go_router`
- Freezed
- `json_serializable`
- Firestore DTOとDomain Modelの分離
- Repository経由のデータアクセス
- 複雑な処理のみUseCaseへ分離

## 2. 依存方向

```text
View / Widget
→ ViewModel / UI State
→ UseCase（必要な場合）
→ Repository interface
→ Repository implementation
→ Service
→ Firestore / Functions / Storage / Maps / Auth / Location
```

外部データは逆方向に変換してViewへ届く。ViewからFirebase SDKを直接呼ばない。

## 3. レイヤー責務

### Presentation

- Screen
- Widget
- ViewModel
- UI State

Viewは表示・入力伝達・レイアウト・画面内アニメーションを担当する。検索クエリ、Firestore構造、距離判定等を持たない。

### Domain

- Entity
- Value Object
- Repository interface
- UseCase

Firebase固有の`Timestamp`、`GeoPoint`、ドキュメントパスを画面へ漏らさない。

### Data

- DTO
- Mapper
- Repository implementation
- Service

ServiceはSDKや外部APIを薄く包み、旧形式互換・キャッシュ・変換・再試行はRepositoryで扱う。

## 4. UseCase候補

- `SearchNearbyMachinesUseCase`
- `CreateMachineFromPhotoUseCase`
- `CreateMachineFromManufacturerUseCase`
- `UpdateMachineProductsUseCase`
- `RecognizeMachinePhotoUseCase`
- `SubmitMachineReportUseCase`

単純なマスタ取得はViewModelからRepositoryを利用してよい。全操作に機械的にUseCaseを作らない。

## 5. 状態管理

### アプリ共有状態

- 認証ユーザー
- 選択テーマ
- よく飲む商品
- 商品・メーカーマスタ
- 位置情報権限
- 現在地
- Firebase等の依存オブジェクト

### ホーム画面状態

```text
selectedSearchCondition
selectedMachineId
visibleMachines
mapLoadingState
searchPanelState
```

### 登録フロー状態

```text
selectedLocation
registrationMethod
temporaryPhoto
recognizedManufacturer
recognizedProducts
confirmedProducts
registrationStep
submissionState
```

登録完了または中止時に破棄する。

### Widgetローカル状態

- TextEditingController
- FocusNode
- カメラプレビュー
- スクロール位置
- 短命なアニメーション

## 6. 非同期状態

一つの巨大enumではなく画面ごとの不変Stateで表す。

```text
initial
loading
data
empty
error
submitting
success
```

`AsyncValue`と画面固有Stateを組み合わせ、読み込みと送信を必要に応じて分ける。

## 7. データモデル

### DTO

```text
VendingMachineDocument
LegacyVendingMachineDocument
MachineProductDocument
ProductDocument
ManufacturerDocument
MachineReportDocument
```

### Domain

```text
VendingMachine
MachineProduct
Product
Manufacturer
SearchCondition
RegistrationDraft
```

### Mapper

旧・新Firestore形式、`Timestamp`、`GeoPoint`、欠損値をDomainへ変換する。

## 8. ルーティング

```text
/
/login
/machine/:machineId
/register/position
/register/method
/register/photo
/register/recognition
/register/manufacturer
/register/confirm
/machine/:machineId/update
/machine/:machineId/report
/favorites
/profile
/feedback
```

登録フローは専用Scopeで下書きを保持する。ログイン後のreturn locationまたは明示的な復帰情報を持つ。

## 9. フォルダ構成

```text
lib/
├ app/
│  ├ app.dart
│  ├ bootstrap.dart
│  ├ router/
│  └ theme/
├ core/
│  ├ errors/
│  ├ result/
│  ├ firebase/
│  ├ location/
│  ├ logging/
│  ├ constants/
│  └ ui/
├ features/
│  ├ auth/
│  ├ home_map/
│  ├ product_search/
│  ├ machine_detail/
│  ├ machine_registration/
│  ├ machine_update/
│  ├ machine_report/
│  ├ favorite_products/
│  ├ feedback/
│  └ profile/
└ main.dart
```

各feature:

```text
feature/
├ presentation/
│  ├ screens/
│  ├ widgets/
│  ├ view_models/
│  └ states/
├ domain/
│  ├ entities/
│  ├ repositories/
│  └ use_cases/
└ data/
   ├ dto/
   ├ mappers/
   ├ repositories/
   └ services/
```

実際に2機能以上で共有するまで、Widgetを早期に`core`へ移さない。

## 10. Service候補

- `FirebaseAuthService`
- `FirestoreMachineService`
- `CallableFunctionsService`
- `StoragePhotoService`
- `LocationService`
- `MapNavigationService`
- `PhotoRecognitionService`（Functions呼び出しの抽象）

## 11. エラー変換

```text
Firebase / SDK Exception
→ Serviceで捕捉
→ RepositoryでAppFailureへ変換
→ ViewModelで画面文言・次の操作へ変換
```

### `AppFailure`候補

- NetworkFailure
- AuthenticationFailure
- PermissionFailure
- ValidationFailure
- RateLimitFailure
- NotFoundFailure
- PhotoRecognitionFailure
- DuplicateRequestFailure
- UnknownFailure

## 12. オフライン

### 閲覧

Firestoreキャッシュ等で取得済み情報を表示し、「保存済みの情報を表示しています」と示す。

### 登録・更新

MVPでは永続的な自動同期キューを作らない。

- 画面を閉じない限り下書きを保持
- 再試行可能
- AI失敗時は別ルート
- 二重送信はrequestIdで防止

端末永続下書きはテスト後の将来候補。

## 13. テスト可能性

- Service: SDK入出力・例外変換
- Mapper: v1/v2変換
- Repository: 互換・キャッシュ・エラー
- UseCase: 業務ルール
- ViewModel: 状態遷移
- Widget: 表示・操作
- Firebase Emulator: Rules / Functions / Storage

## 14. 実装上の禁止事項

- ScreenからFirestore直接アクセス
- FirestoreドキュメントをそのままUIモデルとして使用
- グローバルな可変singletonへ画面状態を保存
- 旧`main_shell_screen.dart`へv2機能を追加し続ける
- AI候補をUI確認なしでRepositoryへ確定保存
- 文字列`contains`だけを商品識別に使用
