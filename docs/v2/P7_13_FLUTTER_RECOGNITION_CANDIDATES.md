# P7-13 Flutter Recognition + Candidate Confirmation

P7-13 connects the P7-12 temporary upload to the existing
`recognizeVendingMachinePhoto` Callable.

```text
temporaryPhotoUploadId
→ recognitionRequestId UUID v4
→ recognizeVendingMachinePhoto
→ normalized Master IDs
→ active Product / Manufacturer Master load
→ candidate confirmation UI
```

AI output remains candidate-only. It is kept in a separate recognition
controller and does not directly mutate `MachineRegistrationDraft`.

Only after the user taps `この内容を保存` are the user's selections copied into
`draft.manufacturerId` and `draft.confirmedProductIds`.

The machine-level manufacturer is displayed as `自販機ブランド`. Product
manufacturers remain independent, so mixed-brand vending machines are valid.

Failure routes offer reanalysis, retake, manufacturer quick registration, or
location-only registration.

P7-13 intentionally does not call `createVendingMachine` for photo registration.
P7-14 will add server-side session/hash verification, evidence classification,
formal photo finalization, and final create.
