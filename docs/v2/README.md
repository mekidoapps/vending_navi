> 文書状態: Phase 0 正式版（実装前基準）  
> 更新日: 2026-08-05  
> 対象: 自販機ナビ / VendingNavi v2  
> パッケージID: `com.mekidoapps.vendingnavi`  
> リポジトリ: `mekidoapps/vending_navi`


# 自販機ナビ v2 設計ドキュメント

## 1. このディレクトリの目的

このディレクトリは、自販機ナビ v2 の実装時に参照する固定情報源である。現行版を削除せず比較・再利用元として保持しながら、v2を新しい構造で再構築する。

実装中は、過去の会話や旧仕様書ではなく、原則として本ディレクトリの文書を参照する。仕様とコードが食い違う場合、コードが動作していることだけを理由にコードを正とはしない。

## 2. プロダクトの核

> よく飲む、好きな飲み物を近くから探す。

最優先のユーザー行動は、飲みたい商品またはジャンルを指定し、買える可能性の高い近くの自販機を見つけることである。

データ登録・更新は検索体験を支える第二の主要行動とする。チェックイン、経験値、称号、広告、通知などはv2 MVPの中心に置かない。

## 3. 現在の位置づけ

- 現行版はGoogle Playクローズドテスト版として保持する。
- v2は完全な新規アプリではなく、Firebase、認証、Google Maps、配信設定、既存データ等を活用した再構築とする。
- ホーム、検索表示、登録フロー、状態管理、データ更新方式は必要に応じて作り直す。
- 本番データを一括置換せず、旧形式の読み取り互換期間を設ける。

## 4. 文書一覧

| 文書 | 役割 |
|---|---|
| [REQUIREMENTS_V2.md](REQUIREMENTS_V2.md) | コンセプト、MVP範囲、完成条件 |
| [USER_FLOWS_V2.md](USER_FLOWS_V2.md) | 主要な操作フロー |
| [SCREEN_SPEC_V2.md](SCREEN_SPEC_V2.md) | 画面ごとの表示・操作・状態 |
| [DESIGN_SYSTEM_V2.md](DESIGN_SYSTEM_V2.md) | 色、余白、角丸、共通UI |
| [DATA_MODEL_V2.md](DATA_MODEL_V2.md) | Firestoreとドメインデータ |
| [FUNCTIONS_SPEC_V2.md](FUNCTIONS_SPEC_V2.md) | Callable Functionsの契約 |
| [SECURITY_V2.md](SECURITY_V2.md) | 権限、App Check、投稿制限 |
| [ARCHITECTURE_V2.md](ARCHITECTURE_V2.md) | Flutterコード構造と依存方向 |
| [MIGRATION_PLAN_V2.md](MIGRATION_PLAN_V2.md) | 現行資産・旧データからの移行 |
| [TEST_PLAN_V2.md](TEST_PLAN_V2.md) | テスト項目と合格基準 |
| [IMPLEMENTATION_PLAN_V2.md](IMPLEMENTATION_PLAN_V2.md) | 実装フェーズと完了条件 |
| [DECISIONS.md](DECISIONS.md) | 確定判断と理由 |
| [OPEN_ISSUES.md](OPEN_ISSUES.md) | 実装前またはPoC後に決める事項 |
| [CHANGELOG_V2.md](CHANGELOG_V2.md) | 仕様・動作に影響する変更履歴 |
| [REPOSITORY_AUDIT_V1.md](REPOSITORY_AUDIT_V1.md) | 現行リポジトリの再利用・作り直し監査 |
| [PHASE1_BOOTSTRAP_PLAN_V2.md](PHASE1_BOOTSTRAP_PLAN_V2.md) | Phase 1のコミット分割、基盤構成、安全なEmulator導入 |

## 5. 優先順位

内容が食い違った場合は、次の順で判断する。

1. `DECISIONS.md`の最新確定事項
2. `REQUIREMENTS_V2.md`
3. `USER_FLOWS_V2.md`
4. `SCREEN_SPEC_V2.md`
5. `DATA_MODEL_V2.md` / `FUNCTIONS_SPEC_V2.md` / `SECURITY_V2.md`
6. `ARCHITECTURE_V2.md`
7. `IMPLEMENTATION_PLAN_V2.md`
8. 現在のコード
9. 旧仕様書・過去メモ

## 6. 状態ラベル

| 状態 | 意味 |
|---|---|
| 確定 | ユーザー確認済みで実装基準となる |
| 暫定 | PoC、実測、実機確認後に再判断する |
| 実機調整可能 | 意図は確定済みで数値や見た目のみ調整可能 |
| 保留 | 実装前に決定が必要 |
| MVP対象外 | v2 MVPには含めない |
| 将来候補 | 後続版で再検討できる |
| 廃止 | 旧仕様として記録のみ残す |

## 7. 仕様変更ルール

仕様変更は、原則として次の順で行う。

1. 変更提案
2. 影響確認
3. ユーザー承認
4. `DECISIONS.md`と関連仕様書の更新
5. テスト項目の更新
6. コード変更
7. 実機確認

不具合修正は確定仕様への復帰であるため、仕様変更とは分ける。色コード、余白、ボタン径など、確定済み方針内の見た目調整は「実機調整可能」とする。

## 8. 参照した既存資料

- `v2開始時点メモ.txt`
- `vending_navi_spec20260413.docx`
- `vending_navi_spec_v2.docx`
- `vending_navi_spec_v5.docx`
- `4-12時点実装状況.txt`
- `20260415時点ＭＶＰまで.txt`
- `フィードバックに関して.txt`
- `feedback.txt`

旧資料に含まれる通知、経験値、称号、広告、プレミアム、棚スロット、編集期限等は、現在のv2確定事項と区別して扱う。
