# P6-10 Flutter登録導線接続

> 状態: 実装中
> 日付: 2026-08-12

## 1. 監査結果

P6-10開始時点では次の状態だった。

- Homeの登録ボタンには既存Auth Gateがある。
- Auth Gate後に実行する`onRegisterPressed`はproduction routerから未接続だった。
- Position / Method / Manufacturer / Confirmationの各画面にはcallback seamがある。
- Duplicate Candidates画面は実装済みだがnamed routeが未登録だった。
- `MachineRegistrationController.submit()`はP6-09 Callable repositoryまで接続済み。
- Home Mapは`VendingMachineMapController.loadViewport(..., force: true)`で再読込可能。
- Product / Genre検索も`force: true`で再検索可能。

## 2. Production登録フロー

```text
Home 登録
↓
既存 AuthRequiredActionRunner
↓
MachineRegistrationController.reset()
↓
/v2/register/position
↓
/v2/register/duplicates
↓
/v2/register/method
↓
/v2/register/manufacturer
↓
/v2/register/confirm
↓
MachineRegistrationController.submit()
↓
createVendingMachine Callable
↓
Map / active search再読込
↓
登録stackを除去
↓
作成した自販機詳細
```

未ログイン時は既存のLogin Required Sheet → Email/Google Authの動線をそのまま使う。
Home画面に新しい認証ロジックは追加しない。

## 3. requestId lifecycle

Homeから新しい登録を開始する時だけ`MachineRegistrationController.reset()`する。

戻る・画面間移動・送信失敗・再試行では同じrequestIdを保持する。

成功後は作成済みmachineIdを取得してからcontrollerをresetする。

## 4. Duplicate route

追加:

```text
/v2/register/duplicates
```

候補0件:
自動でMethodへ進む。

候補あり:
- 既存情報を見る → Machine Detail
- 別の自販機として登録を続ける → Method

「この自販機を更新」はPhase 8接続点のため、P6-10ではupdate callbackを接続しない。

## 5. 保存UI

Confirmationはproduction routerから`onSubmit`を受け取る。

送信中:
- 保存ボタン無効
- 「登録中…」
- 戻るボタン無効

失敗:
- ControllerのAppFailureを確認画面内へ表示
- draft / requestIdは維持
- 同じボタンから再試行可能

成功:
- createdMachineIdを取得
- Map / 現在選択中の商品またはジャンル検索をforce refresh
- 登録画面stackを除去
- 作成したMachine Detailを開く

## 6. Map / Search reflection

P6-09でmachineと`machine_product_index`を同一transactionで作成するため、
Callable成功後は既存query経路を再実行するだけでよい。

```text
vendingMachineMapControllerProvider
  .loadViewport(lastViewport, force: true)

selectedProductあり
→ productMachineSearchControllerProvider.search(force: true)

selectedGenreあり
→ genreMachineSearchControllerProvider.search(force: true)
```

新しい検索経路は追加しない。

## 7. Production保護

変更しない:

```text
firebase.json
firestore.rules
firebase/v2/firestore.rules
```

P6-10はFlutter composition / navigation / submit UIのみ。
