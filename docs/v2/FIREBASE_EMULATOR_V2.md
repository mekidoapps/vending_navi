# Firebase Emulator Suite for VendingNavi v2

## Purpose

Develop and test the v2 backend without changing the existing v1 Firebase
configuration or production rules.

## Isolated files

```text
firebase.v2.json
firebase/v2/firestore.rules
firebase/v2/firestore.indexes.json
firebase/v2/storage.rules
functions/
```

The existing `firebase.json` and root `firestore.rules` remain unchanged.

## Phase 1 security state

- Firestore client reads: denied
- Firestore client writes: denied
- Storage reads: denied
- Storage writes: denied
- Functions: emulator-only health callable, no business writes

Permissions are opened only when a v2 feature and its emulator tests are added.

## Flutter defines

```text
USE_FIREBASE_EMULATORS=true
FIREBASE_EMULATOR_HOST=10.0.2.2
```

Optional port overrides:

```text
FIREBASE_AUTH_EMULATOR_PORT=9099
FIRESTORE_EMULATOR_PORT=8080
FIREBASE_FUNCTIONS_EMULATOR_PORT=5001
FIREBASE_STORAGE_EMULATOR_PORT=9199
```

`USE_FIREBASE_EMULATORS=true` is ignored in release builds.

## Start

From the repository root:

```bash
firebase emulators:start --config firebase.v2.json \
  --only auth,firestore,functions,storage
```

Android Emulator:

```bash
flutter run \
  --dart-define=APP_ENTRY=v2 \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

Physical Android device:

Use the development PC's LAN IPv4 address instead of `10.0.2.2`. The device and
PC must be on the same network, and Windows Firewall must permit the emulator
ports.

## Safety rules

- Always pass `--config firebase.v2.json` when starting the v2 emulators.
- Do not replace the root `firebase.json` during Phase 1.
- Do not run `firebase deploy` for P1-07.
- Do not add a permissive temporary rule such as `allow read, write: if true`.
- Add rules and indexes only with the feature that needs them.
