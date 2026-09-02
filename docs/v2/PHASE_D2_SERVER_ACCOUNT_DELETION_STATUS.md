# Phase D.2 Server Account Deletion Status

Date: 2026-09-02

## Status

PASS - SERVER / EMULATOR

READY FOR CLIENT INTEGRATION

This document records completion of the server-side account deletion workflow.

Phase D overall is NOT complete yet.

Remaining work includes:

- Flutter reauthentication flow
- in-app account deletion UI
- production deployment
- disposable production-account verification
- external web deletion resource
- Play Console account deletion URL registration

## Security contract

Account deletion requires:

- an authenticated Firebase user;
- explicit `DELETE_ACCOUNT` confirmation;
- authentication within the previous 10 minutes;
- the shared App Check policy.

Account deletion intentionally does not use the normal content-operation
rate limiter because a partially completed deletion must remain retryable.

## Deleted user-owned data

The server deletion workflow removes:

- `users/{uid}` recursively, including all present and future subcollections;
- `request_deduplication` records owned by the UID;
- `operation_rate_limits` records owned by the UID;
- `photo_recognition_sessions` records owned by the UID;
- feedback records matched by UID;
- legacy feedback records matched by the authenticated account email;
- machine reports authored by the UID;
- machine corrections authored by the UID;
- temporary Storage objects under `machine_uploads/{uid}/`.

## Retained public/community data

Published vending-machine contributions remain available.

The workflow preserves:

- public vending-machine roots;
- vending-machine product documents;
- `machine_product_index`;
- formal published vending-machine photos;
- revision/history documents.

Identity attribution belonging to the deleted account is removed from retained
documents.

## Anonymized attribution

The workflow removes the deleted UID or related legacy identity fields from:

- `vending_machine_private/{machineId}.createdBy`;
- Phase C.1 `legacyPublicActorMetadata`;
- private product `confirmedBy`;
- vending-machine revision `updatedBy`;
- vending-machine photo `uploadedBy`;
- reviewer-only `reviewedBy` fields on retained reports;
- reviewer-only `reviewedBy` fields on retained corrections.

Other users' attribution is unchanged.

## Ordering and retry safety

Firebase Authentication is deleted LAST.

All Firestore and temporary Storage cleanup occurs before Auth deletion.

A fault-injection Emulator test verified that when Storage deletion fails:

- the account deletion request fails;
- the Firebase Auth user remains;
- already completed Firestore cleanup is safe;
- the same deletion workflow can be retried;
- the retry deletes the remaining Storage object;
- the retry finally deletes the Auth user.

Therefore a pre-Auth partial failure does not strand the user without a
retry path.

## Emulator E2E result

The account deletion Emulator verification passed.

Verified behaviors:

- recursive user tree deletion;
- operational private data deletion;
- feedback deletion;
- authored moderation-record deletion;
- reviewer identity anonymization;
- private vending-machine attribution anonymization;
- revision attribution anonymization;
- photo attribution anonymization;
- public vending-machine preservation;
- public vending-machine product preservation;
- public search-index preservation;
- temporary Storage deletion;
- formal Storage preservation;
- foreign-user data preservation;
- Firebase Auth deletion after cleanup;
- Auth preservation on injected pre-Auth failure;
- successful retry after partial cleanup.

## Regression result

Functions TypeScript build: PASS

Functions tests:

- tests: 160
- passed: 160
- failed: 0

Additional contracts verify:

- `deleteAccount` adds no identity-bearing failure logs;
- all content mutation Callables remain rate limited;
- `deleteAccount` uses recent authentication instead of content rate limiting;
- `deleteAccount` remains under the shared App Check policy.

## Production status

The new `deleteAccount` Callable has NOT been deployed to production yet.

No production account was deleted during Phase D.2.

The existing production Auth population is unchanged by this phase.

## Decision

Phase D.1 account deletion safety contract: PASS

Phase D.2 server deletion implementation: PASS

Phase D overall: OPEN

P0-03 account deletion requirement: PARTIALLY RESOLVED

Production release decision: NO-GO
