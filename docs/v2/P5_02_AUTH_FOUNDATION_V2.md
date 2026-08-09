# P5-02 Auth Domain / Repository骨格

> 更新日: 2026-08-09
> 対象: VendingNavi v2 Phase 5

## 1. 目的

Firebase Authenticationをv2 Presentationへ直接露出させず、
後続のメール認証・Google認証・Auth Gateが共通利用できる認証境界を作る。

P5-02ではログイン操作自体はまだ実装しない。

## 2. レイヤー

```text
FirebaseAuth
  ↓
FirebaseAuthDataSource
  ↓
AuthUserDto
  ↓
AuthRepositoryImpl
  ↓
AuthUser / AuthSession
  ↓
Riverpod Providers
```

PresentationはFirebase `User` / `UserCredential`を扱わない。

## 3. AuthUser

Domainで保持する:

```text
uid
email
displayName
providerIds
emailVerified
```

`providerIds`例:

```text
password
google.com
```

重複・空文字を除去し、安定した順番で保持する。

`uid`空文字はDomainで拒否する。

## 4. AuthSession

認証状態をnullable Firebase Userとして扱わない。

```text
GuestAuthSession
AuthenticatedAuthSession(AuthUser)
```

共通:

```text
isAuthenticated
userOrNull
```

を提供する。

## 5. DataSource

P5-02:

```text
currentUser
authStateChanges()
```

だけを定義する。

以下はP5-03以降:

- email sign-in
- email register
- password reset
- sign-out
- Google credential sign-in

これによりP5-02の変更量を小さくする。

## 6. Repository

```text
currentSession
watchSession()
```

だけを公開する。

Firebase型をDomain境界より上へ出さない。

## 7. Riverpod

追加:

```text
authDataSourceProvider
authRepositoryProvider
authSessionChangesProvider
authCurrentSessionProvider
```

既存:

```text
firebaseAuthProvider
```

を再利用する。

`FirebaseAuth.instance`を新しいv2 featureから直接呼ばない。

## 8. Emulator

Auth Emulator接続はPhase 1の既存bootstrapを再利用する。

P5-02のunit testはFake DataSourceでRepository境界を検証する。

Firebase Auth Emulatorを使った実際のemail sign-in/register testは
P5-03で追加する。

## 9. P5-02で変更しないもの

- Login UI
- Router
- HomeMap登録Action
- Google login
- users/{uid}
- favorite_products
- Firestore Rules
- production firebase.json
- Apple login
- anonymous login

## 10. P5-03へ

次はメール認証。

Repositoryへ:

```text
signInWithEmail
registerWithEmail
signOut
password reset
```

を追加し、
FirebaseAuthExceptionを安全な`AppFailure`へ変換する。

UIはRepository完成後に接続する。
