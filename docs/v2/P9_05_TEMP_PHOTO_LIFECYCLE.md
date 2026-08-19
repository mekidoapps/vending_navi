# P9-05 Temporary Photo Lifecycle

## Current successful-finalization cleanup

Temporary photo objects are already deleted on a best-effort basis after:

- successful photo-based vending-machine creation
- successful photo publication to an existing vending machine

Cleanup failure must not fail an otherwise successful public mutation.

## Product-update exception

updateVendingMachineProducts must not delete the temporary photo.

The same temporary upload may still be required by the subsequent
addVendingMachinePhoto operation.

## Expiration

Temporary photos are valid for at most 24 hours.

Functions already reject temporary photos older than 24 hours.

Therefore a delayed physical deletion does not extend application-level
validity.

## Orphan cleanup

Uploads may remain when:

- the user abandons the flow
- recognition or finalization fails
- best-effort deletion fails

Cloud Storage Object Lifecycle Management is used for this orphan cleanup.

Lifecycle rule:

- prefix: machine_uploads/
- age: 1 day
- action: Delete

Formal vending-machine photos under vending_machines/ are outside the prefix
and must never be deleted by this lifecycle rule.

## Deployment

The lifecycle configuration is stored in:

firebase/v2/storage.lifecycle.json

It is not applied automatically by Firebase deploy.

Production application requires an explicit bucket metadata update after the
configuration has been reviewed.

Application command:

gcloud storage buckets update \
  gs://vendingnavi.firebasestorage.app \
  --lifecycle-file=firebase/v2/storage.lifecycle.json

Do not execute this command during repository-only verification.
