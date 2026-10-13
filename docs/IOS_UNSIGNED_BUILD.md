# iOS unsigned compile preparation

This is a compile check, not an installable iPhone build or distribution pipeline.
No Apple account, signing certificate, provisioning profile or GitHub Secret is
required. The workflow never launches the app, deploys Firebase, builds Android,
uploads an app artifact, or publishes to TestFlight/App Store.

## Source decision (2026-10-14 investigation)

- Remote: `https://github.com/mekidoapps/vending_navi`, default `main`.
- `main`: `f9a29334301e82043722dfaca219849f01c7545e`, version `1.0.0+11`.
- `develop-v2`: `3f40869355a82c5a1a6d617bd9a15b0db327fa1f`.
  Version `1.0.0+21`, 160 commits ahead
  of `main`, with no main-only commits. Preparation branch:
  `prep/ios-unsigned-build`, based on this remote branch.
- RC21 Android immutable AAB source:
  `0904f42309082877bd8137adeb6903dfd6b2ef15`; `APP_ENTRY=v2`; Flutter 3.41.2.
  The branch tip includes later OSM tooling/rules and documentation. Application
  Dart/iOS files have no changes between that source and the inspected tip.
- GitHub Releases API returned `[]`; phase tags are not a current production
  release. `docs/releases/v1.0.0+21_RC.md` still records Alpha active and
  Production authorization pending. Reconcile this with the user's later
  Production 1.0.0(21) information before choosing a release source. Do not
  treat this inspection as evidence of the current Play Console state.
- No preexisting checkout was found in this task workspace/Documents/Codex;
  the old `C:/Users/domek/vending_app` is absent. A separate clone was used.
  No `.agents/skills` or existing `.github` workflows are tracked at this tip.
  Root `AGENTS.md` was read; known memory_summary.md locations were absent.

## Compile configuration

- Manual `workflow_dispatch` only; read-only repository permission; no stored
  checkout credentials; action dependencies pinned to reviewed tag SHAs.
- `macos-15`, explicitly Xcode 26.3, iPhone SDK major >=26; fail if removed
  from the runner image. Flutter 3.41.2 is pinned to the Android release evidence.
- Exact selected-branch SHA must match the `expected_sha` input. Version guard
  rejects old main. Flutter pub resolution must preserve `pubspec.lock`.
- `flutter build ios --release --no-codesign --dart-define=APP_ENTRY=v2`.
- Added CocoaPods Podfile and Pods xcconfig includes. Runner deployment minimum
  raised from 13 to 14 because locked `google_maps_flutter_ios` 2.18.1 requires
  iOS 14. CocoaPods selects compatible native Maps versions for this minimum.
  No Dart package upgrades. Minimum may need reconsideration after native
  resolution, not a silent upgrade in CI.
- No Podfile.lock exists yet: first native resolution is not fully reproducible.
  After an approved successful macOS run, obtain/review its Podfile.lock on a
  Mac and commit it before using this for release validation.
- Only safe source/toolchain evidence and Podfile.lock checksum go into the
  run summary. Do not upload binaries, plist configs or verbose environment logs.

## Before an approved first run

1. Confirm `develop-v2` is the intended source and reconcile any newer unpushed
   work on the other PC. Review the complete diff; this preparation adds no
   credentials or new client keys and is suitable for public review.
2. Separately authorize pushing the preparation branch. To enable manual runs,
   separately review/merge **only the workflow file** into default `main` (or
   agree a default-branch strategy). Do not merge all develop-v2 merely to
   register the workflow, and do not compile old main.
3. Check the current macos-15 image still has Xcode_26.3 and SDK >=26, repository
   Actions are enabled, and pinned actions are allowed by repository policy.
   Standard hosted runners for public repos are free; do not select larger or
   paid runners. No billing or permission changes are part of these steps.
4. After separate execution approval, select `prep/ios-unsigned-build` in Actions
   > iOS unsigned compile > Run workflow. Enter its final complete commit SHA
   (after committing preparation), not the base SHA, as `expected_sha`.
5. Review compile result and source/toolchain summary. Failure may expose a
   native dependency/toolchain incompatibility: inspect before changing locks.
   A success proves compile only; no runtime integration or signing is tested.

## Runtime and later distribution gaps

- Firebase Dart iOS options and bundle ID `com.mekidoapps.vendingnavi` exist;
  ignored `ios/Runner/GoogleService-Info.plist` is absent. Do not regenerate or
  change cloud registrations. Verify the existing iOS registration and obtain
  the matching config through an authorized separate setup.
