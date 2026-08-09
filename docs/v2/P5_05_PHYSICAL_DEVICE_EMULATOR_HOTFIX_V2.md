# P5-05 Physical Android Device / Firebase Emulator Hotfix

> 更新日: 2026-08-09

## 原因

Android実機を`adb reverse`でFirebase Emulatorへ接続するとき、
アプリは`127.0.0.1`を指定する。

しかしFlutterFireのEmulator APIにはAndroid向けの
automatic host mappingがあり、`127.0.0.1` / `localhost`を
`10.0.2.2`へ変換できる。

今回の実機ログでは:

```text
Mapping Auth Emulator host "127.0.0.1" to "10.0.2.2".
...
Cleartext HTTP traffic to 10.0.2.2 not permitted
```

となり、物理端末＋`adb reverse`の意図と衝突していた。

## 修正

Firebase Emulator connectorの4サービスすべてで:

```dart
automaticHostMapping: false
```

を指定する。

対象:

```text
Firebase Auth
Cloud Firestore
Cloud Functions
Firebase Storage
```

## Host運用

### Android物理端末 + adb reverse

```bash
adb reverse tcp:8080 tcp:8080
adb reverse tcp:9099 tcp:9099
adb reverse tcp:5001 tcp:5001
adb reverse tcp:9199 tcp:9199

flutter run \
  --dart-define=APP_ENTRY=v2 \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

### Android Emulator

`adb reverse`を前提にしない通常運用では:

```bash
flutter run \
  --dart-define=APP_ENTRY=v2 \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

hostは環境側で明示する。

## 非変更

- production Firebase設定
- firebase.json
- Firestore Rules
- Functions
- pubspec dependency versions
- Auth Repository / UI
