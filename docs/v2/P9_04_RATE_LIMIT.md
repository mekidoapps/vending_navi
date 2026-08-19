# P9-04 Operation Rate Limit

## Purpose

Authenticated and App-Check-protected requests still require server-side
operation limits to reduce abuse, automation mistakes and AI cost exposure.

## Responsibility separation

requestId idempotency:
- prevents duplicate public mutations.

Operation rate limiting:
- limits Callable invocations per authenticated user.
- counts retries and failed requests as requests.
- does not replace requestId idempotency.

## Storage

Private Firestore collection:

operation_rate_limits/{sha256(uid + operation)}

Clients have no direct read/write access under the v2 deny-by-default
Firestore Rules.

Each document stores only the current fixed-window state.

Fields:

- uid
- operation
- windowStartedAt
- windowEndsAt
- count
- updatedAt

A single document per user/operation is reused when the window changes, so
historical rate-limit documents do not grow without bound.

## MVP baseline

One fixed one-hour window per operation.

- createVendingMachine: 30/hour
- recognizeVendingMachinePhoto: 20/hour
- updateVendingMachineProducts: 60/hour
- addVendingMachinePhoto: 30/hour
- submitMachineCorrection: 30/hour
- submitMachineReport: 30/hour

These are Phase 9 safety baselines, not permanent product limits.

Phase 11 closed testing may adjust the numbers based on legitimate usage,
AI cost and false-positive observations.

## Limit response

Exceeded limits return:

Firebase Functions code:
resource-exhausted

Application details:
appCode = rate-limit-exceeded
retryAfterSeconds = seconds until the next fixed window

## Atomicity

The current count is read and incremented in a Firestore transaction.

P9-04A creates and unit-tests the shared limiter.

P9-04B wires it into all six public v2 Callable Functions and verifies the
behavior against the Firebase Emulator Suite.
