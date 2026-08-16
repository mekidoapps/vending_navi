import {strict as assert} from "node:assert";
import {test} from "node:test";

import type {
  StorageDownloadBucketLike,
  StorageDownloadFileLike,
} from "../src/photo_recognition/temporary_photo_content_adapter";
import {
  TemporaryPhotoContentError,
  readValidatedTemporaryPhotoContent,
} from "../src/photo_recognition/temporary_photo_content_adapter";
import type {
  StorageObjectMetadataLike,
} from "../src/photo_recognition/temporary_photo_storage_adapter";

const UID = "user-123";
const UPLOAD_ID = "123e4567-e89b-42d3-a456-426614174000";
const PATH = `machine_uploads/${UID}/${UPLOAD_ID}/original.jpg`;
const NOW = new Date("2026-08-12T12:00:00.000Z");

class FakeDownloadFile implements StorageDownloadFileLike {
  constructor(
    private readonly metadata: StorageObjectMetadataLike,
    private readonly content: Buffer | Error,
  ) {}

  async getMetadata():
    Promise<readonly [StorageObjectMetadataLike, ...unknown[]]> {
    return [this.metadata];
  }

  async download(): Promise<readonly [Buffer, ...unknown[]]> {
    if (this.content instanceof Error) {
      throw this.content;
    }
    return [this.content];
  }
}

class FakeDownloadBucket implements StorageDownloadBucketLike {
  readonly requestedPaths: string[] = [];

  constructor(private readonly fileValue: FakeDownloadFile) {}

  file(objectPath: string): StorageDownloadFileLike {
    this.requestedPaths.push(objectPath);
    return this.fileValue;
  }
}

function validMetadata(size: number): StorageObjectMetadataLike {
  return {
    name: PATH,
    contentType: "image/jpeg",
    size: String(size),
    timeCreated: "2026-08-12T11:00:00.000Z",
  };
}

test("validated JPEG bytes are returned for provider input", async () => {
  const bytes = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);
  const bucket = new FakeDownloadBucket(
    new FakeDownloadFile(validMetadata(bytes.length), bytes),
  );

  const result = await readValidatedTemporaryPhotoContent(
    bucket,
    UID,
    UPLOAD_ID,
    NOW,
  );

  assert.equal(result.objectPath, PATH);
  assert.equal(result.contentType, "image/jpeg");
  assert.deepEqual(result.bytes, bytes);
  assert.deepEqual(bucket.requestedPaths, [PATH, PATH]);
});

test("download error is converted without leaking provider details", async () => {
  const bucket = new FakeDownloadBucket(
    new FakeDownloadFile(
      validMetadata(4),
      new Error("private storage detail"),
    ),
  );

  await assert.rejects(
    () =>
      readValidatedTemporaryPhotoContent(
        bucket,
        UID,
        UPLOAD_ID,
        NOW,
      ),
    (error: unknown) => {
      assert.ok(error instanceof TemporaryPhotoContentError);
      assert.equal(error.code, "temporary-photo-download-failed");
      assert.equal(
        error.message.includes("private storage detail"),
        false,
      );
      return true;
    },
  );
});

test("empty download is rejected", async () => {
  const bucket = new FakeDownloadBucket(
    new FakeDownloadFile(validMetadata(1), Buffer.alloc(0)),
  );

  await assert.rejects(
    () =>
      readValidatedTemporaryPhotoContent(
        bucket,
        UID,
        UPLOAD_ID,
        NOW,
      ),
    (error: unknown) => {
      assert.ok(error instanceof TemporaryPhotoContentError);
      assert.equal(error.code, "temporary-photo-content-empty");
      return true;
    },
  );
});

test("download size mismatch is rejected", async () => {
  const bucket = new FakeDownloadBucket(
    new FakeDownloadFile(
      validMetadata(4),
      Buffer.from([0xff, 0xd8, 0xff]),
    ),
  );

  await assert.rejects(
    () =>
      readValidatedTemporaryPhotoContent(
        bucket,
        UID,
        UPLOAD_ID,
        NOW,
      ),
    (error: unknown) => {
      assert.ok(error instanceof TemporaryPhotoContentError);
      assert.equal(
        error.code,
        "temporary-photo-content-size-mismatch",
      );
      return true;
    },
  );
});
