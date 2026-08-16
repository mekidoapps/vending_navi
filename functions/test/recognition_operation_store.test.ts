import {strict as assert} from "node:assert";
import {test} from "node:test";

import {
  buildRecognitionOperationId,
  buildRecognitionSessionId,
  parseStoredRecognitionResult,
} from "../src/photo_recognition/recognition_operation_store";

test("recognition operation ID is deterministic and request-scoped", () => {
  const a = buildRecognitionOperationId(
    "user-1",
    "550e8400-e29b-41d4-a716-446655440000",
  );
  const b = buildRecognitionOperationId(
    "user-1",
    "550e8400-e29b-41d4-a716-446655440000",
  );
  const c = buildRecognitionOperationId(
    "user-1",
    "123e4567-e89b-42d3-a456-426614174000",
  );

  assert.equal(a, b);
  assert.notEqual(a, c);
  assert.match(a, /^[0-9a-f]{64}$/);
});

test("recognition session ID is deterministic per uid and upload", () => {
  const a = buildRecognitionSessionId(
    "user-1",
    "123e4567-e89b-42d3-a456-426614174000",
  );
  const b = buildRecognitionSessionId(
    "user-1",
    "123e4567-e89b-42d3-a456-426614174000",
  );
  const c = buildRecognitionSessionId(
    "user-2",
    "123e4567-e89b-42d3-a456-426614174000",
  );

  assert.equal(a, b);
  assert.notEqual(a, c);
});

test("stored recognition result is safely parsed for replay", () => {
  assert.deepEqual(
    parseStoredRecognitionResult({
      providerKey: "vertex_gemini_3_5_flash_lite",
      response: {
        manufacturerCandidates: [
          {manufacturerId: "asahi"},
        ],
        productCandidates: [
          {productId: "otsuka_pocari_sweat"},
        ],
        unresolvedLabels: ["WILKINSON LEMON"],
        recognitionStatus: "completed",
      },
    }),
    {
      providerKey: "vertex_gemini_3_5_flash_lite",
      response: {
        manufacturerCandidates: [
          {manufacturerId: "asahi"},
        ],
        productCandidates: [
          {productId: "otsuka_pocari_sweat"},
        ],
        unresolvedLabels: ["WILKINSON LEMON"],
        recognitionStatus: "completed",
      },
    },
  );
});

test("stored recognition result safely parses exact photo binding", () => {
  const contentSha256 = "a".repeat(64);

  const result = parseStoredRecognitionResult({
    providerKey: "vertex_gemini_3_5_flash_lite",
    response: {
      manufacturerCandidates: [],
      productCandidates: [],
      unresolvedLabels: [],
      recognitionStatus: "completed",
    },
    photoBinding: {
      objectPath:
        "machine_uploads/user-1/123e4567-e89b-42d3-a456-426614174000/original.jpg",
      contentSha256,
      sizeBytes: 1234,
    },
  });

  assert.deepEqual(result.photoBinding, {
    objectPath:
      "machine_uploads/user-1/123e4567-e89b-42d3-a456-426614174000/original.jpg",
    contentSha256,
    sizeBytes: 1234,
  });
});
