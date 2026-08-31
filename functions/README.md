# VendingNavi v2 Functions

The v2 codebase contains the six production Callable Functions plus an
emulator-only health Callable. Production Callables share authentication,
App Check, rate-limit, validation, idempotency, and privacy-safe logging
boundaries.

## Local commands

```bash
npm ci
npm run build
npm test
```

Start the Functions emulator from the repository root with the canonical
Firebase config, or run `npm run serve` here.

Do not deploy directly from this directory. Production deployments must follow
`docs/v2/FIREBASE_RELEASE_OPERATIONS.md`.
