# P9-03 App Check Enforcement

## Decision

All public v2 Callable Functions use one shared App Check runtime policy.

Production:

enforceAppCheck = true

Firebase Functions Emulator:

enforceAppCheck = false

The only condition that disables enforcement is:

FUNCTIONS_EMULATOR === "true"

Missing, false, malformed or differently-cased values do not disable App
Check.

## Client behavior

Existing Flutter bootstrap behavior remains unchanged.

Firebase Emulator Suite:
- App Check activation is skipped.

Debug build against Firebase:
- AndroidProvider.debug
- AppleProvider.debug

Android release:
- AndroidProvider.playIntegrity

Apple release:
- AppleProvider.deviceCheck

## Covered Callable Functions

- createVendingMachine
- recognizeVendingMachinePhoto
- updateVendingMachineProducts
- addVendingMachinePhoto
- submitMachineCorrection
- submitMachineReport

v2EmulatorHealth remains emulator-only and is not a production application
endpoint.

## Security model

App Check supplements but does not replace:

- Firebase Authentication
- accountStatus validation
- input validation
- requestId idempotency
- Firestore Rules
- Storage Rules
- Phase 9 rate limiting

## Deployment note

P9-03 changes source configuration only.

No Firebase production deployment is performed as part of this implementation
step.

Before the first production deployment with enforcement enabled, Firebase
Console App Check provider configuration and the Android Play Integrity path
must be verified on a release build.
