# P6-08 登録内容の最終確認

> 状態: 完了
> 日付: 2026-08-12

## 1. 目的

メーカー簡単登録・メーカー不明登録について、保存前にユーザーが登録内容を確認できる画面を用意する。

## 2. 表示内容

確認画面では次を表示する。

- 選択位置
- 自販機名
- メーカー
- 商品情報
- 設置場所
- 場所メモ
- メーカー推定商品と確認済み商品の区別

自販機名が未入力の場合は、Functions側の自動設定を利用するため「登録時に自動設定」と表示する。

## 3. メーカー簡単登録

メーカーを選択した場合は、Manufacturer masterの`presetProductIds`を「あるかも」として表示する。

これは実物確認済み情報ではなく、Functions保存時には`manufacturer_inferred`として扱う。

## 4. メーカー不明

「分からない」を選択した場合は、`locationOnly`として確認する。

- manufacturerIdなし
- confirmedProductIdsなし
- temporaryPhotoUploadIdなし
- 商品情報なし

## 5. 保存接続点

P6-08時点では確認画面の`onSubmit`を接続点として用意した。

P6-09で`createVendingMachine` Functionsを実装し、P6-10でproduction routerから実際のsubmit処理を接続した。

## 6. 戻る操作

「修正に戻る」では現在のdraftを保持したまま前画面へ戻る。

requestIdは再生成しない。

## 7. テスト

確認した内容:

- メーカー簡単登録の表示
- locationOnlyの表示
- submit callback
- 確認route
- draft保持

P6-10で送信中表示・失敗表示を追加した後、ListViewのviewportに合わせてWidgetテストを更新した。
