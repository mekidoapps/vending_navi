# Phase 9 Security Hardening Completion Report

## Status

Repository-side Phase 9 security hardening is complete.

Production Firebase / Google Cloud changes are intentionally not performed
during this phase completion step.

## Completed work

### Firebase configuration

- Emulator and production Firebase configurations are separated.
- Production configuration uses production Firestore and Storage Rules.
- Release builds cannot intentionally connect to local Firebase Emulators.

### App Check

- Production Callable Functions enforce App Check.
- Functions Emulator disables enforcement only when the runtime explicitly
  identifies itself as the Emulator.
- Production App Check provider registration and release-build validation
  remain pre-release deployment tasks.

### Callable protection

The following public Callable Functions require authentication and are
protected by operation rate limiting:

- createVendingMachine
- recognizeVendingMachinePhoto
- updateVendingMachineProducts
- addVendingMachinePhoto
- submitMachineCorrection
- submitMachineReport

Rate limiting is isolated by user and operation and returns
resource-exhausted when exceeded.

The rate-limit collection remains inaccessible to normal clients.

### Temporary photos

Temporary uploads:

- are owner-only
- are JPEG only
- are limited to 5 MiB
- use UUID-based upload paths
- are bound to the exact recognized bytes
- expire for application use after 24 hours
- are deleted best-effort after successful finalization

Abandoned temporary uploads are covered by the repository lifecycle
configuration:

firebase/v2/storage.lifecycle.json

The lifecycle configuration targets only:

machine_uploads/

Production lifecycle configuration must be inspected and merged before it is
applied to the actual bucket.

### Logging privacy

Server and Flutter logging were audited.

Logs do not expose:

- raw Callable payloads
- authentication tokens
- App Check tokens
- email addresses
- image bytes
- raw AI responses
- correction/report free-form text
- exact coordinates
- arbitrary runtime exception messages or stacks

### Firestore public boundaries

Public clients may read:

- product and manufacturer master documents
- active vending machines
- active products belonging to active vending machines
- active machine-product search-index entries belonging to active machines

Public clients may not directly write community vending-machine data.

Non-public vending-machine states such as:

- underReview
- hidden
- removed
- merged

are not directly readable.

Private collections remain deny-by-default.

### Master inactive semantics

isActive == false on product/manufacturer master data means:

- unavailable for new selection
- unavailable for new search

It does not mean the historical master document is secret.

Inactive master documents remain readable so historical vending-machine data
can still resolve names.

### Legacy compatibility

Legacy vending-machine documents can be missing status.

Before hardened Firestore Rules are deployed to production, legacy documents
with missing status must receive:

status: active

using the dedicated non-destructive migration:

functions/scripts/backfill_legacy_machine_status.ts

The migration:

- defaults to dry-run
- does not change schemaVersion
- does not remove legacy fields
- does not overwrite an explicit status
- requires explicit production opt-in
- requires project confirmation for production apply

## Final repository verification

Phase 9 final regression includes:

- Functions build
- Functions full test suite
- Flutter full test suite
- targeted Flutter analyze
- Firestore Rules verification
- machine-product-index Rules verification
- master Rules verification
- Storage/photo-flow verification
- photo recognition
- photo vending-machine creation
- vending-machine creation
- product update
- existing-machine photo publication
- correction proposal
- machine report
- operation rate limiting
- legacy status migration dry-run/apply verification

All repository-side Phase 9 gates passed.

## Production pre-release checklist

The following items are intentionally pending until production/release
preparation.

### 1. Confirm production targets

Confirm the exact:

- Firebase project ID
- Cloud Storage bucket name
- Android application ID
- release signing certificate

Do not infer or hard-code the production bucket name without verification.

### 2. App Check

In Firebase Console:

- register the Android production app for App Check
- enable the Play Integrity provider
- verify a release-signed build obtains valid App Check tokens
- verify protected Callable Functions work with the release build
- only then deploy/enforce the production Functions path

### 3. Google Maps API key

In Google Cloud Console:

- use Android application restrictions
- register com.mekidoapps.vendingnavi
- register the release signing SHA-1 fingerprint
- restrict the key to only the required Google Maps Platform APIs

### 4. Legacy vending-machine migration

Run production dry-run first.

Review:

- scanned count
- legacy count
- candidate count
- already-active count
- explicit-other-status count

Apply only after the result is understood.

After apply, rerun dry-run and require:

candidates=0

before hardened Firestore Rules are deployed.

### 5. Firestore

Deploy:

- firebase/v2/firestore.rules
- firebase/v2/firestore.indexes.json

Then rerun production-safe read/write verification.

### 6. Temporary-photo lifecycle

Before applying:

firebase/v2/storage.lifecycle.json

inspect the bucket's current lifecycle configuration.

If lifecycle rules already exist, merge them rather than blindly replacing
the configuration.

Apply only to the confirmed production bucket.

### 7. Cloud Storage behavior

Do not rely on lifecycle deletion occurring at exactly 24 hours.

Application-level temporary-photo validity is already limited to exactly
24 hours by backend validation.

Review the production bucket's soft-delete / retention configuration before
changing it.

### 8. Post-deploy smoke test

Using a release-like Android build, verify:

- guest public browsing
- login
- vending-machine creation
- photo recognition
- product update
- photo publication
- correction submission
- report submission
- search
- hidden/inactive data rejection
- App Check enforcement
- Maps display

## Result

Phase 9 repository security hardening is complete.

Production configuration and deployment remain explicit pre-release tasks.
