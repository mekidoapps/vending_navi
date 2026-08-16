import {strict as assert} from "node:assert";
import {test} from "node:test";

import {
  TemporaryPhotoStorageError,
  readAndValidateTemporaryPhotoMetadata,
} from "../src/photo_recognition/temporary_photo_storage_adapter";
import type {
  StorageBucketLike,
  StorageFileLike,
  StorageObjectMetadataLike,
} from "../src/photo_recognition/temporary_photo_storage_adapter";
import {
  TemporaryPhotoValidationError,
} from "../src/photo_recognition/temporary_photo_validation";

const UID = "user-123";
const UPLOAD_ID = "123e4567-e89b-42d3-a456-426614174000";
const EXPECTED_PATH =
  `machine_uploads/${UID}/${UPLOAD_ID}/original.jpg`;
const NOW = new Date("2026-08-12T12:00:00.000Z");

class FakeFile implements StorageFileLike {
  constructor(
    private readonly result:
      | StorageObjectMetadataLike
      | Error
      | {readonly code: number}
      | {readonly statusCode: number},
  ) {}

  async getMetadata():
    Promise<readonly [StorageObjectMetadataLike, ...unknown[]]> {
    if (this.result instanceof Error) {
      throw this.result;
    }
    if (
      "code" in this.result ||
      "statusCode" in this.result
    ) {
      throw this.result;
    }

    return [this.result];
  }
}

class FakeBucket implements StorageBucketLike {
  readonly requestedPaths: string[] = [];

  constructor(private readonly fileResult: FakeFile) {}

  file(objectPath: string): StorageFileLike {
    this.requestedPaths.push(objectPath);
    return this.fileResult;
  }
}

test("adapter derives owner-scoped object path before reading metadata", async () => {
  const bucket = new FakeBucket(
    new FakeFile({
      name: EXPECTED_PATH,
      contentType: "image/jpeg",
      size: "2048",
      timeCreated: "2026-08-12T11:00:00.000Z",
    }),
  );

  const result = await readAndValidateTemporaryPhotoMetadata(
    bucket,
    UID,
    UPLOAD_ID,
    NOW,
  );

  assert.deepEqual(bucket.requestedPaths, [EXPECTED_PATH]);
  assert.equal(result.objectPath, EXPECTED_PATH);
  assert.equal(result.sizeBytes, 2048);
});

test("metadata name cannot point at another user's object", async () => {
  const bucket = new FakeBucket(
    new FakeFile({
      name:
        `machine_uploads/other-user/${UPLOAD_ID}/original.jpg`,
      contentType: "image/jpeg",
      size: "2048",
      timeCreated: "2026-08-12T11:00:00.000Z",
    }),
  );

  await assert.rejects(
    () =>
      readAndValidateTemporaryPhotoMetadata(
        bucket,
        UID,
        UPLOAD_ID,
        NOW,
      ),
    (error: unknown) => {
      assert.ok(error instanceof TemporaryPhotoValidationError);
      assert.equal(error.code, "temporary-photo-path-invalid");
      return true;
    },
  );
});

test("missing metadata name safely falls back to the requested path", async () => {
  const bucket = new FakeBucket(
    new FakeFile({
      contentType: "image/jpeg",
      size: "2048",
      timeCreated: "2026-08-12T11:00:00.000Z",
    }),
  );

  const result = await readAndValidateTemporaryPhotoMetadata(
    bucket,
    UID,
    UPLOAD_ID,
    NOW,
  );

  assert.equal(result.objectPath, EXPECTED_PATH);
});

test("storage 404 is converted to temporary-photo-not-found", async () => {
  const bucket = new FakeBucket(
    new FakeFile({code: 404}),
  );

  await assert.rejects(
    () =>
      readAndValidateTemporaryPhotoMetadata(
        bucket,
        UID,
        UPLOAD_ID,
        NOW,
      ),
    (error: unknown) => {
      assert.ok(error instanceof TemporaryPhotoStorageError);
      assert.equal(error.code, "temporary-photo-not-found");
      return true;
    },
  );
});

test("generic storage failure is converted to safe read error", async () => {
  const bucket = new FakeBucket(
    new FakeFile(new Error("private provider detail")),
  );

  await assert.rejects(
    () =>
      readAndValidateTemporaryPhotoMetadata(
        bucket,
        UID,
        UPLOAD_ID,
        NOW,
      ),
    (error: unknown) => {
      assert.ok(error instanceof TemporaryPhotoStorageError);
      assert.equal(
        error.code,
        "temporary-photo-storage-read-failed",
      );
      assert.equal(
        error.message.includes("private provider detail"),
        false,
      );
      return true;
    },
  );
});

test("adapter delegates MIME, size and age validation to the core", async () => {
  const bucket = new FakeBucket(
    new FakeFile({
      name: EXPECTED_PATH,
      contentType: "image/png",
      size: "2048",
      timeCreated: "2026-08-12T11:00:00.000Z",
    }),
  );

  await assert.rejects(
    () =>
      readAndValidateTemporaryPhotoMetadata(
        bucket,
        UID,
        UPLOAD_ID,
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
