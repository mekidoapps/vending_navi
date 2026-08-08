# P4-04 Product検索結果とHomeMap接続

> 更新日: 2026-08-07
> 対象: VendingNavi v2 Phase 4

## 1. 目的

P4-02の商品選択とP4-03の`machine_product_index`を
HomeMapへ接続する。

完成フロー:

```text
探す
→ 商品候補
→ Product選択
→ 現在のMap viewport
→ machine_product_index
→ 該当machineId
→ HomeMap Markerを絞る
```

検索解除で通常の全自販機表示へ戻す。

## 2. 検索範囲

P4-04でも固定半径は決めない。

検索条件:

```text
selected Product ID
+ Google Map visible region
```

地図を移動して`onCameraIdle`になるたびに、
通常自販機viewport取得の後でProduct indexを再検索する。

OI-003は未確定のまま維持する。

## 3. ProductMachineSearchController

保持:

- Product ID
- viewport
- index entries
- loading
- failure
- searched

同一Product ID・同一viewportを連続で要求した場合は
不要な再検索を省略する。

再試行時はforceする。

検索中に別Productへ切り替わった場合、
古い非同期結果で最新状態を上書きしない。

## 4. Marker filter

### schemaVersion=2

P4-03 indexに含まれる`machineId`だけ表示する。

正本の商品subcollection全件検索へ戻さない。

### legacy

旧v1文書は派生indexを持たないため、
P3で互換変換済みの`VendingMachine.products`を利用する。

```text
legacy machine
+ activeProducts
+ selected Product ID一致
→ 検索結果へ合流
```

文字列を再比較しない。

P2/P3でProduct IDへ解決できた旧商品だけを対象とする。
曖昧な旧文字列をP4-04で推測しない。

## 5. 状態別Marker

通常表示ではP3のMarker状態を維持する。

商品検索中は、
「その検索対象商品のevidence」をMarker状態へ使う。

```text
検索対象商品 confirmed
→ confirmed marker

検索対象商品 inferred
→ inferred marker
```

別商品のconfirmed状態でMarker色を強くしない。

選択中Markerは最優先。

## 6. 0件

検索結果が0件なら地図を消さず、

```text
この範囲では「BOSS ブラック」が見つかりませんでした
```

を表示する。

地図を動かせば新しいviewportで自動再検索する。

P4-04では勝手に検索半径を広げない。

## 7. Failure

通常の自販機viewport読込に失敗した場合は、
商品indexの0件と誤認させず、

```text
自販機情報を読み込めませんでした
再試行
```

を優先表示する。

index読込だけ失敗した場合:

```text
商品検索結果を読み込めませんでした
再試行
```

検索条件は保持する。

再試行では通常自販機viewportを再確認した後、
同じProduct ID・viewportでindexもforce再検索する。

## 8. 検索解除

選択商品ラベルの×:

```text
Product selection clear
Product machine search state clear
→ 通常HomeMap Markerへ即時復帰
```

通常Mapデータを再取得し直す必要はない。

## 9. 売り切れ

P4-03と同様、
`soldOut`だから検索結果から削除する処理はまだ入れない。

OI-004の鮮度Policyと合わせて後続で決定する。

## 10. P4-05へ

次はGenre検索を追加する。

Product検索と同じ地図体験を維持しつつ、

```text
コーヒー
→ Genreに属するProduct ID群
→ index検索
→ machineId集合
```

へ拡張する。
