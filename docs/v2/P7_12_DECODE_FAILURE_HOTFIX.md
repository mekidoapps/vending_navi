# P7-12 Decode Failure Hotfix

## Cause

`package:image` may throw while probing malformed/too-short bytes before
`decodeImage()` can return `null`.

The P7-12 normalizer originally handled only a `null` decode result, so malformed
input such as four arbitrary bytes leaked a `RangeError`.

## Fix

Wrap only the `img.decodeImage(sourceBytes)` call and convert any decoder
exception to the existing safe domain error:

```text
RegistrationPhotoException
code = decodeFailed
```

This keeps malformed camera/image bytes inside the photo flow instead of leaking
package-specific exceptions to the controller/UI.
