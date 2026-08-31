# P9-02 Firebase Config / App Check Baseline

## Historical note

Phase 9 originally separated `firebase.v2.json` and
`firebase.v2.production.json`. The 2026-08-31 release audit found that this left
the root `firebase.json` pointing at legacy permissive Rules and made the deploy
source ambiguous.

Phase A of the release remediation supersedes that layout:

- `firebase.json` is the only Firebase configuration.
- `.firebaserc` fixes the default project to `vendingnavi`.
- `firebase/v2/firestore.rules` is the canonical Firestore Rules source.
- `firebase/v2/storage.rules` is shared by production and Emulator tests.
- `functions` with codebase `v2` is the only Functions source.
- obsolete split configs and root legacy Rules are removed.

See:

- `FIREBASE_EMULATOR_V2.md`
- `FIREBASE_RELEASE_OPERATIONS.md`

## App Check baseline

- Emulator Suite enabled: App Check activation is skipped.
- Debug build against Firebase: debug provider.
- Android release build: Play Integrity provider.
- Release builds cannot connect to the Emulator Suite.
- Production Functions enforce App Check through the shared runtime policy.

The Firebase Console enforcement state and Play-distributed release behavior
must still be verified before release.
