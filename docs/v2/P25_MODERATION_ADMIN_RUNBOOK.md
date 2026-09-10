# VendingNavi モデレーション管理運用 Runbook

## 1. 目的と通常経路

`/admin` は、通報・修正提案に対する運営管理者用画面である。通常のモデレーションは管理キューを起点とし、任意の対象を直接指定する緊急経路は使用しない。

通常経路は、キュー確認、確認開始、対象詳細確認、変更計画の確認、措置なし・却下・承認済み措置の実行である。

## 2. セキュリティ境界

- Firebase Authenticationで正式な管理用アカウントを認証する。
- Web App Check（reCAPTCHA Enterprise）が有効なリクエストだけを使用する。
- Functions側で`admin: true`と`users/{uid}.accountStatus == active`を確認する。
- クライアント表示やクライアント側claim判定を認可境界にしない。
- Firestore、Storage、Admin SDKへ管理Webから直接アクセスしない。

## 3. 管理者の初期登録

正式な管理者identity操作には`tool/manage_moderation_admin.cjs`を使用する。Functionsに固定された既存Firebase Admin SDKと、承認済みのtrusted環境で利用できるApplication Default Credentials（ADC）だけを使用する。service account JSON、秘密鍵、UID、メールアドレス、tokenをリポジトリや運用記録へ保存しない。

実行前に環境のproject IDを`vendingnavi`へ明示し、ツール自身のproject guardを通す。対象アカウントはコマンド引数にせず、起動後のpromptへUIDまたはメールアドレスを入力する。

Node 22と既存のFunctions依存が前提である。clean source-lock worktreeに`functions/node_modules`がない場合は、既存依存を持つ検証済みFunctions package rootの絶対パスを`VENDING_NAVI_FUNCTIONS_ROOT`へprocess-localに指定する。ツールは指定先の実在、`package.json`のpackage名、`firebase-admin`依存、Admin SDKのpackage exportsを検証する。個人環境固有の絶対パスはsourceや運用記録へ残さない。

Production bootstrap中にツールからnpm installを行わない。依存を解決できない場合は操作せず停止する。ADCやProduction APIを使わずmodule解決だけを確認する場合は、先に次を実行する。

```text
node tool/manage_moderation_admin.cjs runtime-check
node tool/manage_moderation_admin.cjs status
node tool/manage_moderation_admin.cjs grant
node tool/manage_moderation_admin.cjs revoke
```

`status`はAuth account、admin claim、`users/{uid}.accountStatus`の安全な要約だけを読み取る。`grant`はuser documentが存在し、`accountStatus == active`の場合だけ確認後に`admin: true`を追加する。`revoke`はadmin claimだけを削除し、他claimを維持したうえでrefresh tokenを失効する。このツールは`accountStatus`を変更しない。

Production bootstrapは次の順序に固定する。

1. source lock済みのclean環境を用意する。
2. trusted環境のADCとproject IDを確認する。
3. `status`を実行する。
4. `grant`を実行し、表示された確認に明示同意する。
5. 再度`status`を実行する。
6. 対象管理者アカウントをログアウトし、再ログインする。
7. `/admin`のProduction smokeを実施する。
8. 緊急時に同じ環境から`revoke`を実行できることを確認する。ただし平常時にrevokeを試行しない。

1. 既存の正式なFirebase Authアカウントを管理者候補として選定する。
2. 承認済み管理環境から対象アカウントへ`admin: true`を付与する。
3. 対象ユーザーの`accountStatus`が`active`であることを確認する。
4. 対象アカウントを再ログインさせ、更新済みID tokenを取得する。
5. `/admin`へログインする。
6. 管理キュー、対象詳細、plan previewまでを確認し、不要なmutationを実行しない。

UID、token、秘密鍵、credential値は運用記録へ転記しない。実施記録には日時、承認者、目的、結果だけを必要最小限で残す。

## 4. 管理者権限の失効

