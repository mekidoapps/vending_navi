# P5-01 認証・ユーザー設計 / v1監査

> 更新日: 2026-08-09

## 1. 目的

v1には認証実装履歴があるため、
v2でFirebase Authenticationをゼロから重複実装しない。

一方でv1 UI・巨大画面・直接Firebase依存を
そのままv2へ持ち込まない。

P5-01では:

```text
再利用するもの
捨てるもの
互換だけ残すもの
```

を現行repoから確認する。

## 2. 仕様側で既に確定していること

- Firebase Authenticationを利用する。
- メールアドレス認証を利用する。
- GoogleログインをMVPへ含める。
- Appleログインは将来対応。
- 閲覧・検索は未ログインで利用できる。
- 投稿系操作はログイン必須。
- 既存Firebase環境は可能な範囲で再利用する。
- 既存本番データを壊さない。

したがってP5-01で再議論しない。

## 3. 監査対象

### dependencies

- firebase_auth
- google_sign_in
- sign_in_with_apple
- shared_preferences等の旧ログイン状態保存
- Firebase関連plugin

### source

- FirebaseAuth直接利用箇所
- authStateChanges / userChanges
- currentUser
- email/password sign-in
- create user
- sign out
- Google credential
- login/register screen
- auth guard
- users collection
- favorite_products / favorites
- MyPage
- router login route

### tests

- auth unit/widget test
- emulator auth test
- login after navigation test

### platform

中身は表示せず存在だけ確認:

- android/app/google-services.json
- Google services Gradle plugin
- iOS GoogleService-Info.plist

## 4. 監査で出してはいけないもの

監査スクリプトは以下の内容をcatしない。

- google-services.json
- GoogleService-Info.plist
- firebase_options.dart
- .env
- API key
- OAuth client secret
- signing key
- keystore

Firebase設定ファイルは「存在する / しない」のみ。

## 5. 判定ルール

### 再利用候補

次を満たすもの:

- Firebase Auth設定
- Emulator接続
- Firebase初期化
- 安定して動いているplatform設定
- v2レイヤーへ包める小さなService
- テスト済みの例外処理

### v2へ直接持ち込まない

- ScreenからFirebaseAuthを直接呼ぶ処理
- `main_shell_screen.dart`等の巨大UIに埋まった認証処理
- SharedPreferencesだけでログイン状態を正本化する実装
- Firebase Userをアプリ全体へ直接渡す構造
- 認証後の遷移先を固定画面へハードコードする実装
- 本番Rulesを前提にしたテスト

### 互換確認

- `users/{uid}`旧schema
- 旧favorites
- displayName
- 旧投稿者uid
- 匿名ユーザー履歴が存在する場合

## 6. P5-02へ進む条件

監査結果から以下を確定する。

```text
firebase_auth dependency: reuse / add
Google sign-in dependency: reuse / add / replace
v1 AuthService: reuse logic / reference only / discard
v1 login UI: reuse / discard
users schema: compatible / bridge required
favorites schema: compatible / migrate later
Google Android config: ready / needs console work
```

P5-02ではこの結果を前提にAuth Domainから作る。

## 7. 現時点での仮置き禁止

監査前に以下を決め打ちしない。

- 新しいGoogle OAuth client ID
- 新しいFirebase project
- users schemaの破壊変更
- 旧favorite削除
- production Rules変更
- Apple dependency追加


## 8. 2026-08-09 監査結果

現行repo監査結果から、P5-02以降の扱いを以下で固定する。

### 8.1 dependencies / Firebase基盤

- `firebase_auth ^5.7.0` → **reuse**
- `google_sign_in ^6.3.0` → **reuse**
- `firebase_core` → **reuse**
- v2 `firebaseAuthProvider` → **reuse**
- Auth Emulator connector → **reuse**
- Android `google-services.json` → **存在確認済み**
- iOS `GoogleService-Info.plist` → **存在確認済み**
- Android Google Services Gradle plugin → **設定確認済み**
- `sign_in_with_apple` → **MVPでは追加しない**

