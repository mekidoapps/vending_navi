# Firebase v2 local configuration

This directory is intentionally isolated from the existing production-oriented
`firebase.json` and `firestore.rules`.

Phase 1 policy:

- Firestore rules deny every client read and write.
- Storage rules deny every client read and write.
- Permissions are added only with the feature and its emulator tests.
- Public-data writes remain Callable Functions only.
- Do not deploy these files during Phase 1.

Start from the repository root:

```bash
firebase emulators:start --config firebase.v2.json \
  --only auth,firestore,functions,storage
```
