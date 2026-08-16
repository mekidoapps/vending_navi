import type {
  StorageBucketLike,
  StorageFileLike,
} from "./temporary_photo_storage_adapter";
import {
  readAndValidateTemporaryPhotoMetadata,
} from "./temporary_photo_storage_adapter";
import {
  TEMPORARY_PHOTO_LIMITS,
} from "./temporary_photo_validation";

export interface StorageDownloadFileLike extends StorageFileLike {
  download(): Promise<readonly [Buffer, ...unknown[]]>;
}

export interface StorageDownloadBucketLike extends StorageBucketLike {
  file(objectPath: string): StorageDownloadFileLike;
}

export interface TemporaryPhotoContent {
  readonly objectPath: string;
  readonly contentType: "image/jpeg";
  readonly bytes: Buffer;
}

export type TemporaryPhotoContentErrorCode =
  | "temporary-photo-download-failed"
  | "temporary-photo-content-empty"
  | "temporary-photo-content-size-mismatch";

export class TemporaryPhotoContentError extends Error {
  constructor(
    readonly code: TemporaryPhotoContentErrorCode,
    message: string,
  ) {
    super(message);
    this.name = "TemporaryPhotoContentError";
  }
}

export async function readValidatedTemporaryPhotoContent(
  bucket: StorageDownloadBucketLike,
  uid: string,
  uploadId: string,
  now: Date,
): Promise<TemporaryPhotoContent> {
  const verified = await readAndValidateTemporaryPhotoMetadata(
    bucket,
    uid,
    uploadId,
    now,
  );

  let bytes: Buffer;
  try {
    const response = await bucket.file(verified.objectPath).download();
    bytes = response[0];
  } catch {
    throw new TemporaryPhotoContentError(
      "temporary-photo-download-failed",
      "Temporary photo content could not be read.",
    );
  }

  if (bytes.length === 0) {
    throw new TemporaryPhotoContentError(
      "temporary-photo-content-empty",
      "Temporary photo content is empty.",
    );
  }

  if (
    bytes.length !== verified.sizeBytes ||
    bytes.length > TEMPORARY_PHOTO_LIMITS.maxBytes
  ) {
    throw new TemporaryPhotoContentError(
      "temporary-photo-content-size-mismatch",
      "Temporary photo content size does not match validated metadata.",
    );
  }

  return {
    objectPath: verified.objectPath,
    contentType: "image/jpeg",
    bytes,
  };
}
