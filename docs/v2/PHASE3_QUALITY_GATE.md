# Phase 3 品質ゲート

> 更新日: 2026-08-07
> 対象: VendingNavi v2 Phase 3

## 完了条件

Phase 3は次をすべて満たした時点で完了とする。

- `/v2`で全面HomeMapが表示される。
- 位置情報許可・拒否・サービスOFF・取得失敗を区別できる。
- 現在地取得成功時に地図へ移動できる。
- viewport基準で自販機を取得できる。
- schemaVersion=2はgeohash queryを利用する。
- v1旧データを互換読取できる。
- 状態別Markerを表示できる。
- Marker選択状態を保持できる。
- 固定情報カードを表示できる。
- 自販機詳細へ遷移できる。
- Product／Manufacturer masterの表示名を結合できる。
- 確認済み／あるかもを区別できる。
- 販売中／売切／在庫不明を区別できる。
- 詳細から戻ってもMap selectionを維持できる。
- 外部地図へ徒歩経路を渡せる。
- 320x568 / 390x844 / 600x960で主要UIがoverflowしない。
- Flutter全体testが通る。
- v2範囲のstrict analyzeが通る。
- Functions build/testが通る。
- Firestore Emulator read/write Rulesゲートが通る。
- 本番`firebase.json`／`firestore.rules`を変更していない。
- Android実機で主要閲覧フローが成立する。

## 自動ゲート

```bash
bash tool/phase3_quality_gate.sh vendingnavi
```

確認内容:

```text
Flutter analyze
Flutter test
v2 strict analyze
Functions build/test
Firestore Emulator integration
production Firebase config guard
```

最後が、

```text
Phase 3 quality gate passed.
```

なら自動ゲート合格。

## Android実機

P3-07の完了には実機確認も含める。

USB接続時:

```bash
adb reverse tcp:8080 tcp:8080
adb reverse tcp:9099 tcp:9099
adb reverse tcp:5001 tcp:5001
adb reverse tcp:9199 tcp:9199
```

Firebase Emulatorを別ターミナルで起動し、fixtureを投入したあと:

```bash
flutter run \
  --dart-define=APP_ENTRY=v2 \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

確認:

```text
起動
→ 現在地
→ 自販機Marker
→ Marker選択
→ 固定カード
→ 詳細
→ 経路を見る
→ 外部地図
→ アプリへ戻る
→ 詳細から戻る
→ Marker選択維持
```

位置情報拒否でもHomeMapが利用できることを確認する。

## 未確定事項

Phase 3完了時点でも以下は勝手に固定しない。

- OI-003 商品検索時の周辺検索半径
- OI-004 「以前の情報」とする具体期間

これらはPhase 4の商品検索PoCで決定する。
