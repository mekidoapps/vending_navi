# P7-10 Emulator E2E Verification

This script is emulator-only and refuses to run unless all emulator host
variables exactly target localhost.

Expected topology:

```text
Auth Emulator       127.0.0.1:9099
Firestore Emulator  127.0.0.1:8080
Functions Emulator  127.0.0.1:5001
Storage Emulator    127.0.0.1:9199
Vertex AI            real Google Cloud / ADC
```

Bucket:

```text
vendingnavi.firebasestorage.app
```

Verification:

1. emulator auth user is created
2. JPEG is uploaded to emulator temporary Storage
3. Callable is invoked with auth token
4. real Vertex provider recognizes the photo
5. existing emulator Master is resolved
6. private recognition session is stored
7. same recognitionRequestId is invoked again
8. response is identical
9. session/operation updateTime remains unchanged on replay

The script does not deploy Functions and does not write to production Firestore
or production Storage.
