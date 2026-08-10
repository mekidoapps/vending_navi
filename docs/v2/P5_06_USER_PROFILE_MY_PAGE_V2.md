# P5-06 users / v2マイページ基礎

> 更新日: 2026-08-09
> 対象: VendingNavi v2

## 1. 監査結果

既存`users/{uid}`はv1で複数用途に利用されている。

代表例:

```text
appDisplayName
displayName
defaultDistanceMeters
favoriteDrinkNames
registeredMachineCount
registeredDrinkCount
checkinCount
exp
level
titles
currentTitle
notificationsEnabled
...
```

したがってP5-06では`users/{uid}`を新schemaで置換しない。

## 2. bridge方針

v2 profileが読む表示名は次の優先順位とする。

```text
appDisplayName
→ displayName
→ Firebase Auth displayName
→ email local-part
→ ユーザー
```

Firestore DTOは既知のprofile fieldだけを読む。
未知のlegacy fieldは拒否せず無視する。

writeは`SetOptions(merge: true)`で行い、
既存legacy fieldを削除・再生成しない。

v2で表示名を変更した場合はv1互換のため:

```text
appDisplayName
displayName
```

の2フィールドを同じ値で更新する。

表示名をリセットした場合はv1 MyPageと同様に両方を削除し、
Auth側の表示名へfallbackする。

## 3. user document作成

ログイン済みユーザーがv2 MyPageを開いた時、
`users/{uid}`が存在しなければ最小documentを作成する。

```text
createdAt
updatedAt
```

メールアドレスはFirestoreへ重複保存しない。
Firebase Authenticationを正本とする。

既存documentがある場合は読み取りのみで、
作り直さない。

## 4. client write決定

P5-06ではユーザー本人のprivate profileに限り、
Firestore client writeを採用する。

対象:

```text
users/{request.auth.uid}
```

許可field:

```text
appDisplayName
displayName
createdAt   # create時のみ
updatedAt
```

update時の変更可能field:

```text
appDisplayName
displayName
updatedAt
```

他人のdocument、legacy field、document deleteは拒否する。

公開・コミュニティデータwriteは引き続きCallable Functions経由。

## 5. Rules展開方針

P5-06では開発用:

```text
firebase/v2/firestore.rules
```

だけを更新する。

production:

```text
firestore.rules
firebase.json
```

は変更しない。

production Rulesへの統合はP5-08品質ゲートで、
P5-07 `favorite_products`方針と合わせて実施する。

## 6. MyPage

未ログイン:

```text
マイ
→ ゲスト利用中
→ ログイン / 新規登録
```

ログイン後:

```text
表示名
メールアドレス
認証Provider
表示名変更
ログアウト
```

ログアウト後もMyPageを閉じずにゲスト表示へ戻る。

## 7. P5-07接続口

P5-06 MyPageには`よく飲む商品`の次工程を示すだけとし、
実保存はP5-07で行う。

source of truth:

```text
users/{uid}/favorite_products/{productId}
```

旧`favoriteDrinkNames`はP5-07で
Product masterへ一意に対応できる場合だけfallback対象とする。
