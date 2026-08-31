# Firebase Emulator Suite for VendingNavi v2

## Canonical configuration

Local emulators and production deployment share one resource map:

```text
.firebaserc
firebase.json
firebase/v2/firestore.rules
firebase/v2/firestore.indexes.json
firebase/v2/storage.rules
functions/
```

This prevents local verification from exercising Rules different from the
Rules selected for production. `firebase.json` retains the Emulator port
configuration, but the same Firestore, Storage, indexes, and Functions sources
are used in both environments.

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
tool/verify_firebase_release_config.sh
firebase emulators:start \
  --config firebase.json \
  --project vendingnavi \
  --only auth,firestore,functions,storage
```

Android Emulator:

```bash
flutter run \
  --dart-define=APP_ENTRY=v2 \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

For a physical Android device, use the development PC's LAN IPv4 address
instead of `10.0.2.2`. The device and PC must be on the same network, and the
local firewall must permit the Emulator ports.

## Safety rules

- Keep `.firebaserc` fixed to `vendingnavi`.
- Do not create a second deployable Firebase config.
- Do not add permissive temporary Rules.
- Do not deploy from a dirty working tree.
- Never use a bare production `firebase deploy` command; use the guarded script
  with an explicit resource scope.
