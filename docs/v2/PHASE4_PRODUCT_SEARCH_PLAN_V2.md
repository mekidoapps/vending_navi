# Phase 4 商品検索 実装計画

> 文書状態: Phase 4 実装開始
> 更新日: 2026-08-07
> 対象: VendingNavi v2

## 1. Phase 4の目的

自販機ナビv2の主価値である、

```text
飲みたい商品を選ぶ
→ その商品がある自販機を探す
→ 地図で候補を見る
→ 自販機詳細で確認する
```

を成立させる。

検索対象はProduct IDを正とし、
商品名文字列だけで自販機を判定しない。

## 2. 実装順

### P4-01 商品検索Core

- `ProductSearchQuery`
- 検索文字列の軽量normalize
- Product ID完全一致
- 商品名一致
- `searchKeywords`一致
- 前方一致
- 部分一致
- 候補score
- 候補Controller
- 古い非同期結果の破棄

P4-01では画面・地図検索をまだ接続しない。

### P4-02 検索パネルUI ✅

HomeMap右下「探す」から、
左方向へ角丸検索パネルを開く。

パネル:

```text
商品を検索
[検索欄]

候補
- 商品
- 商品
- 商品

よく飲む商品
- Phase 5ユーザー情報接続前は正式データを捏造しない
```

商品選択後はHomeMapに小型選択ラベルを残す。

### P4-03 machine_product_index read ✅

`machine_product_index`のv2 read model / Repositoryを追加する。

目的:

```text
Product ID
→ 対象自販機ID
```

を地図用に高速に絞る。

クライアントからindexへwriteしない。

### P4-04 Product検索結果とHomeMap接続 ✅

選択Product IDと現在地図範囲を組み合わせ、
該当自販機だけを検索結果Markerとして表示する。

検索解除で通常HomeMapへ戻す。

### P4-05 ジャンル検索 ✅

既存固定enum:

- お茶
- 緑茶
- コーヒー
- 水
- 炭酸飲料
- ジュース
- スポーツドリンク
- エナジードリンク
- その他

Genre自体を保存用Product IDへ変換しない。
Genreに属するProduct ID群を検索条件にする。

### P4-06 よく飲む商品

UI位置だけPhase 4で確保する。

ユーザー固有保存・認証はPhase 5で正式接続するため、
Phase 4で架空の個人データや固定お気に入りを作らない。

### P4-07 検索状態の詳細優先表示

検索中は固定カード・詳細で、
検索対象商品を他の商品より先に見せる。

`確認済み`と`あるかも`の差は維持する。

### P4-08 Phase 4品質ゲート

- 商品名
- alias
- Product ID
- Genre
- 0件
- 検索解除
- 地図
- 固定カード
- 詳細
- v1/v2互換
- Emulator
- Android実機

まで回帰する。

## 3. P4-01で決める検索候補ルール

優先順位:

```text
1. Product ID完全一致
2. 商品名完全一致
3. keyword完全一致
4. 商品名前方一致
5. keyword前方一致
6. 商品名部分一致
7. keyword部分一致
```

同scoreなら商品名、Product ID順で固定する。

表記揺れ対応はProduct masterの`searchKeywords`を正とする。

Normalizerでは以下だけ吸収する。

- 前後空白
- 半角／全角空白
- 英字大小文字
- 区切り記号

ふりがな推定、意味検索、AI補完はMVPに入れない。

## 4. OI-003 検索半径

未確定を維持する。

P4-01/P4-02ではProduct候補だけを作るため、
半径値は不要。

P4-03/P4-04の`machine_product_index`実測時に、

- index query数
- Firestore read数
- 0件UX
- 地図操作との整合

を見て決定する。

勝手に50m / 100m / 500m等を固定しない。

## 5. OI-004 情報古さ

未確定を維持する。

P4-07で検索対象商品の優先表示を作る際に、
`updatedAt`やevidenceの実データを見てPolicyを決定する。

P4-01では古さ判定を実装しない。

## 6. MVP外

Phase 4では以下を追加しない。

- 気分検索
- AI意味検索
- 音声検索
- 検索履歴
- レコメンド
- 広告
- Premium
