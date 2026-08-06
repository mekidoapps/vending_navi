# Phase 1 品質ゲート

> 対象: 自販機ナビ / VendingNavi v2  
> 更新日: 2026-08-06

## 目的

Phase 1で追加したBootstrap、Riverpod、go_router、v2テーマ、共通UI、Failure／Result／ログ、Firebase Emulator分離基盤が、既存v1へ影響せず成立していることを確認する。

## 自動確認

Git Bashでリポジトリのルートから実行する。

```bash
bash tool/quality_gate_v2.sh
```

自動確認の内容:

1. Phase 1必須ファイルの存在
2. v2 Firestore／Storage Rulesのdeny-by-default
3. `flutter pub get`
4. `dart run build_runner build`
5. 既存v1を含む全体Analyzer（既存warning/infoは非fatal）
6. Phase 1対象ディレクトリのstrict analyze
7. Flutter全テスト
8. Functionsの`npm ci`／build／test
9. ルートの本番向け`firebase.json`／`firestore.rules`に未コミット変更がないこと

## Analyzerの扱い

現行v1にはPhase 1開始以前からのwarning／infoが残っている。このためPhase 1では次の二段階で判定する。

- 全体: `flutter analyze --no-fatal-infos --no-fatal-warnings`でerrorがないこと
- v2追加範囲: `dart analyze`を個別に実行し、warning/errorを残さないこと

既存v1の警告解消は別目的のコミットで行い、v2基盤追加と混在させない。

## 手動確認

### legacy起動

```bash
flutter run
```

確認項目:

- 現行画面が起動する
- 地図・ログイン状態など既存機能が維持される
- 起動直後にクラッシュしない

### v2起動

```bash
flutter run --dart-define=APP_ENTRY=v2
```

確認項目:

- v2基盤確認画面が表示される
- 第一・第二ボタン、地図操作ボタン、状態ラベルが表示される
- 「現行版を開く」でlegacyへ移動できる
- スクロール、戻る操作でクラッシュしない

### Emulator接続

```bash
firebase emulators:start \
  --config firebase.v2.json \
  --only auth,firestore,functions,storage
```

別ターミナル:

```bash
flutter run \
  --dart-define=APP_ENTRY=v2 \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

確認項目:

- Emulator UIが起動する
- FlutterログにEmulator接続が表示される
- 本番Firebase設定を変更していない
- `firebase deploy`を実行していない

## Phase 1完了判定

- 自動品質ゲートが成功
- legacy／v2をPixel 6aまたは確認端末で起動
- Emulator分離起動を確認
- `git status`がclean
- `develop-v2`へpush
- Phase 1完了タグを作成

推奨タグ:

```bash
git tag -a v2-phase1-foundation -m "VendingNavi v2 Phase 1 foundation complete"
git push origin v2-phase1-foundation
```
