# VendingNavi v2 Phase 10 Scenario Coverage

## Purpose

Phase 10 では新機能追加ではなく、MVP必須シナリオの全体統合、
実機、実写真AI、レスポンシブ、回帰を確認する。

## Coverage policy

- Unit / Controller / Widget / Router / Emulator で保証できるものは自動化する。
- Google Maps、位置権限、カメラ、実Firebase Auth、実AI写真評価は実機で確認する。
- 同じ責務を重複して大量に自動化しない。
- P0 / P1 が発見された場合はPhase 10内で修正・回帰する。

## Main integration tests

- P10-I01: search -> selected machine card -> detail
- P10-I02: guest -> authentication resume -> manufacturer registration -> detail
- P10-I03A: photo -> AI candidates -> confirmation -> registration -> detail
- P10-I03B: AI failure -> manufacturer fallback -> registration -> detail
- P10-I04: detail -> manual product update -> sold out -> submit -> detail

## Mandatory scenarios

| No. | Scenario | Automated coverage | Remaining Phase 10 validation |
| --- | --- | --- | --- |
| 1 | 通常閲覧 | Home / detail tests | Pixel実機 |
| 2 | 固有商品検索 | Search tests + P10-I01 | Pixel実機 |
| 3 | ジャンル検索 | Genre search tests | Pixel実機 |
| 4 | よく飲む商品検索 | Frequent product tests | Pixel実機 |
| 5 | メーカー簡単登録 | P10-I02 + registration/controller/Emulator | Pixel実機 |
| 6 | 写真AI登録 | P10-I03A + photo/Functions/Emulator | 実写真AI評価 |
| 7 | AI失敗→代替登録 | P10-I03B | 実機失敗時UX |
| 8 | 商品手動更新 | P10-I04 + Functions/Emulator | Pixel実機 |
| 9 | 写真一括更新 | Photo update/controller/submit/Emulator | 実写真AI評価 |
| 10 | 売り切れ設定・解除 | P10-I04 + edit session/controller | Pixel実機 |
| 11 | 推定→確認済み | Edit session/plan/Functions | Pixel実機 |
| 12 | 基本情報修正提案 | Screen/controller/Emulator | Pixel実機・位置UI |
| 13 | 報告 | Screen/controller/Emulator | Pixel実機 |
| 14 | ログイン復帰 | Auth gate tests + P10-I02 | 実Firebase Auth |
| 15 | 旧・新データ混在 | Mapper/repository/rules/backfill tests | Pixel実機 |

## Phase 10 remaining gates

### Responsive

Confirm representative flows on:

- small Android layout
- Pixel 6a baseline
- large Android layout
- large font
- OS dark mode while v2 UI remains light

### Pixel 6a

Run the 15 mandatory scenarios using the v2 entry point.

Also check:

- location permission granted / denied
- GPS disabled
- recenter
- indoor / low accuracy behavior
- return from Android settings
- slow or interrupted network where practical

### Real photo AI evaluation

Evaluate both new registration and photo update with representative photos:

- daylight
- shade
- night / low light
- reflection
- blur
- angled shot
- cropped machine
- small product names
- multiple vending machines in frame
- wrapped / decorated vending machine

Record:

- manufacturer candidate quality
- product candidate quality
- false positives
- unresolved labels
- usefulness of manual correction
- failure/fallback UX

### Exit criteria

Phase 10 is complete when:

1. All automated suites pass.
2. All 15 mandatory scenarios have either automated evidence or completed device evidence.
3. Representative responsive/device checks pass.
4. Real-photo AI evaluation is completed.
5. P0 issues are zero.
6. P1 issues are zero or fixed and regressed.
7. Phase 10 completion report is committed.
