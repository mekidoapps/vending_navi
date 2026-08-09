# P5-03 メール認証

> 更新日: 2026-08-09
> 対象: VendingNavi v2 Phase 5

## 1. 目的

P5-02の認証境界へFirebase Email/Password認証を追加する。

対象:

- メールログイン
- メール新規登録
- ログアウト
- パスワード再設定
- Firebase Auth例外の安全なAppFailure変換
- v2メール認証画面
- Auth Emulator gate

GoogleログインはP5-04。

## 2. Repository

追加:

```text
signInWithEmail
registerWithEmail
signOut
sendPasswordResetEmail
```

PresentationはFirebase `UserCredential`を扱わない。

成功時は`AuthSession`を返す。

## 3. Validation

クライアント側で最低限:

- email必須
- email形式
- password必須
- password 6文字以上
- 登録時password確認一致

を検証する。

Firebase側でより強いpassword policyが設定されている場合、
`weak-password`を安全なUI文言へ変換する。

## 4. Firebase Auth error

例:

```text
invalid-credential
wrong-password
user-not-found
```

はすべて、

```text
メールアドレスまたはパスワードを確認してください。
```

へ統一する。

ログインUIからアカウントの存在有無を特定しにくくする。

password resetで`user-not-found`が返った場合も成功扱いとし、
アカウント存在をUIへ出さない。

## 5. v2 Email Auth Screen

Route:

```text
/v2/auth/email
```

画面:

```text
ログイン / 新規登録切替
メールアドレス
パスワード
確認パスワード（登録時）
送信
パスワード再設定
```

地図閲覧・検索は未ログインで利用できることを明記する。

P5-03ではHomeMapの登録ボタンへまだ接続しない。
P5-05 Auth Gateからこのrouteをpushして、
成功後に元Actionへ復帰する。

## 6. Google

P5-03画面にはGoogleを実装しない。

P5-04で同じ認証画面へ追加する。

## 7. Auth Emulator

```bash
bash tool/phase5_p503_auth_emulator_gate.sh vendingnavi
```

確認:

```text
email register
email sign-in
password reset request
```

本番Authデータを使用しない。

## 8. 非変更

- users/{uid}
- favorite_products
- HomeMap Auth Gate
- Firestore Rules
- Functions
- production firebase.json
- Apple
- anonymous auth

## 9. P5-04へ

次はGoogleログイン。

既存:

- `google_sign_in ^6.3.0`
- Android/iOS Firebase設定
- v1 Google credential flow

を参照しつつ、
v2 DataSource / Repository / Controllerへ追加する。

Google cancelはFailure表示にしない。
