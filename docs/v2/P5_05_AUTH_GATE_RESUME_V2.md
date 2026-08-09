# P5-05 Auth Gate / 中断フロー復帰

> 更新日: 2026-08-09
> 対象: VendingNavi v2 Phase 5

## 1. 目的

ログイン必須Actionを、

```text
未ログイン
→ 認証要求
→ 認証
→ 元Actionへ復帰
```

できる共通構造にする。

P5-05最初の接続対象はHomeMapの「登録」。

## 2. AuthRequiredActionRunner

Application層で認証有無とAction再開を管理する。

```text
already authenticated
→ action

guest
→ requestAuthentication
  → cancel
    → actionしない
  → success
    → currentSession再確認
      → authenticated
        → action
      → guest
        → actionしない
```

認証画面が成功を返しただけではActionを再開せず、
Repositoryの`currentSession`も再確認する。

## 3. Login Required Sheet

未ログイン時に即Auth画面へ飛ばさず、

```text
この操作はログインが必要です
自販機の登録にはログインが必要です。
地図の閲覧や検索はログインしなくても利用できます。

[ログイン / 新規登録]
[今はしない]
```

を表示する。

v1のUX思想は参照するが、v2 widgetとして新規実装する。

## 4. Auth route

続行した場合:

```text
context.pushNamed(
  AppRoute.v2EmailAuth.name
)
```

でP5-03/P5-04のAuth画面へ遷移する。

メールでもGoogleでも成功時は`true`をpopする。

back/cancelは`false/null`となり、元Actionは再開しない。

## 5. HomeMap登録

HomeMapの登録ボタンを:

```text
onRegisterPressed直接実行
```

から:

```text
AuthRequiredActionRunner
→ 必要ならAuth
→ onRegisterPressed再実行
```

へ変更する。

P5-05では登録画面そのものを新規実装しない。

現在の`onRegisterPressed` callbackは
Phase 6の自販機登録画面接続ポイントとして保持する。

## 6. Google実機acceptance

P5-05でHomeMapからAuth画面へ到達可能になったため、
P5-04で保留したGoogle Android実機確認をここで行う。

確認:

```text
未ログイン
→ 登録
→ Login Required Sheet
→ ログイン / 新規登録
→ Googleで続ける
→ account chooser
→ 選択
→ Auth成功
→ 元の登録Actionへ復帰
```

P5-05時点では登録画面未実装なので、
UI上の最終登録画面遷移はPhase 6。
ただしcallback再開はwidget testで保証する。

cancel:

```text
Google chooserを閉じる
→ Auth画面に残る
→ エラー表示なし
→ 登録Action未実行
```

## 7. 非変更

- users/{uid}
- favorite_products
- Firestore Rules
- Functions
- production firebase.json
- 自販機登録画面本体
- マイページ本体

## 8. 次

P5-06:

```text
users/{uid}
My Page base
guest / authenticated表示
displayName等のbridge
```

へ進む。
