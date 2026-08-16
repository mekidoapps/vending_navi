# P7-11 Storage Rules Split + Photo Content Binding

## Why the rules are split

`firebase/v2/storage.rules` remains the production-intent ruleset and keeps:

```text
resource == null
```

for first-write-only temporary objects.

The local Storage Emulator currently has a known mismatch when evaluating
overwrite uploads against this resource state. The v2 emulator config therefore
loads:

```text
firebase/v2/storage.emulator.rules
```

which preserves auth / owner / UUID / JPEG / size constraints but does not claim
to prove overwrite immutability.

The production file is not weakened.

## Defense in depth: exact recognized-byte binding

Recognition now computes server-side SHA-256 over the exact normalized JPEG
bytes sent to Vertex AI.

The private recognition session stores only:

```text
photoObjectPath
photoContentSha256
photoSizeBytes
```

in addition to the existing provider/candidate/session fields.

No image bytes are stored in Firestore.

During the later photo-finalization step, the server must re-read the temporary
JPEG and require the SHA-256 to match the session before any candidate can be
treated as `photo_confirmed`.

This protects the evidence relationship even if the temporary object is replaced
through an emulator limitation or another unexpected path.

## Tests

Storage Rules:

- executable emulator tests use `storage.emulator.rules`
- production immutable guard is statically asserted
- overwrite semantic test is explicitly skipped with the emulator limitation in
  the test name rather than being made green by weakening production rules

Functions:

- exact photo SHA-256 deterministic
- different bytes produce a different binding
- completed recognition persists the binding
- failed recognition has no photo-confirmed binding
- replay parsing supports the binding

E2E verifier also checks that the stored session SHA-256 equals the local JPEG
used for recognition.