Google OAuth / SHA / Firebase Console上の有効化状態はrepo監査だけでは確定できない。
P5-04のAndroid実機テストで最終確認する。

### 8.2 v1 LoginScreen

v1にはメール認証とGoogle credential flowの実装履歴がある。

ただし、

- `FirebaseAuth.instance`直接依存
- `GoogleSignIn`直接生成
- Firebase例外処理がPresentation内
- Googleキャンセルをエラー表示
- sign-in前にGoogle signOut

という構造のため、

```text
認証API利用方法 / Google credential flow
→ reference

v1 LoginScreen本体
→ discard for v2
```

とする。

### 8.3 v1 AuthService

`authStateChanges`、メールlogin/register、password reset、sign-out等の
Firebase API wrapperとしては参照できる。

ただしFirebase `User` / `UserCredential`を直接返し、
AppFailure境界・Riverpod DIがないため、

```text
v1 AuthService
→ reference only
```

P5-02ではv2 DataSource / Repositoryとして再構築する。

anonymous sign-inはMVP対象外。

### 8.4 v1 AuthGate

既存の

```text
閲覧・検索はゲスト利用可能
登録・お気に入りはログイン必須
```

というUX思想はv2仕様と一致する。

```text
UX / Action境界
→ reuse concept

v1 widget実装
→ reference only
```

P5-05でv2 Auth Gateとして再実装する。

### 8.5 users/{uid}

既存repoでは`users/{uid}`が既に複数用途で使われている。

監査で確認できた例:

- `defaultDistanceMeters`
- displayName関連
- progress関連
- notification settings
- `favoriteDrinkNames`

したがって、

```text
users/{uid}
→ bridge required
```

新しいv2 profile schemaで既存docを上書きしない。
P5-06で既存フィールド保持を前提に設計する。

### 8.6 favorites

旧実装:

1. Firestore `users/{uid}`内の`favoriteDrinkNames`
2. SharedPreferencesベースの`FavoriteService`

v2正本:

```text
users/{uid}/favorite_products/{productId}
```

判定:

```text
favoriteDrinkNames
→ migration / fallback bridge required

SharedPreferences FavoriteService
→ v2の正本にはしない
```

旧文字列はP5-07でProduct masterに明確一致するものだけfallback対象とし、
曖昧名を自動変換しない。

### 8.7 Auth session / tests

SharedPreferencesをAuth sessionの正本にしている証拠はない。

```text
Auth session正本
→ Firebase Authentication
```

Auth専用testは監査上見つからなかったため、
P5ではDomain / Repository / Emulator / Auth Gate / Google実機testを新規構築する。

### 8.8 最終判定

| 対象 | 判定 |
|---|---|
| Firebase project / 初期化 | reuse |
| `firebase_auth` | reuse |
| `firebaseAuthProvider` | reuse |
| Auth Emulator connector | reuse |
| `google_sign_in` | reuse |
| Android/iOS Firebase files | reuse |
| v1 Google credential flow | reference |
| v1 `LoginScreen` | discard for v2 |
| v1 `AuthService` | reference only |
| v1 AuthGate UX | reuse concept |
| v1 AuthGate widget code | reference only |
| `users/{uid}` | bridge required |
| `favoriteDrinkNames` | migrate/fallback later |
| SharedPreferences favorite | discard as v2 source of truth |
| anonymous sign-in | out of MVP |
| Apple sign-in | future |
| Auth tests | build new |
| production Rules | P5-01では変更しない |

## 9. P5-02開始条件

P5-02では、

```text
FirebaseAuth
→ AuthDataSource
→ AuthRepository
→ AuthUser / AuthSession
→ Riverpod
```

の骨格だけを作る。

まだ以下は実装しない。

- Login UI
- Google login UI
- users write
- favorites migration
- production Rules変更

これによりP5-01を完了とする。
