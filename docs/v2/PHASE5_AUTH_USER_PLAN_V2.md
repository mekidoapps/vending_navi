# Phase 5 認証・ユーザー 実装計画

> 更新日: 2026-08-09
> 対象: VendingNavi v2

## 1. Phase 5の目的

閲覧・検索を未ログインのまま利用できる状態を維持しつつ、
投稿系操作・ユーザー固有機能だけを認証へ接続する。

MVP認証:

- メールアドレス
- Google

将来:

- Apple

Phase 5ではAppleを実装しない。

## 2. 認証境界

未ログインで利用可能:

- HomeMap表示
- 現在地表示
- Product検索
- Genre検索
- 自販機詳細
- 外部Google Maps経路

ログイン必須:

- 自販機登録
- 自販機更新
- 商品更新
- 写真投稿
- 売り切れ更新
- 報告
- フィードバック
- よく飲む商品の保存・削除
- 投稿履歴
- ユーザー固有設定

「マイ」は未ログインでも押せる。
未ログイン時はログイン導線を表示する。

## 3. v2認証アーキテクチャ

```text
FirebaseAuth
  ↓
AuthDataSource
  ↓
AuthRepository
  ↓
AuthSession / AuthUser
  ↓
AuthController (Riverpod Notifier)
  ↓
Presentation
```

Firebaseの`User`をPresentationへ直接流さない。

Domainでは最低限:

- uid
- email
- displayName
- providerIds
- emailVerified

を扱う。

## 4. users

Firestore:

```text
users/{uid}
```

MVPユーザー情報候補:

```text
uid
displayName
createdAt
updatedAt
```

メールアドレスをFirestoreへ重複保存する必要はない。
Firebase Authenticationを正本とする。

既存users schemaがある場合はP5-01監査後に互換方針を決める。

## 5. よく飲む商品

```text
users/{uid}/favorite_products/{productId}
```

Phase 4で作成した:

```text
V2ProductSearchPanel.frequentProducts
```

へPhase 5で実データを接続する。

Product自体をユーザードキュメントへ複製せず、
Product IDを保存する。

## 6. 中断フロー復帰

ログインが必要な操作を未ログインで押した場合:

```text
ユーザー操作
→ Auth required
→ ログイン
→ 成功
→ 元の操作へ戻る
```

MVPで最低限必要:

- HomeMap「登録」
- よく飲む商品追加

後続Phaseの報告・更新・写真投稿も同じ仕組みを再利用する。

ログイン後に常にHomeMap先頭へ飛ばさない。

## 7. エラー

Firebase例外文字列をそのままUIへ表示しない。

既存`AppFailure`へ変換する。

対象例:

- invalid credential
- email already in use
- weak password
- network
- cancelled Google sign-in
- disabled user
- too many requests
- unknown Firebase error

Googleログインのユーザーキャンセルは、
赤いエラー画面ではなく「何も変更しない」扱いを基本とする。

## 8. セキュリティ

- 認証状態だけでFirestore client writeを許可しない。
- 公開データwriteはPhase 0方針どおりCallable Functions経由。
- `users/{uid}`および`favorite_products`のclient write方針はP5実装時に個別決定する。
- 本番RulesはP5品質ゲートまで勝手に変更しない。
- App Check enforcementは段階導入を維持する。

## 9. 実装分割

### P5-01 認証・ユーザー設計 / v1監査
- [x] 確定要件整理
- [x] 監査スクリプト
- [x] 現行repo監査結果レビュー
- [x] 再利用・廃止リスト確定

### P5-02 Auth Domain / Repository骨格
- [x] AuthUser
- [x] AuthSession
- [x] AuthRepository interface
- [x] Firebase DTO / Mapper
- [x] authStateChanges
- [x] Fake DataSource unit tests
- [x] 実Auth Emulator email test（P5-03で実施）

### P5-03 メール認証
- [x] メールログイン
- [x] 新規登録
- [x] サインアウト
- [x] パスワード再設定
- [x] 入力validation
- [x] Firebase例外→AppFailure
- [x] UI
- [x] Auth Emulator gate

### P5-04 Googleログイン
- [x] 既存`google_sign_in ^6.3.0`継続
- [x] Google plugin境界
- [x] Firebase credential境界
- [x] Google sign-in
- [x] cancel/error
- [x] UI
- [x] local config audit
- [x] Android実機acceptance（P5-05で確認済み）

### P5-05 Auth Gate / 中断フロー復帰
- [x] 認証必須Action abstraction
- [x] HomeMap登録
- [x] ログイン後復帰
- [x] 二重実行防止
- [x] back/cancel

### P5-06 users / マイページ基礎
- [x] users schema互換
- [x] profile read
- [x] displayName
- [x] ログイン状態表示
- [x] logout

### P5-07 favorite_products / よく飲む商品
- [x] Product ID保存
- [x] 重複防止
- [x] 削除
- [x] P4-06表示領域へ実データ接続
- [x] 未ログイン導線

### P5-08 Phase 5品質ゲート
- [x] Email Emulator
- [x] Google実機
- [x] 未ログイン閲覧回帰
- [x] Auth gate回帰
- [x] favorite_products
- [x] responsive
- [x] full regression

## 10. Phase 5完了条件

```text
未ログイン
→ 検索・詳細は利用可能

登録を押す
→ ログイン要求
→ メール / Google
→ 成功
→ 登録フローへ復帰

ログイン済み
→ マイページでユーザー状態確認
→ よく飲む商品を保存
→ 検索パネルへ表示
```

まで成立すること。


### P5-05 Auth Gate / interrupted flow resume
- [x] AuthRequiredActionRunner
- [x] Login Required Sheet
- [x] interrupted action
- [x] resume original action
- [x] HomeMap registration callback gate
- [x] cancel時は元Action未実行
