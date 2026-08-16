import {strict as assert} from "node:assert";
import {test} from "node:test";

import {
  RecognitionRequestValidationError,
  parseRecognitionRequest,
} from "../src/photo_recognition/recognition_contract";

const REQUEST_ID = "550e8400-e29b-41d4-a716-446655440000";
const UPLOAD_ID = "123e4567-e89b-42d3-a456-426614174000";

test("recognition request accepts UUID v4 request and upload IDs", () => {
  assert.deepEqual(
    parseRecognitionRequest({
      recognitionRequestId: REQUEST_ID.toUpperCase(),
      uploadId: ` ${UPLOAD_ID} `,
    }),
    {
      recognitionRequestId: REQUEST_ID,
      uploadId: UPLOAD_ID,
    },
  );
});

test("recognition request rejects unknown fields", () => {
  assert.throws(
    () =>
      parseRecognitionRequest({
        recognitionRequestId: REQUEST_ID,
        uploadId: UPLOAD_ID,
        provider: "client-must-not-select-provider",
      }),
    RecognitionRequestValidationError,
  );
});

test("recognition request rejects non-v4 request IDs", () => {
  assert.throws(
    () =>
      parseRecognitionRequest({
        recognitionRequestId: "550e8400-e29b-11d4-a716-446655440000",
        uploadId: UPLOAD_ID,
      }),
    RecognitionRequestValidationError,
  );
});

test("recognition request rejects malformed upload IDs", () => {
  assert.throws(
    () =>
      parseRecognitionRequest({
        recognitionRequestId: REQUEST_ID,
        uploadId: "upload-123",
      }),
    RecognitionRequestValidationError,
  );
});