- AppDelegate lacks Google Maps SDK API-key initialization. Google Sign-In
  lacks the iOS client/URL-scheme configuration. Confirm matching OAuth client
  and restricted iOS Maps key without reusing/modifying Android keys.
- Info.plist has location-when-in-use text but no camera/photo-library usage
  descriptions. Photo workflows, login, Maps, location and notification paths
  require separate iOS setup and real-device smoke testing.
- Release bootstrap uses Apple DeviceCheck App Check. Verify iOS App Check
  registration/provider and required Apple credentials later; do not weaken
  enforcement or activate debug provider for release.
- Confirm Apple Developer Program membership, bundle ID ownership, signing
  team/profiles, privacy manifests/disclosures, icons/display name, and review
  requirements before preparing TestFlight/App Store distribution. A signed
  build is required for normal iPhone installation; unsigned Runner.app is
  not a user-installable deliverable.

## Verification boundary and official references

Windows has no Flutter/Xcode/CocoaPods toolchain on PATH. Local checks cover
Git diff whitespace, workflow static validation, plist XML and Bash syntax.
Completed checks: `actionlint 1.7.12 -shellcheck=` (PASS, no ShellCheck installed),
`bash -n` on extracted multiline workflow commands (PASS), `git diff --check`
(PASS), PowerShell XML parsing of both existing plists (PASS), all three Runner
deployment targets equal 14.0 (PASS), and `git diff --quiet` of RC21 source versus
develop-v2 for `lib ios pubspec.yaml pubspec.lock` (PASS).
Pod resolution, Ruby execution, Flutter analyze/tests and iOS compilation have
not been run. No push, Actions run, Secrets, certificates, Apple registration,
cloud writes, permission changes or payment occurred.

