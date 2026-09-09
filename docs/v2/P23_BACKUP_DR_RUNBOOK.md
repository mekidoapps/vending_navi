# Phase 23: Production Backup / Disaster Recovery Runbook

## Scope and recovery principle

This runbook covers the Firebase project `vendingnavi`. It is a recovery
guide, not authorization to change Production. Do not restore a backup
directly into the Production database. Restore first to an isolated/new
database, verify it, prepare a reviewed recovery plan, and then perform only
the approved limited recovery.

## Confirmed Production protection

### Firestore

- Point-in-Time Recovery (PITR): enabled, 7-day retention.
- Scheduled backup: daily.
- Scheduled-backup retention: 98 days.
- First scheduled backup: generated successfully at 2026-09-09 03:55:25 JST;
  expiry is 2026-12-16 03:55:25 JST.
- An isolated restore drill completed successfully in
  `restore-drill-20260909` (`asia-northeast1`) without overwriting the
  Production `(default)` database. Read-only verification covered core
  machine, index, master, user, private, feedback, operational, recognition,
  and request-deduplication data.

### Cloud Storage

- Bucket: `vendingnavi.firebasestorage.app`.
- Soft delete: enabled, 7-day retention.
- Object Versioning: off.
- Bucket retention policy: none.
- `machine_uploads/` objects are deleted by lifecycle after 7 days.
- Formal photos under `vending_machines/` are not lifecycle deletion targets.

## Recovery evidence

Before a recovery, record the incident time, affected paths/counts, selected
PITR timestamp or backup generation, operator, and the Git SHA of deployed
Functions. Keep sensitive exports and recovery evidence outside the repository.

After an isolated restore, compare document counts and these relationships
before proposing a limited Production recovery:

- `vending_machines/{machineId}` and its `products/{productId}` documents;
- `machine_product_index` entries for the affected machines/products;
- `vending_machine_private` metadata and formal-photo public/private pairs;
- reports, corrections, and moderation/audit records where relevant.

## Scenario playbooks

### A. One vending machine is accidentally lost

1. Preserve the incident timestamp and affected machine ID.
2. Restore the selected Firestore point or backup to an isolated database.
3. Compare the machine, product relations, private metadata, photo metadata,
   and index entries with Production.
4. Review a limited restoration plan; do not bulk import the database.

### B. Bulk Firestore bad write or delete

1. Stop the source of writes and record the earliest safe timestamp.
2. Restore PITR/backup into an isolated database.
3. Compare root counts, relations, indexes, and moderation records.
4. Approve a narrow recovery plan before any Production write.

### C. `machine_product_index` corruption

The authoritative relation is:

```text
vending_machines/{machineId}/products/{productId}
```

`machine_product_index` is derived search data. There is no approved
Production rebuild mutation tool in this repository. Do not repurpose emulator
fixtures or run an ad-hoc bulk write. A future approved rebuild must:

1. read active machine/product relations from a verified snapshot;
2. derive each index entry using the same Functions schema and active-status
   rules;
3. dry-run counts and sample entries in an isolated environment;
4. use bounded, idempotent writes with rollback evidence; and
5. verify search/index consistency after completion.

### D. Formal photo is accidentally deleted

1. Confirm the exact formal path:
   `vending_machines/{machineId}/{photoId}/original.jpg`.
2. Within the 7-day soft-delete window, restore the object in Cloud Storage.
3. Verify the matching active Firestore photo metadata; do not expose private
   metadata or alter lifecycle scope.

### E. Bad Functions deploy

1. Identify the last known-good Git SHA and deployed Functions revision.
2. Re-deploy that known-good source through the approved release procedure.
3. Verify runtime configuration and secret bindings without placing secret
   values in Git.

### F. Account deletion incident

Account deletion intentionally removes private user data before Firebase Auth
and preserves public community contributions. Do not automatically resurrect an
account. Preserve incident evidence, use an isolated Firestore restore to assess
the affected private data, and require explicit owner/security review before any
limited recovery.

## Functions recovery

Functions source is recovered from a known-good Git SHA. Runtime configuration,
service account bindings, and Secret Manager values are Console-managed and
must be verified separately. Secret values must never be stored in this
repository or recovery logs.

## Release gate

Before Production release, retain evidence of the daily backup and isolated
restore drill. Any missing PITR/backup/soft-delete protection, or an
unreviewed restore plan, is a release blocker.
