# Phase C.1 Legacy Public Actor Field Remediation

Date: 2026-09-01

## Status

PASS

Phase C.1 was opened after a production-wide public-field re-audit found
legacy identity-related fields that were outside the original Phase C
migration scope.

The original Phase C migration itself remains valid and is not rolled back.

## Re-audit finding

Publicly readable active vending-machine roots: 42

Affected public vending-machine root documents: 7

Sensitive legacy fields:

- `createdByName`: 7 documents
- `updatedBy`: 7 documents
- `updatedByName`: 7 documents

No identity-related fields were detected in:

- product master documents
- manufacturer master documents
- publicly readable vending-machine product documents
- publicly readable machine-product index documents

## Current v2 write behavior

Current v2 Functions do not write these three legacy fields to public
vending-machine roots.

Current actor identity is stored in server-only/private data such as:

- `vending_machine_private`
- vending-machine revisions

Therefore Phase C.1 is a cleanup of legacy production data rather than
a new public-write schema change.

## Production dry-run

Production dry-run result:

- vending-machine roots: 42
- affected machine roots: 7
- private metadata writes: 7
- public document writes: 7
- public field deletes: 21
- total planned writes: 14
- conflicts: 0
- state: `pre-migration`

Approved plan SHA-256:

`bab5fb3ffe69d1af136e310b3adc85dc725a7839fbe32c3bb7204159c936d9d0`

## Backup

A local pre-migration backup containing the seven affected legacy actor
records was created outside Git.

Backup SHA-256:

`4ccab7c6148fb23a8956b5f7fe3e80aa4fd94367794b0a683fd766ec359e555a`

The backup contains identity-related information and MUST NOT be committed.

## Migration behavior

For each affected vending-machine root:

1. preserve the three legacy fields under server-only
   `vending_machine_private/{machineId}.legacyPublicActorMetadata`;
2. remove `createdByName` from the public root;
3. remove `updatedBy` from the public root;
4. remove `updatedByName` from the public root.

No public vending-machine document is deleted.

No product, search-index, manufacturer, location, status, or business data
is modified.

## Completion gate

Phase C.1 can return Phase C to PASS only after all of the following pass:

- production apply exits 0;
- all 42 active vending-machine roots remain present;
- all three legacy public actor fields are absent;
- private legacy metadata exists for exactly the seven affected machines;
- private values match the pre-migration backup;
- production public-field re-audit finds zero affected documents;
- second migration dry-run reports zero writes and zero conflicts.

## Production apply result

Production migration completed successfully.

- production apply exit: 0
- affected machine roots: 7
- private metadata writes: 7
- public document writes: 7
- public field deletes: 21
- total planned writes: 14
- conflicts: 0

## Independent production postcheck

Verified production state after migration:

- product masters: 96
- manufacturers: 7
- vending-machine roots: 42
- active vending machines: 42
- vending-machine product documents: 32
- active vending-machine products: 31
- machine-product index documents: 32
- active machine-product indexes: 31
- private vending-machine roots: 42

Public identity audit:

- product masters with identity fields: 0
- manufacturers with identity fields: 0
- vending-machine roots with identity fields: 0
- vending-machine products with identity fields: 0
- machine-product indexes with identity fields: 0
- total affected publicly readable documents: 0

Private legacy metadata verification:

- expected metadata documents: 7
- actual metadata documents: 7
- missing: 0
- value mismatches against backup: 0

Postcheck result:

`matchesExpected: true`

## Idempotency

A production dry-run after migration returned:

- state: `post-migration`
- affected machine roots: 0
- `createdByName`: 0
- `updatedBy`: 0
- `updatedByName`: 0
- existing private legacy metadata: 7
- private writes: 0
- public writes: 0
- public field deletes: 0
- planned writes: 0
- conflicts: 0

## Final decision

Phase C.1: PASS

Phase C: PASS

P1-10: RESOLVED

The overall release remains NO-GO until the remaining P0/P1 audit findings
are resolved and independently re-audited.
