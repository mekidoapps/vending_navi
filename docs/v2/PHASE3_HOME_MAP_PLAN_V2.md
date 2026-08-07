# Phase 3 ホーム地図・通常閲覧 実装計画

> 文書状態: Phase 3 P3-01開始時固定  
> 更新日: 2026-08-07  
> 対象: 自販機ナビ / VendingNavi v2

## 1. Phase 3の目的

未ログインの利用者が、

```text
起動
→ 現在地
→ 周辺自販機
→ ピン
→ 固定吹き出し
→ 詳細
→ 外部経路
```

まで進める通常閲覧を完成させる。

Phase 3では商品検索はまだ実装しない。
商品検索と`machine_product_index`はPhase 4で接続する。

## 2. P3-01 自販機Domain／DTO／Mapper

### 対象

```text
vending_machines/{machineId}
vending_machines/{machineId}/products/{productId}
```

Phase 0 `DATA_MODEL_V2.md`のフィールド名と固定値を変更せず型へ落とす。

### 重要方針

- `schemaVersion=2`の正式データは厳格に検証する。
- 未知enumを既知値へ勝手に補正しない。
- Product document IDと`productId`の不一致を拒否する。
- AI未確認候補用のevidence値を追加しない。
- DomainはFirestore SDK型を持たない。
- 旧データ互換用に一部Domain項目をnullableにできるが、v2 Mapperでは必須項目を必ず検証する。
- 地図・検索半径・古い情報の期間はP3-01で固定しない。

## 3. Phase 3の分割

### P3-01
- VendingMachine Domain
- VendingMachineProduct Domain
- GeoCoordinate
- 固定enum
- Firestore DTO／Mapper

### P3-02 ✅
- VendingMachine Repository
- v2 root + products subcollection読取
- P2 LegacyMappedVendingMachine → VendingMachine bridge
- v1/v2同時読取fixture
- Emulator read Rules
- compatibility snapshotは移行確認専用としHomeMap全件取得に使わない

### P3-03
- 現在地Service
- permission状態
- 位置取得Controller
- 位置取得拒否・失敗時状態
- 既存位置資産の監査再利用

### P3-04
- v2 HomeMapScreen
- 全画面Google Map
- 上部小型アプリラベル
- 右下「探す」「登録」「マイ」
- 現在地へ戻る操作
- まだ検索パネルは開かない

### P3-05
- 周辺自販機取得
- 地図移動と再取得
- 状態ピン
- 選択ピン
- 周辺0件表示

### P3-06
- 選択時カメラ移動
- 固定吹き出し
- 詳細画面
- 戻り時の選択状態維持

### P3-07
- 外部地図経路
- Emulator統合
- 小型／基準／大型画面
- Phase 3品質ゲート
- 実機確認

## 4. 未確定事項を勝手に固定しない

Phase 0 `OPEN_ISSUES.md`の次は継続する。

### OI-003 周辺検索範囲
- 起動時の既定半径
- 地図移動時の再検索条件
- 最大取得件数

### OI-004のうち情報古さ
- 「以前の情報」とする具体的期間

情報古さの期間はPhase 4 PoC決定事項であるため、
P3のピン実装では期間を差し替え可能なPolicyとして扱う。

## 5. P3-01完了条件

- `vending_machines` rootのv2文書をDomainへ変換できる。
- `products` subcollectionをDomainへ変換できる。
- Product IDの整合性を検証できる。
- v2固定enumの未知値をValidationFailureにできる。
- 不正な位置情報をValidationFailureにできる。
- Firestore型がDomainへ漏れない。
- v1画面、Firebase Rules、Functionsを変更しない。
