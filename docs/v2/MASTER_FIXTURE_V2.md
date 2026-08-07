# Product／Manufacturer 固定fixture

> 文書状態: Phase 2 P2-04 固定版  
> 更新日: 2026-08-07  
> 対象: 自販機ナビ / VendingNavi v2

## 1. 目的

Phase 2以降で検索・登録・旧データ互換・Emulator seedが同じProduct ID／Manufacturer IDを参照できるように、初期マスタをコードfixtureとして固定する。

fixtureは本番商品カタログの完全版ではない。現行v1で使っているメーカー別プリセットを移行起点とし、MVPで扱う代表商品を安定IDへ変換した初期集合である。

## 2. 初期メーカー

固定するManufacturer ID:

```text
coca_cola
suntory
ito_en
kirin
asahi
dydo
otsuka
```

現行v1のプリセットに存在するメーカーを基準とする。

`その他`は正式メーカーではないためfixtureへ追加しない。自販機のメーカー不明は従来どおり`null`で扱う。

`AQUO`は現行v1に文字列として存在するが、P2-04時点では正式な飲料メーカーとしてProduct masterへ確定しない。旧データでは未解決として保持し、実データ確認後に必要なら正式マスタまたは別属性へ整理する。

## 3. 初期商品

現行v1のメーカー別プリセットから、商品として一意に扱いやすいものを初期fixtureへ採用する。

一方、次のようなブランド全体を指し得る曖昧名称は正式Productへ自動確定しない。

```text
ジョージア
ファンタ
BOSS
```

例:

```text
BOSS ブラック      -> suntory_boss_black
ジョージア ブラック -> coca_cola_georgia_black
ファンタ グレープ   -> coca_cola_fanta_grape
```

この方針は「誤ったProduct IDへ確定するより未解決を優先する」というP2-03の互換方針を維持する。

## 4. Repository

Domain層には次のinterfaceを置く。

```text
ProductRepository
ManufacturerRepository
```

Data層ではFirestoreを直接Domainへ露出せず、

```text
Firestore
 -> MasterDocumentSource
 -> DTO / Mapper
 -> Repository
 -> Domain
```

の順に変換する。

公開マスタは閲覧用途なので、Repositoryは読み取りのみ提供する。書き込みAPIは追加しない。

## 5. 一覧取得のエラー方針

正式マスタは検索の基盤であるため、一覧内に不正な1件が存在した場合、その1件を黙って除外せずRepository全体をFailureにする。

これにより、壊れたマスタを「商品が存在しない」と誤認して検索結果へ反映しない。

旧`vending_machines`内の商品はこれと異なり、P2-03のLegacy Mapperで未解決商品を保持して自販機全体の読み込みを継続する。

## 6. 手動alias

手動対応表は`LegacyMasterAliases`に固定する。

利用対象:

- 記号差
- 旧メーカー表記
- 明確な一般略称
- メーカーが分かっている場合のみ安全に確定できる旧名称

利用しないもの:

- 類似度による推測
- 部分一致だけの確定
- ブランド名だけから特定バリエーションへの変換

`BOSS`単独のように複数商品を指し得るものは未解決のまま残す。

## 7. P2-05への引き継ぎ

P2-05では本fixtureをEmulatorへseedし、次を結合確認する。

- `manufacturers`
- `products`
- Repository一覧取得
- ID指定取得
- activeOnly
- 旧名称alias
- 対応不能旧商品
- deny-by-defaultから公開read用Rulesへの最小変更
