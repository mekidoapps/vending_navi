# P7-14 Photo Registration Finalization

## Goal

Connect the user-confirmed P7-13 photo draft to formal vending-machine creation.

## Final flow

```text
confirmed photo draft
→ createVendingMachine
→ recognition session lookup by uid + uploadId
→ completed / TTL validation
→ temporary JPEG re-read
→ exact path / size / SHA-256 binding verification
→ active Manufacturer / Product Master validation
→ evidence classification
→ formal Storage save
→ vending machine + products + photo + revision + index transaction
→ requestId dedupe completed
→ temporary photo best-effort delete
```

## Evidence

For photo registration only:

- recognized by AI and kept by user: `photo_confirmed`
- user-added Product ID: `manual_confirmed`
- manufacturer preset inference is **not** added on the photo route

Machine body brand is independent from Product manufacturers.

`manufacturerStatus`:

- selected machine brand exists in recognition candidate IDs:
  `recognized_and_confirmed`
- user selected/changed a machine brand not in candidates:
  `confirmed`
- no machine brand selected:
  `unknown`

## Exact-image binding

Formal creation re-reads the temporary JPEG and recomputes the same SHA-256
binding created during recognition. Registration is rejected if object path,
byte count, or SHA-256 differs.

## Storage

Temporary:

```text
machine_uploads/{uid}/{uploadId}/original.jpg
```

Formal:

```text
vending_machines/{machineId}/{photoId}/original.jpg
```

No download URL is stored.

The recognition session is transactionally marked with its finalized machine,
photo, and request IDs. A different request cannot reuse the same recognized
photo for another machine.

Formal machine ID is deterministic from `uid + requestId`. Formal `photoId`
also includes `uploadId`, so even a malformed concurrent replay that reuses the
same request ID with a different temporary photo cannot overwrite the winning
formal photo object. This allows safe retries to reuse the same formal object and
document IDs if a process is interrupted after the Storage save but before the
Firestore transaction completes.

## Firestore photo document

```text
vending_machines/{machineId}/photos/{photoId}
```

Fields:

- storagePath
- thumbnailPath = null
- status = active
- uploadedBy
- uploadedAt
- recognitionStatus = completed
- recognitionProvider
- isPrimary = true

The root `primaryPhotoId` is set to the same photoId.

## Retry / cleanup

A completed `requestId` is returned before the temporary photo is required
again, so a successful retry still works after temporary cleanup.

Temporary deletion is best-effort after Firestore commit. Phase 9 remains
responsible for orphan cleanup after interrupted operations.

## Flutter

Photo drafts become submit-ready when they contain:

- requestId
- location
- registrationMethod = photo
- temporaryPhotoUploadId

After the candidate user confirms the selection, the app advances to the
existing final confirmation screen. The existing successful create flow then
refreshes map/search and opens the new machine detail.
