# P7-11 Temporary Storage Immutability Hotfix

## Reason

The first P7-11 Rules test showed that `allow create` did not enforce
immutability for Cloud Storage in the exercised emulator behavior.

Cloud Storage Rules exposes the existing object as `resource`. To make the
temporary object immutable, the rule now uses the Cloud Storage write rule and
requires:

```text
resource == null
```

Therefore:

- first upload: existing resource is null -> eligible
- overwrite/update: existing resource is present -> denied
- delete: existing resource is present -> denied

All existing owner / UUID / JPEG / size conditions remain unchanged.
