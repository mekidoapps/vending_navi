# P3-03 現在地取得・権限状態

> 更新日: 2026-08-07
> 対象: VendingNavi v2 Phase 3

## 1. 目的

v2 HomeMapがGeolocator SDKを直接呼ばず、Riverpod Controllerから
現在地状態を購読できる境界を作る。

```text
HomeMap
  ↓
CurrentLocationController
  ↓
LocationService
  ↓
GeolocatorLocationService
  ↓
geolocator
```

## 2. 状態

Controllerは次を区別する。

```text
idle
loading
ready
serviceDisabled
permissionDenied
permissionDeniedForever
permissionUnableToDetermine
failed
```

位置情報サービスOFFと権限拒否を同じnullで潰さない。

## 3. permission

アプリ内部ではGeolocator enumを直接使わず、
`AppLocationPermission`へ変換する。

```text
denied
deniedForever
whileInUse
always
unableToDetermine
```

`denied`の場合だけ、通常の`locate()`では1回permission requestする。

`deniedForever`ではrequestを繰り返さず、アプリ設定画面へ案内できる状態にする。

## 4. 位置情報サービスOFF

位置サービスそのものがOFFの場合はpermission requestを行わない。

`openRelevantSettings()`ではOSの位置情報設定画面を開く。

## 5. 現在地取得

P3-03では1回取得のみ。

```text
accuracy = high
timeout = 12秒
```

連続監視は行わない。

HomeMapで現在地へ戻る操作をした場合も、必要に応じてControllerの
`locate()`を再実行する。

## 6. 既存v1との関係

現行v1の`DistanceUtil.getCurrentPositionSafe()`と
`ensureLocationPermission()`は変更しない。

v2ではLocation featureを利用し、GeolocatorをUIから直接呼ばない。

既存v1のdeprecatedな`desiredAccuracy`呼び出しもP3-03では修正しない。
v1互換コードの整理は別工程とする。

## 7. プライバシー

現在地はUI制御・周辺検索用のランタイム状態として扱う。

P3-03では、

- Firestoreへ保存しない
- ログへ緯度経度を出さない
- Analyticsへ送らない

位置情報の永続化は追加しない。

## 8. P3-04への引き継ぎ

P3-04 HomeMapは、

```text
CurrentLocationState.ready
```

を受け取ってMap初期中心へ利用する。

権限拒否・サービスOFF・取得失敗時は地図自体を壊さず、
案内UIを重ねる。

P3-04ではまだ周辺自販機queryを接続しない。
