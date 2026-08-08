# Phase 4 品質ゲート

> 更新日: 2026-08-09
> 対象: VendingNavi v2 Phase 4

## 完了条件

Phase 4は次をすべて満たした時点で完了とする。

- HomeMapの「探す」から検索パネルを開ける。
- Product ID完全一致検索ができる。
- 商品名完全一致検索ができる。
- `searchKeywords` alias検索ができる。
- 前方一致・部分一致検索ができる。
- Product候補選択後に選択ラベルが残る。
- Product検索で`machine_product_index`を利用できる。
- Product検索結果だけをMarker表示できる。
- Product検索解除で通常Markerへ戻れる。
- 固定Genre 9種から検索できる。
- Genre検索で対象Product ID群を統合できる。
- 同一machineの重複結果を1Markerへ縮約できる。
- confirmed / inferredを検索対象evidence基準で区別できる。
- v1互換Product IDをProduct / Genre検索結果へ合流できる。
- 解決不能な旧商品文字列を勝手に一致させない。
- 検索0件・loading・Failureを区別できる。
- 地図移動後に現在viewportで再検索できる。
- 「よく飲む商品」の表示領域が存在する。
- Phase 5前は架空の個人データを表示しない。
- Product検索時に固定カードへ検索対象を表示できる。
- Genre検索時に固定カードへ検索対象Genreを表示できる。
- 詳細画面で検索対象商品を先頭へ優先表示できる。
- 詳細画面でGenre一致商品群を先頭へ優先表示できる。
- 検索なしで詳細を直接開いた場合は従来表示になる。
- 320x568 / 390x844 / 600x960で検索パネルがoverflowしない。
- 320x568 / 390x844 / 600x960で検索中詳細がoverflowしない。
- Flutter全体testが通る。
- Phase 4対象のstrict analyzeが通る。
- Functions build/testが通る。
- `machine_product_index` Emulator read/write gateが通る。
- 本番`firebase.json` / `firestore.rules`に未計画差分がない。
- Android実機でProduct / Genreの主要検索フローが成立する。

## 自動ゲート

```bash
bash tool/phase4_quality_gate.sh vendingnavi
```

確認内容:

```text
Flutter analyze
Flutter全体test
Phase 4 strict analyze
検索UI responsive regression
Functions build/test
machine_product_index Emulator integration
production Firebase config guard
```

最後が、

```text
Phase 4 quality gate passed.
```

なら自動ゲート合格。

## Android実機

Firebase Emulator起動中にUSB端末へreverseする。

```bash
adb reverse tcp:8080 tcp:8080
adb reverse tcp:9099 tcp:9099
adb reverse tcp:5001 tcp:5001
adb reverse tcp:9199 tcp:9199
```

起動:

```bash
flutter run \
  --dart-define=APP_ENTRY=v2 \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

### Product検索

```text
探す
→ BOSS ブラック
→ Product選択
→ 対象Markerのみ
→ Marker選択
→ 固定カードに検索対象
→ 詳細
→ 検索対象商品が上部
→ 戻る
→ 検索状態維持
→ ×
→ 通常Marker復帰
```

### Genre検索

```text
探す
→ コーヒー
→ 対象Markerのみ
→ Marker選択
→ 固定カードに「コーヒーの商品」
→ 詳細
→ coffee商品群が上部
→ ×
→ 通常Marker復帰
```

### 検索UI

```text
探す
→ よく飲む商品はまだありません
→ 商品名入力
→ 候補へ切替
→ 入力削除
→ よく飲む商品へ復帰
```

## OI-003 検索半径

Phase 4完了時点でも固定値は設定しない。

現在の検索スコープは:

```text
現在表示中のGoogle Map viewport
```

である。

Phase 4の実装・テストだけでは、

- 50m
- 100m
- 300m
- 500m

などの固定半径を選ぶ根拠が不足している。

固定半径・最大取得件数・範囲拡張UXは、
実データ量とクローズドテストでの利用行動を見て決定する。

したがってP4-08では、
「未決だから仮値を入れる」のではなく
「viewport検索でMVP検索フローを成立させた状態」として閉じる。

## OI-004 情報古さ

Phase 4完了時点でも具体期間は設定しない。

現在表示できる検索evidence:

- 確認済み
- あるかも

`以前の情報`へ切り替える日数は、
実際の更新頻度データがない段階で固定しない。

Phase 8の更新・報告実装と
クローズドテストの更新頻度を材料に決定する。

## Phase 4で増やさないもの

- 固定検索半径の仮値
- stale期間の仮値
- 気分検索
- AI意味検索
- 音声検索
- 検索履歴
- レコメンド
- 架空のよく飲む商品
- Premium