- [Apple upload requirements](https://developer.apple.com/news/upcoming-requirements/):
  Xcode 26+/iOS 26+ SDK since April 28, 2026; target iOS 13+ since September 9,
  2026. The preparation uses minimum iOS 14 and Xcode 26.3.
- [Runner image](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md)
- [Manual workflow default-branch requirement](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
- [Public runner billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)

## 実機対応の読み取り監査・今夜のチェックリスト（2026-10-14 JST）

この節は初回成功後のローカル追記。追加commit/push、2回目のActions、Apple/Firebase/Maps設定変更、Secrets登録は未実施。
上の「未実行」は準備時点の記録であり、現状は下記の初回成功を確認済み。

- 準備commit: `67aa28097644a26d6418097c8ec4f45a04cb997c`、基点 `3f40869355a82c5a1a6d617bd9a15b0db327fa1f`。
- [初回run](https://github.com/mekidoapps/vending_navi/actions/runs/38482826381): success、attempt 1、手動dispatch総数1。
- [登録PR #1](https://github.com/mekidoapps/vending_navi/pull/1): mainへworkflowだけを反映。main登録commitは `7572606365aa7aba30cb7f1505d5d65876d1f675`。
- Xcode 26.3 / 17C529、Flutter 3.41.2 / Dart 3.11.0、iOS SDK >=26の事前チェック成功。
- Pod解決・lockfile維持・署名なしRelease成功。Runner.app 95.2MB、job 18分22秒。実機へのインストール・起動・サービス連携は未検証。

### 必須と後回しの区別

| 項目 | repoで確認した状態 | 必須になる時点・具体的な次の作業 |
|---|---|---|
| Apple加入・署名 | ユーザーは未加入。RunnerにDEVELOPMENT_TEAMなし、Automatic signing。配布用証明書/profile未確認 | 今夜はユーザーが加入手続き。加入有効化後にTeam ID、既存/新規App IDの所有者、開発実機用または配布用profileを確認。通常の実機配布/TestFlightには署名が必要。署名なし再コンパイルには不要 |
| Bundle ID | RunnerとDartのFirebase iOS設定が `com.mekidoapps.vendingnavi` で一致。Testsは `.RunnerTests` | Apple App ID・profile・Firebase・OAuth・Maps制限で同じRunner IDを使用。他teamでの利用可否はApple側で確認。登録に失敗しても独断でIDを変更しない |
| Firebase iOS登録 | `lib/firebase_options.dart` にiOS形式App IDとBundle ID。`firebase.json` のDart構成にも同じiOS App ID対応がある | 過去にiOS登録/生成した証拠はある。現在のConsoleでアプリが残り、正しいprojectを参照するかは未確認。既存アプリを読み取り照合し、重複登録しない。初期化/本番接続前に一致確認が必要 |
| Googleログイン | `GoogleSignIn()`にclientId指定なし。Info.plistにGIDClientID・CFBundleURLTypesなし。Dart FirebaseOptionsにもiosClientIdなし | Googleログインを使う実機検証前に、既存iOS OAuth clientのCLIENT_IDをGIDClientIDへ、REVERSED_CLIENT_IDをCFBundleURLTypesのschemeへ設定。Android OAuth clientやMapsキーを流用しない |
| Maps | AppDelegateにGoogleMaps import・GMSServices初期化なし | ホーム地図の実機起動前に `GMSServices.provideAPIKey` をplugin登録/Map生成より前に実行。iOS Bundle IDとMaps SDK for iOSに制限されたキー/有効APIを確認。既存Androidキーの制限・API・課金を変更しない |
| カメラ/写真 | v2 captureはImageSource.camera、requestFullMetadataを明示していない。カメラ/写真ライブラリの使用目的キーが両方ない | 写真登録テスト前にInfo.plistへNSCameraUsageDescription・NSPhotoLibraryUsageDescriptionを追加。例:「自販機や商品の写真を撮影して登録するため」「登録する写真の情報を読み込むため」。動画/録音は今回の経路にないためマイク権限は不要 |
| 位置情報 | WhenInUse使用目的あり、v2は現在地取得。Always/BackgroundModesとgeolocatorのAlways bypassはなし | 現在地許可/拒否/概略位置/設定復帰を実機確認。foreground限定ならPodfileのgeolocator_apple targetだけにBYPASS_PERMISSION_LOCATION_ALWAYS=1を追加する案。Always/背景位置権限を不用意に足さない。背景追跡は後回し |
| App Check | DebugはAppleProvider.debug、Release/ProfileはdeviceCheck。Firebase初期化後のApp Check失敗は起動エラー画面につながる。Functionsのソース上はenforcementあり | 本番バックエンドを使うRelease実機テスト前に既存iOS App Check登録を確認。DeviceCheck利用にはApple側キーとFirebaseへのprovider登録が必要。秘密鍵はConsole指定の安全な経路だけで扱う。enforcementを切る/debugをReleaseへ使う案は不可 |
| native lock | ios/Podfile.lockはrepo/手元ともなし。成功runのArtifactsは空 | 再現可能な次回ビルド/配布検証前に、次回承認runでlockだけ保存・レビューしてcommit。今回の生成lockは回収できない |
| 通知・外部地図 | 旧通知serviceはAndroid初期化のみ、調査したDart呼出しなし。v2外部経路はHTTPS Google Maps URL | 初期のMap/登録/ログインsmokeでは通知は後回し。通知機能を対象にする時にDarwin初期化・権限を別途実装。外部地図のカスタムscheme追加は現v2経路には不要。HTTPS遷移は実機確認 |

FirebaseOptionsを明示してFirebase.initializeAppしているため、GoogleService-Info.plistがないことだけでFirebase初期化失敗とは判定しない。
既存iOSアプリのplistは、OAuth情報を照合するためユーザーが安全にダウンロードする。
ロック済みgoogle_sign_in_ios **5.9.0**の手順はGIDClientIDとURL scheme設定であり、plist全体をアプリへ追加する必要はない。
CLIENT_IDが含まれない場合はGoogle provider/iOS OAuth登録の状態を確認する。GIDServerClientIDはserver auth codeの用途がなければ追加不要。
`flutterfire configure`は登録やAndroid設定も変更し得るため、この監査では実行しない。

### 今夜の順序（設定値はこの文書に記録しない）

1. Apple Accountの2要素認証、個人/法人の区分を確認して加入を申し込む。個人は販売者名が本名、法人はD-U-N-S等が必要。契約・支払いはユーザーが行う。
2. 加入有効化後にTeam IDとApp Store Connectアクセスを確認。Bundle IDの所有/利用可否を確認し、署名方針（開発実機かTestFlightか）を決める。今夜必ず有効化されるとは前提にしない。
3. 既存Firebase projectのiOSアプリをBundle ID/App IDで照合し、対応するGoogle設定を安全に取得する。既存Google providerを変更する必要がある場合は、Androidを含む共有設定なので別途確認する。
4. Maps iOSキー/API制限とDeviceCheck登録状況を確認。キー発行、API有効化、provider登録が必要なら、その限定操作を別途承認してから行う。秘密鍵・認証token・profileをSlack/公開Gitへ貼らない。
5. 実装担当がiOSだけの設定差分を準備・レビューする。署名情報のCI連携は別の承認範囲とし、必要になるまでGitHub Secretsを登録しない。
6. 次のビルド/署名/実機テストの範囲を承認する。初回の承認を根拠に2回目を実行しない。

### 変更案とAndroidへの影響

- `ios/Runner/AppDelegate.swift`: GoogleMaps importと初期化。キーはGit-ignoredローカル設定/明示承認済みCI注入からInfo.plist設定を通じて読む構成案。Mapsキーは配布binaryから隠せる秘密ではないため、iOS/API制限を必須とする。iOS native限定でAndroidコードへの変更なし。
- `ios/Runner/Info.plist`: GIDClientID、CFBundleURLTypes、カメラ/写真使用目的。OAuth値も公開文書へ転記しない。iOSだけの設定でAndroidのログイン/権限への変更なし。
- `ios/Podfile`: foreground用のgeolocator_apple macroだけを既存post_installへ追加し、既存flutter_additional_ios_build_settingsを維持。iOS native限定、Dart pubspec/Android依存は変更不要。
- `ios/Runner.xcodeproj/project.pbxproj`: 署名用team/profileは所有者確認後に必要な設定だけ。Android signing・applicationIdには触れない。
- 既存 `lib/firebase_options.dart` と共通GoogleAuth providerは変更しない案を優先。共有Dart、Firebase Authentication、App Check enforcementを変える案はAndroidにも影響し得るので、別途検証/承認が必要。
- SDK/プラグインの最新資料が要求する最低OSと、今回固定バージョンの要件は区別する。今回iOS 14でコンパイル成功した事実はiOS 14実機動作を保証しない。Firebase/Mapsの新しいmajorへの更新や最低OS引上げは今回は行わない。

### 次回runでPodfile.lockだけを保存する最小案（まだworkflowへ反映していない）

GitHub-hosted runnerはjob後に破棄される。今回のArtifacts APIは `artifacts: []`、キャッシュも無効、repoへの自動commitもない。
run summaryのchecksumはlock内容を復元できないため、今回のlockを後から取得する手段は確認できない。
Macで再解決してlockを作る場合も、今回と同一内容だったとは扱わない。

次回はreviewed full SHAに固定した `actions/upload-artifact` を、compile成功・lock存在確認の後に1step追加する案。
保存対象を**ios/Podfile.lockの1ファイルだけ**、名前をsource SHA付き、`if-no-files-found: error`、`retention-days: 1`に限定。
upload前にprivate source URL/embedded credentialがないか値を出さず検査する。app、Pods、Generated.xcconfig、plist、ログ、署名素材は含めない。
artifact uploadにGITHUB_TOKENのcontents/actions write権限を追加する案は不要。小容量でもartifact storage扱いになるため、取得後は保存ポリシーを守る。
取得後に依存名/版/source・checksumをレビューし、専用ブランチへlockだけ追加する。その追加pushと次回runは未承認。

### 実機smokeと配布前（加入後）

- 実機smoke必須: 署名済みAPP_ENTRY=v2で起動、地図・現在地許可/拒否/概略、Googleログインcancel/成功/logout、写真capture/cancel/拒否、登録/更新、外部経路、App Check成功とFunctionsアクセス。テスト投稿を本番に行う時は既存データへ影響しない承認済み方法を使う。
- App Store/TestFlight前には表示名（現在Vending App）・アイコン・privacy manifest/required-reason API・プライバシー申告/ポリシー・アカウント削除・審査情報を確認。Googleログインを提供する公開版は審査ガイドライン4.8の代替ログイン要件と適用例外を確認し、必要ならSign in with Apple対応を別タスク化。これらは今夜の加入申込み自体を止める条件ではない。
- Windowsでの今回監査は静的確認のみ。アプリコード修正・実機テスト・署名ビルドは行っていない。

### 監査の参考資料（バージョンを固定して確認）

- [Google Sign-In iOS 5.9.0](https://pub.dev/packages/google_sign_in_ios/versions/5.9.0)
- [image_picker 1.1.2](https://pub.dev/packages/image_picker/versions/1.1.2)
- [geolocator 14.0.2](https://pub.dev/packages/geolocator/versions/14.0.2)
- [Maps Flutter iOS設定](https://developers.google.com/maps/flutter-package/config)
- [Firebase Flutter初期化](https://firebase.google.com/docs/flutter/setup)
- [DeviceCheck設定](https://firebase.google.com/docs/app-check/ios/devicecheck-provider)
- [Apple加入](https://developer.apple.com/programs/enroll/)
- [App Review 4.8](https://developer.apple.com/app-store/review/guidelines/#login-services)
- [GitHub-hosted runner](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [Artifact保存action](https://github.com/actions/upload-artifact)

## iPhone専用ローカル修正（未push・未再ビルド）

ブランチ: `ios/device-configuration`、基点は初回成功commit `67aa28097644a26d6418097c8ec4f45a04cb997c`。
前節の不足表はこの修正前の監査結果。今回確定できるiOS native設定のみを修正した。

- Info.plistにカメラ・写真読み取りの日本語使用目的を追加。マイク、Always位置情報、背景実行は追加しない。
- Podfileでgeolocator_appleだけにforeground用macroを追加。既存の定義とFlutterのbuild settingsを維持。
- AppDelegateでGoogleMapsをimportし、確認済み形式のキーが設定された時だけGMSServicesを初期化。空欄・未展開変数・placeholderは渡さない。
- Maps未設定、Googleログインclient未設定/形式不正、clientとcallback schemeの不一致は起動時にNSLogで診断。値は出力しない。
- Info.plistのMaps/GIDClientID/URL schemeはXcode変数から注入。Debug・Release・Profileが同じiOS設定経路を使う。
- `ios/Flutter/Services.xcconfig` は空欄default。実値を含める `LocalServices.xcconfig` だけをGit-ignoreし、空欄の `.example` を提供。共有Dart・FirebaseOptions・Android・本番cloud・App Check・Bundle ID・署名は変更していない。

### 実値確定後の安全なローカル設定手順

1. `ios/Flutter/LocalServices.xcconfig.example` を同じ場所の `LocalServices.xcconfig` へコピーする。今は空欄のままであり、このPCでは実値ファイルを作っていない。
2. 既存の対応するiOS設定から3値だけを記入する。`GOOGLE_MAPS_IOS_API_KEY` はiOS/API制限済みMapsキー、`GOOGLE_SIGN_IN_IOS_CLIENT_ID` はCLIENT_ID、`GOOGLE_SIGN_IN_REVERSED_CLIENT_ID` は同じclientのREVERSED_CLIENT_ID。flatな代入のみ、quote/include/環境変数展開を使わない。
3. `node tool/check_ios_runtime_config.cjs` を実行する。値を表示せず、必須3値・placeholder・キー/client形式・callback一致をチェックする。未設定はexit 1で止まる。
4. 別途承認されたmacOSビルド後、次を実行する。

   ```sh
   node tool/check_ios_runtime_config.cjs --built-plist build/ios/iphoneos/Runner.app/Info.plist
   ```

   macOSのplutil出力をメモリ内で読み、Bundle ID・Maps・OAuth・schemeの実際の注入結果を照合する。値を標準出力へ出さない。
5. preflight成功でもキーの有効性、cloud/API制限、署名、DeviceCheckの成功は別の実機検証が必要。構文が正しいだけで有効なキーと判断しない。実値ファイル・展開済みplist・appを公開Git/ログへ出さない。

未設定のままでも署名なしコンパイル用構成を保持する。起動ログの診断は未設定アプリを利用可能にする措置ではない。
Maps画面/Googleログインを実機で使う前に必ずpreflightとサービス設定確認を行う。現時点の未設定値は3値すべて。
署名・Team・Firebase登録の現状・App Check DeviceCheck登録は今回も未確認/未設定のまま。

### 今回のローカル検証範囲

- Node構文、未設定CLIのexit 1、設定検証8ケース、built plist照合6ケース、Info.plist XML、Git-ignore、Android/共通/cloud差分なし、git diff --checkを確認。
- 正常系テストはメモリ内の構文用fixtureのみ。実在credentialとして使用/保存/認証していない。
- WindowsにSwift compiler/Xcode/Ruby/CocoaPodsがないため、新しいnativeコードのコンパイル・Podfile実行・実機動作は未検証。前回成功runはこの追加差分の検証結果ではない。
- workflowやSecretsの変更、追加push、2回目のActions、Apple/cloud設定変更はしていない。
