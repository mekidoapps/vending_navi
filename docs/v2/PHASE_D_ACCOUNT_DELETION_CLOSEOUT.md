# Phase D: Account Deletion Closeout

## Status and scope

Production account-deletion E2E: **PASS**. This is a record of the verified
Phase D evidence, not a new deletion test or authorization for another
Production mutation. Only a newly created disposable account was used.

The deletion workflow is available in the app and at
`https://vendingnavi.web.app/delete-account`. Privacy and restore guidance in
this source update still require a separate Hosting publication decision and
Play Data Safety manual alignment check. No Production deployment or Play
Console change is part of this closeout.

The earlier `PHASE_D2_SERVER_ACCOUNT_DELETION_STATUS.md` describes the
historical server/Emulator milestone; its former Production-pending status is
not the current Phase D status and has not been rewritten.

## Production E2E evidence

- Google Play closed testing (Alpha), version 1.0.0, version code 19.
- Password reauthentication and `deleteAccount`: PASS.
- App transition to Guest: PASS.
- Firebase Auth account and `users/{uid}`: absent after deletion.
- Favorites, temporary Storage upload, photo-recognition session, request
  deduplication, and operation-rate-limit records: absent after deletion.
- Existing-account re-login with the same credentials: failed as expected.
- Impact on unrelated users: not observed.
- Play Data Safety account-deletion URL: registered as
  `https://vendingnavi.web.app/delete-account`.

Do not repeat the Production disposable-account deletion E2E merely to close
the documentation follow-up. No deleted test email, UID, password, token, or
credential is recorded here.

## Index remediation before the E2E

The initial deletion preflight found a missing Production index for the
`blocked_actors` collection-group query on `actorUid`. The required index is
`actorUid` ASCENDING with `COLLECTION_GROUP` scope. Its source correction is
in `firebase/v2/firestore.indexes.json` at Git SHA
`6854ba412518d418161dd5782766ab55f83d276c`.

Deletion-related tests passed 13/13, formal Functions tests passed 315/315,
and the release verifier passed. Only `firestore:indexes` was deployed for
the remediation. The index reached READY; the query retest succeeded with
zero matching records. The subsequent disposable-account E2E passed.

## Recovery and retention context

- Firestore PITR: enabled, 7 days.
- Firestore scheduled backup: daily, 98-day retention. Latest successful
  backup evidence for this closeout: 2026-09-24 11:01:55 JST.
- Cloud Storage soft delete: 7 days.
- Online account/private-data cleanup and recovery-copy retention are
  separate. A snapshot created before deletion may retain earlier data for
  its configured period; an isolated restore copy needs separate control.
- `P23_BACKUP_DR_RUNBOOK.md` now requires candidate UID-reference review,
  comparison with current Firebase Auth state, exclusion of private data for
  absent Auth accounts, stop-and-review for indeterminate UID references,
  protection of anonymized public attribution, and post-promotion checks.
  Auth absence is a fail-closed condition, not proof of why the account is
  absent. No deleted-UID ledger or restore automation was added.
- `moderation_private_audit` and `moderation_private_queue_audit` may retain
  identifiers after account deletion. Their retention period and Cloud
  Logging retention are not established in this repository. A future,
  approved time-limited audit policy is the target; this closeout does not
  set a duration, add TTL, delete audit records, or anonymize audit UIDs.

## Release evidence and manual follow-up

There is no current release-candidate manifest in this repository. The
release-manifest template remains a template, and the v1.0.0+17 audit
baseline remains historical. The next candidate manifest should cite this
closeout for the account-deletion E2E rather than replacing `TBD` in the
template with this single test result.

Before publishing the updated Hosting documents, manually compare the Play
Data Safety answers with the implemented account deletion and the published
Privacy wording. Confirm the following without assuming the existing answers:

- account deletion support and external deletion URL;
- retained public user-generated content and anonymized attribution;
- audit/security records that can remain after deletion;
- PITR, scheduled backup, and Storage soft-delete copies, without an
  immediate-complete-erasure claim;
- temporary photos, feedback, location, authentication, and other
  user-generated content categories.

The Hosting Privacy and delete-account text in this source update is not yet
live. Play Console, Firebase configuration, Cloud configuration, runtime
Functions, audit TTL, and Production data were not changed in this phase.
