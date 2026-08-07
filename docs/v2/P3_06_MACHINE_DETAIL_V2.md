# P3-06 固定吹き出し・自販機詳細

> 更新日: 2026-08-07
> 対象: VendingNavi v2 Phase 3

## 1. 目的

P3-05の選択状態をUIへ接続し、

```text
自販機ピン
→ 選択
→ 固定情報カード
→ 詳細を見る
→ 自販機詳細
→ 戻る
→ 選択状態維持
```

を成立させる。

## 2. 固定情報カード

Google Maps標準InfoWindowは使用せず、
地図上にFlutter widgetとして固定表示する。

表示:

- 自販機名
- メーカー
- 確認済み / あるかも
- active商品件数
- 場所説明（存在する場合）
- 詳細を見る

選択解除ボタンも持つ。

地図空白タップによる選択解除はP3-05の挙動を維持する。

## 3. 詳細画面

Route:

```text
/v2/machines/:machineId
```

既存`/v2` routeは変更しない。

詳細表示:

- 自販機名
- メーカー
- 場所
- 緯度経度
- 確認済み / あるかも
- ドリンク一覧
- 売り切れ / 販売中 / 在庫不明
- legacy互換表示（該当時）

P3-06では以下をまだ入れない。

- 経路案内
- 編集
- 報告
- 写真
- 更新履歴

## 4. Product master結合

`VendingMachineProduct`はProduct IDを保持するため、
詳細表示時にProduct masterを読み込んで商品名へ変換する。

Product master取得に失敗した場合でも、
詳細画面そのものを落とさずProduct IDをfallback表示する。

Manufacturer master取得不能時もManufacturer IDをfallback表示する。

自販機本体の取得失敗だけはFailure画面にする。

## 5. 確認済み / あるかも

既存の`V2StatusBadge`を利用する。

```text
manual_confirmed / photo_confirmed
→ 確認済み

manufacturer_inferred
→ あるかも
```

AI未確認候補を新しい公開evidenceとして追加しない。

## 6. 情報古さ

OI-004の「以前の情報」とする具体期間は未決定。

P3-06では`updatedAt`等を使った独自の期限判定を追加しない。
期間がPhase 4で決定してからPolicyとして接続する。

## 7. 戻り時の選択維持

`VendingMachineMapController`はautoDisposeではないため、
詳細画面へ`push`しても選択状態をclearしない。

戻った時に選択中Markerと固定情報カードをそのまま復元する。

P3-06から詳細へ入る際に、
HomeMapのviewportやselectionを明示的に初期化しない。

## 8. P3-07への引き継ぎ

P3-07で次を追加する。

- 外部Google Maps等への経路案内
- 詳細画面からの経路ボタン
- 小型 / 基準 / 大型画面検証
- Phase 3 Emulator統合
- 実機回帰
- Phase 3品質ゲート
