# P3-04 v2 HomeMapScreen

> 更新日: 2026-08-07
> 対象: VendingNavi v2 Phase 3

## 1. 目的

`APP_ENTRY=v2`で基盤確認画面ではなく、
実際のv2ホーム地図へ入る状態に切り替える。

P3-04では地図UIの骨格だけを完成させる。

## 2. 画面構成

```text
全面 Google Map
├ 上部左: 小型「自販機ナビ」ラベル
├ 上部右: 現在地へ戻る
├ 上部: 位置情報状態カード（必要時のみ）
└ 右下:
   ├ マイ
   ├ 登録
   └ 探す（最大・最下部）
```

「探す」は右下の主操作とし、
P4で左方向へ検索パネルを展開する前提を維持する。

## 3. 地図

初期位置を取得できる前も地図自体は表示する。

技術上のfallbackとして日本全体が見えるカメラから開始し、
現在地取得成功後に現在地へ移動する。

このfallbackは周辺検索位置や検索半径を意味しない。

P3-04では:

- 自販機Markerなし
- 周辺自販機queryなし
- 検索範囲なし
- clusteringなし

P3-05で接続する。

## 4. 現在地状態

P3-03 Controllerを利用する。

位置情報が利用できない場合でもGoogle Mapを消さない。

状態カード:

```text
loading
serviceDisabled
permissionDenied
permissionDeniedForever
permissionUnableToDetermine
failed
```

`ready`ではカードを消す。

### serviceDisabled
OS位置情報設定を開く。

### permissionDeniedForever
アプリ設定を開く。

### retry可能状態
Controllerの`retry()`を実行する。

## 5. 現在地ボタン

上部右の現在地ボタンはControllerの`locate()`を再実行する。

取得成功時のController状態変化を監視し、
GoogleMapのカメラを現在地へ移動する。

GoogleMap標準のmyLocationButtonは使わず、
v2デザインの操作を使用する。

## 6. 右下アクション

P3-04では配置・サイズ・押下可能な骨格だけを固定する。

```text
探す: 主操作 / 64
登録: 副操作 / 50
マイ: 副操作 / 50
```

実機上で「探す」を右下最下部に置く。

P3-04では以下はまだ接続しない。

- 探す → 検索パネル
- 登録 → 登録フロー
- マイ → マイページ

それぞれのPhaseでcallbackを接続する。

## 7. ルーティング

既存の`/v2`パスをそのまま利用する。

Phase 1のrouter test互換性を壊さないため、
内部enum名`v2Foundation`のrenameはP3-04では行わない。

productionのdefault builderだけを:

```text
V2FoundationScreen
  ↓
V2HomeMapScreen
```

へ変更する。

Foundation画面ファイル自体はPhase 1基盤記録として残す。

## 8. テスト

Google Map PlatformViewをwidget testへ直接出さないよう、
`mapBuilder`をテスト用seamとして持つ。

確認:

- 全面地図領域
- アプリラベル
- 現在地ボタン
- 探す／登録／マイ
- 探すが他より大きい
- serviceDisabledでも地図を維持
- 設定画面導線
- 現在地成功時に状態カードを消す
- text scale 2.0
