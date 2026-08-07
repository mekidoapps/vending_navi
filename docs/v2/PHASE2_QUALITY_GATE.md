# Phase 2 品質ゲート

> 更新日: 2026-08-07  
> 対象: VendingNavi v2 Phase 2

## 完了条件

Phase 2は次をすべて満たした時点で完了とする。

- Product ID／Manufacturer ID規約が固定されている。
- Product／Manufacturer DomainがFirestore SDKへ依存しない。
- Firestore DTO／Mapperが不正文書をFailureへ変換する。
- v1混在データをLegacy Mapperで読み取りできる。
- 未解決旧商品を推測で正式Product IDへ変換しない。
- 固定fixtureが7メーカー・33商品で重複していない。
- Dart fixtureとEmulator seed JSONが同期している。
- Product／Manufacturer Repositoryが読み取り専用である。
- Firestore Rulesで`products`／`manufacturers`だけを公開readできる。
- `products`／`manufacturers`へのクライアントwriteは拒否される。
- まだ公開していない`vending_machines`等はdeny-by-defaultのままである。
- Emulator seedが本番Firestoreへ接続できない安全策を持つ。
- Flutter Analyzer／testが通る。
- Functions build／testが通る。
- Emulator結合ゲートが通る。

## Emulator seed

`functions/fixtures/master_fixture.json`はEmulator確認用のsnapshotであり、
Dart側`ProductMasterFixture`との同期をFlutter testで保証する。

seed処理はAdmin SDKを使うが、`FIRESTORE_EMULATOR_HOST`がlocalhost系でない場合は即時停止する。
本番Firestoreへfixtureを書き込む用途には使用しない。

## Firestore Rules

Phase 2終了時点で公開するのは次の2コレクションだけ。

```text
/products/{productId}
/manufacturers/{manufacturerId}
```

権限:

```text
read  = public
write = denied
```

その他はdeny-by-defaultを維持する。

## 実行

静的・単体確認:

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
dart analyze lib/features/product_master
dart analyze test/features/product_master

cd functions
npm install
npm run build
npm test
cd ..
```

Emulator結合確認:

```bash
bash tool/phase2_emulator_gate.sh
```

`.firebaserc`にdefault projectがない場合:

```bash
bash tool/phase2_emulator_gate.sh <projectId>
```

このゲートは`firebase emulators:exec`で一時Firestore Emulatorを起動し、
fixture投入、公開read、write拒否、未公開collection拒否を確認して終了する。
