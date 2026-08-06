# 商品・メーカーマスタ規約

> 文書状態: Phase 2 P2-01 固定版  
> 更新日: 2026-08-06  
> 対象: 自販機ナビ / VendingNavi v2

## 1. 目的

`products`と`manufacturers`を、旧商品文字列・画面表示・FirestoreドキュメントIDから分離し、検索・登録・移行で共通利用できる安定したDomain Modelとして定義する。

## 2. ID共通規則

Product IDとManufacturer IDは次を満たす。

- 小文字ASCIIの`snake_case`
- 先頭は英小文字
- 使用可能文字は`a-z`、`0-9`、`_`
- 2文字以上80文字以下
- 空白、ハイフン、連続underscore、末尾underscoreを使わない
- 公開後は表示名が変わってもIDを変更しない
- FirestoreドキュメントIDとDomain IDを同一にする

不正な値を自動補正して保存しない。DTO／移行処理で`tryParse`し、対応不能値として追跡する。

## 3. Manufacturer ID

メーカーの安定した短い識別子を使う。

例:

```text
coca_cola
suntory
ito_en
kirin
asahi
```

自販機のメーカー不明は`manufacturerId: null`で表す。`unknown`や`other`という架空メーカーをマスタへ追加しない。実在する小規模メーカーの商品を登録する場合は、そのメーカーを正式なマスタとして追加する。

## 4. Product ID

原則として次の形式を使う。

```text
{manufacturerId}_{productSlug}
```

例:

```text
coca_cola_ayataka
suntory_boss_black
ito_en_oi_ocha_green_tea
```

Product IDはSKUではなく、利用者が検索時に同一商品として認識する単位とする。

- 容量違いだけではIDを分けない
- ペットボトル／缶の違いだけではIDを分けない
- HOT／COLDだけではIDを分けない
- 無糖、ゼロ、味違いなど、商品名・選択理由が異なるものは分ける
- メーカー移管や表示名変更があっても既存IDを変更しない

## 5. 固定ジャンル

MVPでは次をコード固定する。

```text
tea
green_tea
coffee
water
carbonated
juice
sports_drink
energy_drink
other
```

実際のIDは先頭空白なしの`green_tea`である。複数ジャンルを許容するが、マスタ作成時に最低1件を設定する。未知ジャンルはMapperで無視または`other`へ明示変換し、enum生成時に例外でアプリを停止させない。

## 6. 商品マスタの運用

- 終売・一時停止商品は削除せず`isActive: false`
- 過去の自販機情報は無効商品を参照できる
- 通常の検索・新規選択では`isActive: true`だけを表示する
- `searchKeywords`には、ひらがな、英字、記号なし表記、一般的な略称を保存する
- キーワードの自動正規化はRepository／検索処理で行い、正式表示名を変更しない
- 初期商品件数と実データはP2-04で固定する

## 7. DomainとDTOの境界

Domain ModelはFirebase SDK型を持たない。

- Firestore `Timestamp` → DTO／Mapperで`DateTime`
- ドキュメントID → DTO／Mapperで`ProductId`または`ManufacturerId`
- 未知ID・欠損値 → Mapperが失敗結果または未解決参照として扱う
- 旧商品文字列 → Legacy Mapperが対応表を使ってDomainへ変換する

P2-01ではDomainとID規約だけを追加し、Firestore読み取り・旧データ変換・seed投入は行わない。
