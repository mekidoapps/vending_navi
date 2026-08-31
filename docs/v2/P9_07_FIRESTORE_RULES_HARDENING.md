# P9-07 Firestore Rules Hardening

## Public machine boundary

Public clients may read only vending machines whose:

status == active

Non-public states such as:

- underReview
- hidden
- removed
- merged

must not be directly readable.

## Public machine-product boundary

A vending-machine product may be read only when:

- the parent vending machine has status == active
- the product has isActive == true

Inactive product history remains server-side data.

## Search index

machine_product_index is public only when:

- isActive == true
- machineStatus == active

Client queries include the same conditions.

## Product and manufacturer master

Master documents remain publicly readable even when isActive == false.

Inactive master documents are required to resolve historical product and
manufacturer references.

isActive == false means:

- not available for new selection
- not available for new search

It does not mean that the master document itself is secret.

## Legacy vending machines

> **Superseded by the 2026-08-31 production audit.** Do not execute the status
> backfill described below. The tracked v1 source does not establish that a
> missing status means `active`, and the command now fails closed. Follow
> `PHASE_B_LEGACY_MIGRATION.md` instead.

Legacy vending-machine documents may not contain status.

Before hardened production Firestore Rules are deployed, a separate
non-destructive migration must add:

status: active

to legacy documents where status is missing.

The migration must:

- never change schemaVersion
- never remove legacy fields
- never overwrite an explicit existing status
- support dry-run
- report candidate and updated counts

Script:

functions/scripts/backfill_legacy_machine_status.ts

Dry-run is the default.

Production apply requires explicit production opt-in and project
confirmation.

## Historical production deployment order (superseded)

1. Build and test the migration script.
2. Run production dry-run.
3. Review candidate count.
4. Apply legacy status backfill.
5. Verify no legacy status candidates remain.
6. Deploy hardened Firestore Rules and indexes.
7. Run post-deploy read/write security verification.

P9-07 repository work does not perform production migration or deployment.