1. 承認済み管理環境で`admin` claimを削除する。
2. 対象アカウントのrefresh tokenをrevokeする。
3. インシデントの内容に応じて`accountStatus`を`restricted`または`suspended`へ変更する。
4. 既存セッションを終了し、再ログイン後に`/admin`が汎用拒否画面になることを確認する。

claim削除、token失効、アカウント状態変更は別々の防御であり、必要な措置を省略しない。

緊急失効時も同じtrusted環境から`revoke`を実行し、完了後に`status`でadmin claimが無効になったことと、対象アカウントの次回ログインで`/admin`が拒否されることを確認する。

## 5. 通常運用

1. 管理キューを更新する。
2. 対象項目を選び、必要なら「確認を開始」で`inReview`へ進める。
3. safe target detailを確認する。
4. actionを選び、理由を1〜500文字で記録する。
5. plan previewと変更前後、Storage・indexへの影響を確認する。
6. 措置不要なら`noAction`、対象外なら`rejected`、措置が必要なら許可された`actionTaken`を実行する。

reasonにはメールアドレス、UID、token、秘密情報、内部パス、不要な個人情報を記載しない。

## 6. 正式写真の削除

- 写真削除は`resolutionPending`を経由し、Storage削除と確定処理を行う。
- 処理中は別actionを開始しない。
- 失敗後の再試行は管理画面の明示操作で行い、同一requestIdを使用する。
- Storage object path、bucket、private metadataを表示・手動操作しない。
- 状態が不明な場合はキューを更新し、自動再送しない。

## 7. インシデント対応

### 管理者アクセスの漏えい

admin claim削除、refresh token revoke、必要なaccountStatus制限を直ちに行う。影響期間とモデレーション監査記録を確認する。

### 誤ったモデレーション

追加操作を止め、対象・queue・auditの状態を確認する。Productionデータを推測で直接書き戻さず、レビュー済み復旧計画を作成する。

### Hosting UIの不具合

管理Webの利用を停止し、既知の正常なGit SHAからHostingだけを戻す。Functions、indexes、Rules、Storage、Productionデータは同時にrollbackしない。

### Functionsまたはbackendの不具合

管理Webからのmutationを停止する。Functionsの既知正常SHAとqueueの状態を確認し、Functionsの復旧手順を別途レビューする。Hosting rollbackだけでbackend状態を変更しない。

## 8. Hosting rollback

管理Webだけに問題がある場合は、既知正常SHAのHosting sourceを検証し、Hosting限定deployを行う。Functions、Firestore indexes、Firestore/Storage Rules、Lifecycle、Productionデータを変更対象へ含めない。

管理者アカウント侵害はHosting rollbackでは解消しないため、権限失効手順を独立して実施する。

## 9. Production smoke

### 一般ユーザー拒否

1. Production `/admin`へアクセスする。
2. Play版で利用中の一般ユーザーとは分離された通常アカウントでログインする。
3. 汎用アクセス拒否が表示されることを確認する。
4. queue、target、planが表示されず、mutationが実行されていないことを確認する。

### 管理者read-only確認

1. 正式管理者でログインする。
2. queue一覧を確認する。
3. 対象詳細を確認する。
4. plan previewまで確認する。
5. private identity、内部path、token、raw responseが表示されないことを確認する。

### 最小mutation確認

識別可能で安全に処理できるtest reportまたはcorrectionが既に存在する場合に限り、1件だけ`mark inReview`後、`noAction`または`rejected`で完了する。machine、product、user、photoへの破壊的actionは初回smokeで実施しない。

安全なtest queue itemが存在しない場合はmutation smokeを`WAIVED`と記録し、一般公開後の最初の正規queue itemを処理する際に同じ確認を実施する。

## 10. 監査衛生

- 運用記録へUID、メールアドレス、token、secret、credential、Firestore/Storage pathを残さない。
- reasonは判断に必要な最小限の内容にする。
- raw Callable responseやstack traceを貼り付けない。
- Production smokeでは実施者、承認者、日時、対象種別、操作結果、WAIVED理由だけを記録する。
