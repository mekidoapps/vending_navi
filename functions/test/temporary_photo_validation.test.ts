import {strict as assert} from "node:assert";
import {test} from "node:test";

import {
  TEMPORARY_PHOTO_LIMITS,
  TemporaryPhotoValidationError,
  buildTemporaryPhotoObjectPath,
  validateTemporaryPhotoMetadata,
} from "../src/photo_recognition/temporary_photo_validation";

const UID = "user-123";
const UPLOAD_ID = "123e4567-e89b-42d3-a456-426614174000";
const PATH = `machine_uploads/${UID}/${UPLOAD_ID}/original.jpg`;
const NOW = new Date("2026-08-12T12:00:00.000Z");

test("temporary photo path is derived from authenticated uid and uploadId", () => {
  assert.equal(
    buildTemporaryPhotoObjectPath(UID, UPLOAD_ID.toUpperCase()),
    PATH,
  );
});

test("temporary photo path rejects path injection", () => {
  assert.throws(
    () => buildTemporaryPhotoObjectPath("../other-user", UPLOAD_ID),
    TemporaryPhotoValidationError,
  );
  assert.throws(
    () => buildTemporaryPhotoObjectPath(UID, "../other-upload"),
    TemporaryPhotoValidationError,
  );
});

test("valid JPEG metadata at exactly 5 MiB is accepted", () => {
  const result = validateTemporaryPhotoMetadata(
    PATH,
    {
      objectPath: PATH,
      contentType: "image/jpeg",
      size: String(TEMPORARY_PHOTO_LIMITS.maxBytes),
      timeCreated: "2026-08-11T12:00:00.000Z",
    },
    NOW,
  );

  assert.equal(result.objectPath, PATH);
  assert.equal(result.sizeBytes, 5 * 1024 * 1024);
  assert.equal(
    result.createdAt.toISOString(),
    "2026-08-11T12:00:00.000Z",
  );
});

test("wrong object path is rejected", () => {
  assert.throws(
    () =>
      validateTemporaryPhotoMetadata(
        PATH,
        {
          objectPath:
            `machine_uploads/other-user/${UPLOAD_ID}/original.jpg`,
          contentType: "image/jpeg",
          size: 1024,
          timeCreated: NOW,
        },
        NOW,
      ),
    (error: unknown) => {
      assert.ok(error instanceof TemporaryPhotoValidationError);
      assert.equal(error.code, "temporary-photo-path-invalid");
      return true;
    },
  );
});

test("non-JPEG content type is rejected", () => {
  assert.throws(
    () =>
      validateTemporaryPhotoMetadata(
        PATH,
        {
          objectPath: PATH,
          contentType: "image/png",
          size: 1024,
          timeCreated: NOW,
        },
        NOW,
      ),
    (error: unknown) => {
      assert.ok(error instanceof TemporaryPhotoValidationError);
      assert.equal(
        error.code,
        "temporary-photo-content-type-invalid",
      );
      return true;
    },
  );
});

test("photo larger than 5 MiB is rejected", () => {
  assert.throws(
    () =>
      validateTemporaryPhotoMetadata(
        PATH,
        {
          objectPath: PATH,
          contentType: "image/jpeg",
          size: TEMPORARY_PHOTO_LIMITS.maxBytes + 1,
          timeCreated: NOW,
        },
        NOW,
      ),
    (error: unknown) => {
      assert.ok(error instanceof TemporaryPhotoValidationError);
      assert.equal(error.code, "temporary-photo-too-large");
      return true;
    },
  );
});

test("zero, negative, fractional and malformed sizes are rejected", () => {
  for (const size of [0, -1, 10.5, "", "abc"]) {
    assert.throws(
      () =>
        validateTemporaryPhotoMetadata(
          PATH,
          {
            objectPath: PATH,
            contentType: "image/jpeg",
            size,
            timeCreated: NOW,
          },
          NOW,
        ),
      TemporaryPhotoValidationError,
    );
  }
});

test("photo exactly 24 hours old remains valid", () => {
  assert.doesNotThrow(() =>
    validateTemporaryPhotoMetadata(
      PATH,
      {
        objectPath: PATH,
        contentType: "image/jpeg",
        size: 1024,
        timeCreated: "2026-08-11T12:00:00.000Z",
      },
      NOW,
    ),
  );
});

test("photo older than 24 hours is rejected", () => {
  assert.throws(
    () =>
      validateTemporaryPhotoMetadata(
        PATH,
        {
          objectPath: PATH,
          contentType: "image/jpeg",
          size: 1024,
          timeCreated: "2026-08-11T11:59:59.999Z",
        },
        NOW,
      ),
    (error: unknown) => {
      assert.ok(error instanceof TemporaryPhotoValidationError);
      assert.equal(error.code, "temporary-photo-expired");
      return true;
    },
  );
});

test("future or malformed creation time is rejected", () => {
  for (const timeCreated of [
    "2026-08-12T12:00:00.001Z",
    "not-a-date",
    "",
  ]) {
    assert.throws(
      () =>
        validateTemporaryPhotoMetadata(
          PATH,
          {
            objectPath: PATH,
            contentType: "image/jpeg",
            size: 1024,
            timeCreated,
          },
          NOW,
        ),
      TemporaryPhotoValidationError,
    );
  }
});
