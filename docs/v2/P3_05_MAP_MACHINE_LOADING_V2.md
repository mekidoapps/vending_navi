# P3-05 周辺自販機取得・状態ピン・選択状態

> 更新日: 2026-08-07
> 対象: VendingNavi v2 Phase 3

## 1. 目的

HomeMapに実データの自販機を表示し、

```text
地図表示
→ visible region取得
→ 自販機読込
→ 状態ピン表示
→ ピンタップ
→ 選択状態
→ カメラ移動
```

まで成立させる。

P3-05では固定吹き出し・詳細画面はまだ実装しない。
P3-06で接続する。

## 2. 「周辺」の定義

OI-003の固定検索半径は未決定のため、P3-05では

```text
現在Google Mapに見えている範囲
```

を読込範囲とする。

50m / 100m / 300m等の半径値は追加しない。

商品検索時の検索半径とは別概念。

## 3. v2データの位置検索

schemaVersion=2はrootに`geohash`を持つ。

HomeMap viewportから複数のgeohash prefixを作り、
Firestoreでprefix range queryを行う。

```text
geohash >= prefix
geohash <= prefix + \uf8ff
```

取得後に緯度経度でもviewport内か再確認する。

追加パッケージは導入せず、
P3-05では小さいpure Dart geohash encoder/query plannerを持つ。

## 4. legacyデータ

現行v1文書は`geohash`を持たない。

v1/v2共存期間だけ、

```text
legacy root取得
→ lat/lng抽出
→ viewport内だけVendingMachineRepositoryで互換変換
```

を行う。

これは永続設計ではない。

本番データをv2位置indexへ移行できた時点で
`fetchLegacyDocuments()`の全件互換読取は削除対象とする。

v2文書はgeohash queryを使うため、
新規v2データが増えても全件取得へ戻さない。

## 5. 状態ピン

P3-05ではデザイン確定前の機能ピンとして、
データ状態を優先して4種類に分ける。

```text
selected          選択中
confirmedProducts 確認済み商品あり
inferredProducts  メーカー推定商品のみ
locationOnly      位置情報のみ
```

P3-06以降で固定吹き出しと合わせて
最終的なピン形状・色・アイコンを調整できる。

## 6. 選択

ピンタップ:

- `selectedMachineId`を保存
- 選択ピンを強調
- 自販機位置へカメラを移動
- zoom値は勝手に変更しない

地図の空白タップ:

- 選択解除

地図移動後:

- 選択自販機が新しいviewport外なら選択解除
- viewport内なら選択維持

## 7. 0件・エラー

### 0件

```text
この範囲には登録された自販機がありません
```

地図は操作可能なまま。

### 読込失敗

```text
自販機情報を読み込めませんでした
再試行
```

既存ピンがある場合は消さずに保持する。

## 8. P3-06への引き継ぎ

P3-06では選択中自販機を利用して、

- 選択位置へのカメラ調整
- 固定吹き出し
- 自販機名
- メーカー
- 確認済み／あるかも表示
- 詳細画面
- 戻り時の選択維持

を実装する。
