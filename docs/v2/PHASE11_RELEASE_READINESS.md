# Phase 11 Release Readiness

## Status

**Superseded by the 2026-08-31 production release audit: NO-GO.**

This file records the readiness state before that independent audit. It must not
be used as current production approval. versionCode 17 must not be promoted to
Production. Follow `PHASE_A_RELEASE_IDENTITY_REMEDIATION.md` and the P0/P1
remediation phases, then create a new versionCode and obtain an independent GO.

Historical status: Phase 11 pre-closed-test release readiness.

Phase 10 quality validation is complete.
This checklist separates code-side readiness from production Console / deployment work.

## 1. App Check / Play Integrity

### Code-side

Status: READY

- Production Firebase path uses App Check.
- Emulator path permits Emulator verification without production App Check token.
- Callable Functions enforce the production security boundary defined in Phase 9.

### Production-side

Status: VERIFY / CONFIGURE BEFORE CLOSED TEST

Confirm in Firebase Console:

- Android app is registered for App Check.
- Play Integrity provider is enabled.
- Production enforcement state is intentional.
- Release build receives valid App Check tokens.

Do not consider Emulator `app=MISSING` logs a production failure.

---

## 2. Firestore Rules / Indexes

### Code-side

Status: READY

Phase 10 final Emulator regression verified:

- public master rules
- vending-machine active/hidden boundaries
- machine-product active/hidden boundaries
- machine-product-index boundaries
- client public-data writes denied

### Production-side

Status: DEPLOY / VERIFY BEFORE CLOSED TEST

Confirm production has the current:

- `firebase/v2/firestore.rules`
- `firebase/v2/firestore.indexes.json`

After deployment, perform a production read smoke test.

---

## 3. Storage Rules / Temporary Photo Lifecycle

### Code-side

Status: READY

- Temporary photo area is user-scoped.
- Formal publication is handled by trusted server-side processing.
- Photo registration/update Emulator verification passed.
- Temporary photo cleanup after successful finalization was verified.

### Production-side

Status: CONFIGURE / VERIFY BEFORE CLOSED TEST

Confirm:

- production Storage rules are current
- bucket lifecycle policy removes abandoned temporary uploads
- lifecycle configuration does not delete formal published photos

The exact production bucket policy must be checked before applying changes.

---

## 4. Legacy Data Migration / Backfill

### Code-side

Status: READY FOR CONTROLLED MIGRATION

- v1/v2 coexistence was validated.
- legacy and v2 records can coexist without breaking public browsing.
- migration/backfill tooling was tested against Emulator only.

### Production-side

Status: REVIEW REQUIRED

Before production migration:

- inspect current production legacy record counts
- determine which records actually require backfill
- run a dry-run / read-only assessment first
- do not perform destructive bulk migration without review

Closed testing may proceed with coexistence if production reads remain valid and required security fields are present.

---

## 5. Google Maps API Key Restrictions

### Code-side

Status: READY

Android integration and Pixel 6a map operation were validated in Phase 10.

### Google Cloud-side

Status: VERIFY BEFORE CLOSED TEST

Confirm the Android Maps API key is restricted by:

- Android application
- package name: `com.mekidoapps.vendingnavi`
- correct signing certificate fingerprint for the closed-test build

Also confirm only required APIs are enabled.

---

## 6. Firebase Auth Production Smoke

### Emulator / test-side

Status: READY

Phase 10 verified:

- auth-required action handling
- authentication resume
- manufacturer registration after authentication
- unauthenticated Callable rejection

### Production-side

Status: REQUIRED BEFORE CLOSED TEST

Using a release-like build, verify:

- account creation / login
- logout
- persisted login after restart
- auth-required registration resume
- authenticated Callable execution

Use a dedicated test account.

---

## 7. Android Release Build

Status: REQUIRED BEFORE CLOSED TEST

Verify:

- release signing configuration
- versionName / versionCode
- production Firebase configuration
- production Maps configuration
- no Emulator dart-defines
- release AAB build succeeds
- installation through Play closed-test path succeeds

Release build must not use:

- `USE_FIREBASE_EMULATORS=true`
- local Emulator hosts

---

## 8. Phase 10 Quality Evidence

Status: PASSED

Completed:

- mandatory MVP scenarios: 15 / 15
- Phase 10 integration tests: 4 / 4
- representative responsive validation
- Pixel 6a Android 17 validation
- real-photo AI validation
- Flutter full regression
- Functions build/test
- Firebase Emulator Rules / Callable regression
- P0: 0
- P1: 0

See:

- `PHASE10_COMPLETION_REPORT.md`
- `PHASE10_SCENARIO_COVERAGE.md`

---

## 9. Closed Test Cycle 1 Readiness Gate

Cycle 1 distribution can begin only when the following production-facing items are complete:

- [ ] App Check / Play Integrity confirmed
- [ ] production Firestore Rules deployed and verified
- [ ] production Firestore indexes deployed / ready
- [ ] production Storage rules verified
- [ ] temporary-photo lifecycle policy verified
- [ ] legacy production data assessed
- [ ] Maps API key restrictions confirmed
- [ ] Firebase Auth production smoke passed
- [ ] release AAB build passed
- [ ] closed-test build installed successfully from Play
- [ ] no known P0
- [ ] no known P1

## 10. Phase 11 Scope Rule

Do not add MVP-outside features during closed testing.

Cycle 1 findings are classified as:

- P0: immediate mandatory fix
- P1: mandatory Phase 11 fix
- P2: fix when multiple testers hit the same UX problem or impact is material
- P3: backlog unless required for release safety

After fixes, run Cycle 2 regression and release-candidate evaluation.
