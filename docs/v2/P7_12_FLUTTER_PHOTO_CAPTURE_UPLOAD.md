# P7-12 Flutter Photo Capture + Temporary Upload

## Scope

P7-12 adds the Android-first client path:

```text
registration method
→ photo guide
→ image_picker camera
→ app-side normalization
→ temporary Firebase Storage upload
→ MachineRegistrationDraft.temporaryPhotoUploadId
→ return to method screen
```

AI recognition is intentionally not invoked in P7-12. P7-13 will consume the
prepared upload ID and connect the existing `recognizeVendingMachinePhoto`
Callable.

## Normalization contract

The uploaded `original.jpg` is the app-normalized image, not camera raw data.

- decode captured image
- bake EXIF orientation
- max long side 2048 px
- JPEG encode at quality 85
- maximum 5 MiB
- if 2048 px / quality 85 still exceeds 5 MiB, reduce dimensions while
  retaining JPEG quality 85
- rebuild from RGB pixel bytes before JPEG encoding so camera EXIF/GPS metadata
  is not carried into the temporary recognition image

## Storage

Exact client path:

```text
machine_uploads/{uid}/{uploadId}/original.jpg
```

- uploadId is a separate UUID v4
- `contentType = image/jpeg`
- no download URL is generated
- retake creates a new uploadId
- old temporary objects remain server-cleanup responsibility

## Android permission

No explicit CAMERA permission is added in P7-12. The Flutter `image_picker`
package documents Android as requiring no additional setup for its camera
intent path. This avoids adding an unnecessary app-level permission.

## UI

The photo route gives four short instructions:

- full machine in frame
- product names visible
- avoid faces/license plates
- do not enter dangerous/private areas

After successful upload, the route returns to registration method selection.
The draft keeps the prepared uploadId. P7-13 will change the post-upload
navigation to recognition/candidate confirmation.

## New dependency

```yaml
image: ^4.9.1
```

Used only for deterministic decode/orientation/resize/JPEG re-encode.

## Test focus

- UUID v4 generation
- max long side
- no upscaling
- JPEG output
- max-size contract
- safe decode failure

Full existing Flutter test/analyzer gates remain required.
