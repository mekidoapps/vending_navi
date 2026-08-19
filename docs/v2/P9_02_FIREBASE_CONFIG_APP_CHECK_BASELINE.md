# P9-02 Firebase Config / App Check Baseline

## Purpose

Phase 9 security hardening separates Firebase Emulator configuration from
production deployment configuration before App Check enforcement is enabled.

## Firebase configuration

### firebase.json

Legacy/v1 compatibility configuration.

Phase 9 does not modify or reuse this file for v2 production deployment.

### firebase.v2.json

v2 local Emulator Suite configuration.

It intentionally uses:

firebase/v2/storage.emulator.rules

This file is used by existing emulator gates, scripts and local development
documentation and therefore retains its existing filename.

It must not be used for production deployment.

### firebase.v2.production.json

v2 production deployment configuration.

It uses:

- firebase/v2/firestore.rules
- firebase/v2/firestore.indexes.json
- firebase/v2/storage.rules
- functions codebase v2

It contains no Emulator configuration.

Future v2 production deployments must explicitly use:

firebase deploy \
  --config firebase.v2.production.json \
  --project vendingnavi

Production deployment is not performed as part of P9-02.

## Flutter App Check baseline

Current bootstrap behavior is retained:

- Firebase Emulator Suite enabled:
  App Check activation is skipped.
- Debug build against Firebase:
  AndroidProvider.debug / AppleProvider.debug.
- Android release build:
  AndroidProvider.playIntegrity.
- Apple release build:
  AppleProvider.deviceCheck.
- Release builds cannot connect to Firebase Emulator Suite.

This separation is suitable for Phase 9 App Check enforcement.

## Functions baseline

At the end of P9-02 the public v2 Callable Functions still use:

enforceAppCheck: false

P9-03 changes this so that:

- production Functions enforce App Check;
- local Functions Emulator remains usable by emulator E2E verifiers.

## Deployment safety rule

Never deploy v2 Firebase resources with:

--config firebase.v2.json

Production v2 deployments must explicitly use:

--config firebase.v2.production.json
