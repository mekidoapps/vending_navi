# iOS 改善の設定と実機確認

基準: TestFlight build 22 / `1979ac2f3d5bd57c26c11dea32cb747b195b1f92`。
この変更はローカル準備のみです。Apple / Firebase / GitHub の設定変更、push、CI、再配布は行っていません。

## 所有者が設定する項目

1. Apple Developer の App ID `com.mekidoapps.vendingnavi`（Team `HBD765T7G9`）で **Sign in with Apple** を有効化します。既存の関連付けがある場合は、その構成を確認してください。
2. Firebase の Apple プロバイダ用 Services ID を確認・準備し、Firebase Console が指定する Return URL を登録します。このプロジェクトの標準 URL は `https://vendingnavi.firebaseapp.com/__/auth/handler` です。Services ID は未確認のため、本書では新しい ID を確定しません。
3. Firebase Authentication の Apple プロバイダを有効化します。**トークン取消には Services ID と OAuth code flow configuration の設定も必要です。** Team ID、Sign in with Apple 用 Key ID・秘密鍵は所有者が直接登録してください。これは既存の App Store Connect Team API key とは用途が異なります。鍵をアプリ・リポジトリ・会話へ載せる必要はありません。
4. 非公開メール宛てに Firebase の確認メール等を送る場合、Apple Private Email Relay に `noreply@vendingnavi.firebaseapp.com` または実際のカスタム送信ドメインを登録します。Firebase の同一メール設定や既存ユーザーは変更しません。
5. Sign in with Apple capability を含む App Store profile を再生成します。既存の証明書と profile 名 `VendingNavi AppStore` は維持できます。署名用証明書・p12を再生成する必要はありません。次のビルド前に、所有者が `ios-testflight` の `IOS_APPSTORE_PROFILE_BASE64` だけを必要に応じ更新してください。今回の変更に新規 GitHub Secret はありません。
6. iOS コードには `Runner.entitlements` と Debug / Release / Profile の参照を追加済みです。CI ヘルパーは新 profile、IPA 内の profile、署名済みアプリのすべてで `com.apple.developer.applesignin` が厳密に `[Default]` であることを要求します。欠落・空配列・文字列・異なる値・余分な値では停止し、値をログに出しません。既存のエラー秘匿と cleanup を維持しています。Xcode/macOS での署名・実機検証は未実行です。ローカル検証は `python -B -m unittest discover -s tool -p test_ios_testflight_entitlements.py -v` です。

Firebase 公式: [Flutter の Apple 認証・再認証・取消](https://firebase.google.com/docs/auth/flutter/federated-auth)、[Apple 設定・非公開メール・取消要件](https://firebase.google.com/docs/auth/ios/apple)。

## 挙動と退会途中失敗

- Apple ボタンは iOS に表示します。Google / メールの既存アカウントは従来の方法へ案内し、アプリから自動連携・統合は行いません。同じメールや非公開メールでの実際の Firebase 競合挙動は、既存の Console 設定を維持して実機確認します。
- Apple が2回目以降に氏名・メールを返さなくても、Firebase セッションを使います。非公開メールを実メールへ置き換えません。
- 退会フローの開始UIDを確認ダイアログから削除開始まで固定します。Apple が連携済みなら、Google/メールも使えるアカウントでも Apple 再認証を要求します。
- Apple 再認証 → 最終確認 → Apple 取消 → 既存のサーバ削除、の順です。最終確認をキャンセルした場合は取消しません。認可コードは UID に結び付けて短時間メモリだけに保持し、1回の取消試行で消費します。
- 取消失敗ではサーバ削除を呼びません。取消後のサーバ失敗・応答不明では削除完了と表示せず、再ログインと状態確認を案内します。再試行には新しい本人確認が必要です。既存サーバの recent-auth / cleanup-before-Auth-delete は変更していません。

## マップ・カメラ・結果表示・アイコン

- iOS の自販機詳細からの徒歩案内は Appleマップ / Google Maps の選択式です。キャンセルでは外部アプリを開きません。Android は従来の Google Maps、アプリ内地図は従来どおりです。
- カメラ拒否と管理者等による制限を区別します。拒否時は端末設定へ進めます。設定から戻っても自動撮影・送信せず、利用者が再度撮影します。
- 読込失敗・検索0件は従来の区別を維持します。地図の0件で未登録と断定せず、商品をすべて非表示にした場合は未登録と表示しません。商品名取得失敗時のID表示は維持し、通信失敗と再読込の案内を追加しました。
- 正式アイコンは Android 設定が参照する `assets/icons/appicon.png` です。新デザインは作らず、既存 iOS catalog の全サイズを生成しました。Android・元画像・catalog 定義は変更していません。再生成は `dart --disable-dart-dev --packages=.dart_tool/package_config.json tool/generate_ios_app_icons.dart`。確認は `python tool/verify_ios_improvements.py`。

## 次の実機確認（未実行）

署名なし archive からの権限伝播対策として、build ジョブは正規 `Runner.entitlements` の Apple `Default` だけを許可し、主アプリへ秘密不要の ad-hoc seed 署名を付け、署名と権限の一致を検証してから暗号化転送します。profile 全権限コピーや `--deep` 一括付与はせず、sign ジョブの分離 export と最終 IPA 検証は維持します。最終検証の application identifier / Team / get-task-allow / Apple は個別の固定診断になり、具体値は出しません。`python -B -m unittest discover -s tool -p 'test_ios_testflight*.py' -v` は合成テストです。Windows 環境では実 codesign と Xcode 26.3 export の互換性を確認できておらず、成功を保証しません。新規 CI・push・外部設定変更はこの修正準備に含みません。

- 新規 Apple ログイン（メール共有 / 非公開）、キャンセル、再ログイン、認証エラー、連打・戻る操作。
- 既存 Google / メール利用者のログインと投稿・お気に入りが同じ UID のまま復元されること。メール競合時に自動統合されないこと。
- Apple 退会の確認キャンセル、再認証キャンセル、取消失敗、取消後のサーバ失敗・再試行、確認中のUID変更。公開データは既存の削除仕様を維持します。
- Appleマップ / Google Maps の徒歩案内、選択キャンセル、外部起動失敗。
- カメラの初回許可・拒否・設定で再許可・端末制限・撮影キャンセル。iOS / Android 双方で撮影から既存登録フローへ進めること。
- 通信失敗 / 範囲内0件 / 商品未確認 / 非表示商品を混同しないこと。
- ホーム画面と TestFlight の正式アイコン、署名後 Apple entitlement、未ログイン閲覧・お気に入り・既存のメール/Google退会。

新しいビルド番号は App Store Connect の未使用値を所有者が確認してください。build 22 は再使用しません。設定と差分レビューの承認後にだけ、新規CI・再配布を行います。
