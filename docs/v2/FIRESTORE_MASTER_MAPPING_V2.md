> 文書状態: Phase 2 P2-02 実装基準  
> 更新日: 2026-08-06  
> 対象: `products` / `manufacturers`

# FirestoreマスタDTO・Mapper

## 1. 目的

Firestore固有の値と、アプリ内部のDomain Modelを分離する。

```text
Firestore document
  ↓ DTO
Firestore依存値を受け取る境界
  ↓ Mapper
検証・正規化・ID変換
  ↓ Domain
Firebaseに依存しないProduct / Manufacturer
```

## 2. DTOの責務

- ドキュメントIDと本文を一つのDTOへまとめる。
- Firestore `Timestamp`をUTC `DateTime`へ変換する。
- `toFirestoreData()`ではドキュメントIDを本文に混ぜない。
- 配列未登録時は空配列、`isActive`未登録時は`true`を既定値とする。
- 必須文字列・日時の欠損や型不一致は、その場で不正データとして扱う。

`toFirestoreData()`はfixture・移行ツール・往復テスト用であり、Flutterクライアントから公開マスタへ直接書き込むためのAPIではない。公開書き込みは引き続きFunctions経由とする。

## 3. Mapperの責務

- Product ID／Manufacturer IDをValue Objectへ変換する。
- 表示名、検索キーワード、任意URLの前後空白を除去する。
- 検索キーワード、ジャンル、プリセット商品IDの重複を除去する。
- 日時をUTCへ統一する。
- 未知ジャンル、不正ID、必須値欠損を自動補正しない。
- 不正データを例外のままUIへ流さず、`ValidationFailure`を持つ`AppResult.failure`へ変換する。

## 4. 未知値の扱い

### 未知ジャンル

`other`へ自動変換しない。マスタデータの誤りを隠すため、`product.genreIds`のValidationFailureにする。

### 不正なProduct ID／Manufacturer ID

正規化して保存し直さない。P2-01のID規則に合わない場合はValidationFailureにする。

### 対応不能な旧商品文字列

P2-02では扱わない。P2-03のLegacy Mapperで「未解決の表示用データ」として保持する。

## 5. Firestoreフィールド

### `products/{productId}`

```text
name
manufacturerId
searchKeywords
genreIds
imageUrl
isActive
createdAt
updatedAt
```

### `manufacturers/{manufacturerId}`

```text
name
displayShortName
searchKeywords
presetProductIds
isActive
createdAt
updatedAt
```

ドキュメントIDは本文へ重複保存しない。
