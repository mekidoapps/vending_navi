# P9-06 Logging Privacy

## Audit result

Phase 9 reviewed server and Flutter logging.

No production Functions log currently contains:

- raw Callable request payloads
- email addresses
- authentication tokens
- App Check tokens
- image bytes
- temporary or formal photo URLs
- correction/report free-form messages
- exact latitude/longitude
- place descriptions
- raw AI responses
- unknown exception messages
- exception stacks

## Functions logging

The six public v2 Callable wrappers use structured failure logging only.

Approved metadata:

- uid
- requestId or recognitionRequestId
- machineId where applicable
- errorName

Known HttpsError instances are returned without additional server logging.

Unknown exceptions expose only a generic client-facing internal error.
Their raw message and stack are not returned to the client.

Validation error messages are allowed because they originate from explicit
application validation classes rather than arbitrary runtime exceptions.

## Flutter logging

LogEvent uses an explicit allow-list.

Approved fields:

- operation
- outcome
- durationMs
- errorCode
- requestId
- appVersion

DebugAppLogger emits these fields only in debug builds.

No raw AppFailure exception, email address, image data, coordinates or
free-form user text is part of LogEvent.

## Regression protection

functions/test/logging_privacy_contract.test.ts prevents new Functions console
logging and sensitive fields from being added without an explicit security
review.

test/core/logging/app_logger_test.dart protects the Flutter safe-log contract.
