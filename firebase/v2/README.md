# Firebase v2 resources

`firebase.json` is the single canonical configuration for both production
deployment and the local Emulator Suite. It points to the files in this
directory:

- `firestore.rules`
- `firestore.indexes.json`
- `storage.rules`

The Firebase project is fixed to `vendingnavi` in `.firebaserc`. Obsolete
`firebase.v2*.json`, root `firestore.rules`, and emulator-only Storage rules
must not be restored.

Verify the configuration before any Firebase operation:

```bash
tool/verify_firebase_release_config.sh
```

Start local emulators from the repository root:

```bash
firebase emulators:start \
  --config firebase.json \
  --project vendingnavi \
  --only auth,firestore,functions,storage
```

Production deployment must use `tool/deploy_firebase_production.sh` with an
explicit resource scope. See `docs/v2/FIREBASE_RELEASE_OPERATIONS.md`.
