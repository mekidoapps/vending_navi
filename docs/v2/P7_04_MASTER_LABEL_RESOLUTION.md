# P7-04 AIラベル → Master ID照合

> 日付: 2026-08-12
> 状態: pure resolver実装

## 目的

Vertex AIが返した文字列を公開データやProduct IDとして信用せず、
既存のFirestore Masterへ安全に照合する。

使用Master:

```text
manufacturers/{manufacturerId}
products/{productId}
```

AI専用Masterは作成しない。

## 入出力境界

```text
machineManufacturerLabels
productLabels
        ↓
Functions内 MasterLabelResolver
        ↓
resolved Manufacturer / Product IDs
unresolved labels
```

自販機本体ブランドの解決と商品IDの解決は独立して実行する。
自販機ブランドと商品のmanufacturerIdが一致する必要はない。

## MVP照合順序

照合対象はactiveなMasterのみ。

各Masterについて次を照合候補にする。

```text
name
searchKeywords[]
```

比較前に安全な表記正規化だけ行う。

- Unicode NFKC
- trim
- lowercase
- ひらがな → カタカナ
- 空白統一
- dash記号統一
- wave記号統一
- `・` `/` `-` 周辺空白統一

次はMVPでは行わない。

- 部分一致
- edit distance / fuzzy match
- Latin ↔ Japanese transliteration
- AIによる再推測
- manufacturerからの商品推測

一意に1 IDへ解決できた場合だけresolvedとする。

0件または複数件の場合はunresolvedとし、
ユーザー確認・手動Product Master選択へ回す。

## 例

```text
Asahi
→ manufacturer searchKeywords "asahi"
→ manufacturerId = asahi
```

```text
POCARI SWEAT
→ product searchKeywords "pocari sweat"
→ productId = otsuka_pocari_sweat
```

```text
ドデカミン ストロング
→ 現Masterに存在しない
→ unresolved
```

```text
デカビタC ストロング
≈ ドデカミン ストロング
```

のような「似た名称」は同一視しない。

## 次段

pure resolverのunit test通過後、

1. Firestoreからactive Manufacturer/Product Masterを読むadapter
2. `recognizeVendingMachinePhoto` Callable
3. Vertex provider adapter
4. normalized response生成
5. recognition session保存

の順に接続する。
