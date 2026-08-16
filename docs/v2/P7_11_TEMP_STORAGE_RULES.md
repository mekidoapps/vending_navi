# P7-11 Temporary Storage Rules

## Scope

Only the Phase 7 temporary photo path is opened:

```text
machine_uploads/{uid}/{uploadId}/original.jpg
```

Formal photo paths remain denied.

## Client temporary-photo permissions

Create is allowed only when all conditions are true:

- authenticated
- path uid equals `request.auth.uid`
- uploadId is UUID v4
- exact filename is `original.jpg`
- content type is exactly `image/jpeg`
- size is greater than 0
- size is at most 5 MiB

Read is owner-only.

Update/overwrite is denied.

Delete is denied. Temporary-photo lifecycle cleanup stays server-side through
Admin SDK. A retake uses a new uploadId.

## Automated rule test

The isolated test package lives under:

```text
tools/p7_storage_rules_test
```

It uses Firebase's official `@firebase/rules-unit-testing` package against the
Storage Emulator. It verifies positive and negative cases without touching
production Storage.

## P7-11 does not open

- formal vending-machine image reads
- formal vending-machine image writes
- arbitrary machine_uploads paths
- client-side delete/update
