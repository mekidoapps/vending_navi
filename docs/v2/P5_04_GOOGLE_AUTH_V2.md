# P5-04 Googleログイン

> 更新日: 2026-08-09
> 対象: VendingNavi v2 Phase 5

## 方針

既存repoの`google_sign_in ^6.3.0`を維持する。

P5-04では認証機能追加とmajor dependency migrationを同時に行わない。
7.x migrationは別作業とする。

## フロー

```text
GoogleSignIn
→ Google tokens
→ Firebase Google credential
→ FirebaseAuth
→ AuthUserDto
→ AuthSession
```

Plugin/Firebase型をPresentationへ出さない。

## cancel

Google account chooserを閉じた場合は:

```text
GoogleSignInCancelled
→ エラー表示なし
→ Auth画面に残る
```

とする。

## UI

P5-03の`/v2/auth/email`を共通Auth画面として使う。

```text
メール認証
────────
または
[ Googleで続ける ]
```

## 実機設定

Android実機成功にはFirebase Console側で:

- Google provider enabled
- debug SHA-1登録済み

が必要。

repo側のconfig存在とsigning reportは
`phase5_p504_google_config_audit.sh`で確認する。

## Emulator

Auth EmulatorはGoogle等のOpenID Connect providerの
実ID tokenを使う`signInWithCredential` flowをテストできる。

ただしP5-04時点ではHomeMapからAuth画面への導線がまだないため、
Google実機acceptanceはP5-05でAuth Gateを接続した直後に実施する。

## P5-05へ

```text
未ログイン
→ 登録
→ Auth画面
→ メール / Google
→ 成功
→ 元Actionへ復帰
```
