# Phase 6 Completion Report

> 対象: 自販機ナビ / VendingNavi v2
> Phase: 6 メーカー簡単登録
> 完了日: 2026-08-12

## 1. 完了範囲

Phase 6では、写真AIを使わない新規自販機登録ルートを成立させた。

実機で成立した導線:

```text
Home「登録」
→ Auth Gate
→ 位置調整
→ 30m重複候補確認
→ 登録方法選択
→ メーカー選択 / 分からない
→ 最終確認
→ createVendingMachine Callable
→ 詳細画面
→ Home地図反映
```

## 2. 実装内容

### 登録draft / Controller

- UUID v4 requestId
- 位置
- 登録方法
- メーカー
- 確認済み商品
- 自販機名
- 場所メモ
- 設置場所
- submit状態
- 完了machineId

戻る・再試行では同じrequestIdを保持し、新しい登録開始時だけresetする。

### 位置調整

- 現在地を初期候補に利用
- 地図中央固定ピン
- 手動位置選択
- 現在地再取得
- 位置取得失敗時も手動選択可能

### 重複候補

OI-005を次で固定した。

- 30m以内
- メーカー不問
- 近い順
- 候補があっても登録を禁止しない
- 既存情報を見る導線
- 別の自販機として続行可能

二重送信防止は距離ではなくrequestId冪等性で行う。

### 登録方法

Phase 6で利用可能:

- メーカーから簡単登録
- メーカー不明 / 位置のみ登録

写真登録はPhase 7まで無効。

### メーカー選択

Firestore Manufacturer masterを利用し、active/selectableなメーカーのみ表示する。

固定のクライアントメーカー一覧は持たない。

「分からない」はlocationOnlyへ進む。

### 最終確認

保存前に次を確認できる。

- 位置
- 自販機名
- メーカー
- 推定商品 / 確認済み商品
- 設置場所
- 場所メモ

メーカーpresetは「あるかも」として表示し、確認済み情報とは区別する。

### createVendingMachine Functions

Callable Functionsへ正式な公開書き込みを集約した。

主なサーバー処理:

- Firebase Authentication
- 入力検証
- accountStatus
- Manufacturer / Product master確認
- server geohash生成
- requestId冪等性
- vending_machines作成
- products作成
- revisions作成
- machine_product_index作成
- request_deduplication保存

クライアントから次を信用しない。

- createdBy / updatedBy
- timestamp
- geohash
- evidenceType
- status / dataLevel
- メーカー推定商品
- revision
- 検索index

### accountStatus互換

Phase 5ユーザーとの互換のため、Callable側で次を扱う。

- user documentなし → activeで初期化
- accountStatusなし → activeをserver側で追加
- active → 投稿可能
- restricted / suspended → 投稿拒否

最終的なprofile / Rules整理はPhase 9で行う。

### geohash

既存Flutter実装と同じbase32 geohashをFunctions側でも使用する。

precisionは6。

fixture:

```text
35.681236, 139.767125
→ xn76ur
```

### machine_product_index

新規Functions書き込みのindex IDを次で固定した。

```text
{machineId}_{productId}
```

検索クエリはdocument IDではなくフィールドを利用する。

### 自動名称

name未入力時:

```text
メーカーあり:
{displayShortName}の自販機

メーカー不明:
自販機
```

場所名等を推測した自動命名は行わない。

## 3. 品質確認

完了確認:

- machine_registration feature tests
- registration route tests
- Functions TypeScript build
- Functions unit tests
- createVendingMachine Emulator integration
- v2 feature strict analyzer
- router strict analyzer
- test strict analyzer
- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `git diff --check`
- Android実機E2E

実機確認:

- Emulator Authログイン
- メーカー簡単登録
- 保存
- 作成後Detail
- Home Map反映
- メーカー不明 / locationOnly登録

## 4. Production保護

Phase 6では次を変更していない。

```text
firebase.json
firestore.rules
firebase/v2/firestore.rules
```

公開データの書き込みはCallable Functions経由とし、既存production Rulesを途中変更していない。

## 5. Phase 6で扱わないもの

次は後続Phaseへ送る。

### Phase 7

- 写真アップロード
- AI画像認識
- 認識候補
- ユーザー確認
- photo_confirmed
- 一時画像から正式画像への反映

### Phase 8

- 自販機更新
- 商品更新
- 修正提案
- 報告
- 重複候補からの「この自販機を更新」

### Phase 9

- App Check最終強制
- accountStatus / profile / Rules最終整理
- rate limit
- security finalization

## 6. Phase 6 Done

Phase 6のDone条件:

> メーカー不明・位置のみを含め、確実な非AI登録ルートが成立していること。

この条件を、Functions Emulator・Android実機の両方で確認した。
