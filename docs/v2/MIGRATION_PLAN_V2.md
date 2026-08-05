> 文書状態: Phase 0 正式版（実装前基準）  
> 更新日: 2026-08-04  
> 対象: 自販機ナビ / VendingNavi v2  
> パッケージID: `com.mekidoapps.vendingnavi`  
> リポジトリ: `mekidoapps/vending_navi`


# 移行計画

## 1. 目的

現行クローズドテスト版、Firebase環境、既存データを維持しながら、v2の新しいコード・スキーマへ段階的に移行する。

## 2. ブランチ方針

候補:

```text
main          # 現行安定版
v2/develop    # v2統合
v2/feature/*  # 機能単位
```

実際の既存ブランチ構成を確認してから名称を確定する。現行安定ブランチへ直接v2を積み上げない。

## 3. そのまま維持する資産

- パッケージID
- GitHubリポジトリ
- Google Playアプリ登録・クローズドテスト枠
- 署名設定
- Firebaseプロジェクト
- Google Maps API設定
- Android基本設定
- 利用規約・プライバシーポリシーの公開先
- Firebase Authのメール・Googleプロバイダ設定

開発・本番Firebaseの分離状況はPhase 0で確認する。

## 4. 改修して再利用する候補

### Firebase初期化

`main.dart`等から、bootstrap、Emulator、App Check、環境設定、ログを分離する。

### 認証

Firebase Auth呼び出し部分を`FirebaseAuthService`、`AuthRepository`へ包み直す。

### Google Maps

再利用候補:

- Map Controller補助
- 現在地移動
- カメラ移動
- 座標変換
- マーカー生成補助
- 外部経路連携

ホーム画面全体は作り直す。

### 位置情報

権限確認、要求、現在地、タイムアウト、設定誘導を`LocationService`へ分離する。

### Storage

画像圧縮・アップロード補助を再利用し、一時領域方式へ変更する。

### 商品検索

既存`AddDrinkScreen`等の商品検索・Product ID選択部分を確認し、共通Widget/Repositoryへ抽出する。

### よく飲む商品

Product IDで保存済みのデータを移行する。文字列保存はマッピング可能なものだけ移行する。

### フィードバック

既存`submitFeedback`、`feedback_items`、rate limit、App Check方針をv2構造へ移植する。

## 5. 作り直す対象

- `main_shell_screen.dart`相当のホーム
- 下カードの`idle/list/detail`切替
- 常設下部ナビ
- 段階式の新規登録フロー
- 情報更新フロー
- 自販機詳細画面
- Firestore直接書き込み処理
- 旧自販機モデルを拡張し続ける構造

旧コードから小さな純粋ロジックだけ抽出する。

## 6. MVPへ移植しない

- 棚・スロットUI (`DrinkSlotWidget`, `DrinkGridPager`等)
- チェックイン
- レベル・経験値・称号
- 通知
- 広告
- プレミアム
- 気分・タグ検索
- Appleログイン
- 編集期限・プレミアム延長

旧ブランチまたはlegacy領域に保持し、v2ビルドへ不要な依存を持ち込まない。

## 7. Firestore移行

### 段階1: 読み取り互換

- 新DTO・Mapperでv1/v2を読めるようにする。
- v2サブコレクションがなければ旧`drinks`/`slots`を読む。
- 対応不能商品があっても自販機を表示する。

### 段階2: v2書き込み開始

- 新規登録・更新はFunctionsからv2形式へ保存。
- 旧フィールドへの書き込みは互換性上必要な場合だけ検討する。

### 段階3: 移行スクリプト

- 旧商品名をProduct IDへ対応付け。
- 変換できるものだけサブコレクションへ追加。
- `source: migration`のrevisionを残す。
- 実行前後の件数・エラーを記録。

### 段階4: 旧書き込み停止

十分なテスト後、旧クライアントの影響を確認して停止する。

### 段階5: 旧フィールド整理

v2安定後の別判断とし、MVP中に物理削除しない。

## 8. 商品マッピング

- Product ID完全一致
- 正規化された旧名称
- メーカー＋商品名
- 手動対応表

の順で変換候補を作る。自動で確信できない商品は未解決として記録し、誤ったProduct IDへ強制変換しない。

## 9. 写真移行

既存画像URL・Storageパスがある場合:

- 所有・公開状態を確認
- v2 photoドキュメントへ参照を作る
- 元ファイルを即時移動しない
- 主写真候補を1件設定
- 権利・不適切写真の運営確認導線を持つ

## 10. バックアップ・ロールバック

### 着手前

- Firestore Exportまたは復元可能なバックアップ
- Storage対象一覧
- Rules / Functions / Firebase設定の保存
- 現行リリースタグ

### ロールバック

- 現行アプリを再配信できる
- v2クライアントを停止しても旧データを読める
- 移行スクリプトはdry-runと実行ログを持つ
- 破壊的削除を行わない

## 11. コード監査表

実装開始時にFlutter、Functions、Rules、Storageを次の形式で確認する。

| ファイル・機能 | 現在の役割 | 依存先 | v2との差 | 判定 | 対応 |
|---|---|---|---|---|---|
| main shell | 地図・検索・詳細 | Maps/Firestore | 大 | 作り直し | 地図補助のみ抽出 |
| StorageService | 画像保存 | Storage | 中 | 改修再利用 | 一時領域へ変更 |
| Favorite service | お気に入り | Firestore | 中 | 改修再利用 | Product ID化 |
| Name normalizer | 文字列補正 | 商品名 | 大 | 移行用 | 本検索では使わない |
| Slot UI | 棚表示 | 登録画面 | 大 | MVP保留 | legacy維持 |
| Feedback | 投稿受付 | Functions | 小 | 再利用 | 新構造へ移動 |

## 12. 移行完了条件

- 旧・新自販機が同じ画面に表示される。
- v2登録が旧データを破損しない。
- Product IDへ変換できない旧商品が追跡できる。
- 現行版へ戻せる。
- 公開データの直接書き込みを停止しても主要フローが成立する。
