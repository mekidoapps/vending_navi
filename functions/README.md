# VendingNavi v2 Functions

Phase 1 contains only an emulator-only health callable. It has no Firestore or
Storage side effects and refuses execution outside the Functions emulator.
Business functions such as `createVendingMachine` are added later together with
validation, idempotency, rate limits, App Check policy, and tests.

## Local commands

```bash
npm install
npm run build
npm test
```

Do not run `firebase deploy` as part of Phase 1.
