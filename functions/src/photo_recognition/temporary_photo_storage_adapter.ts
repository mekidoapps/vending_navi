import {
  buildTemporaryPhotoObjectPath,
  validateTemporaryPhotoMetadata,
} from "./temporary_photo_validation";
import type {
  VerifiedTemporaryPhoto,
} from "./temporary_photo_validation";

export interface StorageObjectMetadataLike {
  readonly name?: string;
  readonly contentType?: string | null;
  readonly size?: string | number | null;
  readonly timeCreated?: string | Date | null;
}

export interface StorageFileLike {
  getMetadata(): Promise<readonly [StorageObjectMetadataLike, ...unknown[]]>;
}

export interface StorageBucketLike {
  file(objectPath: string): StorageFileLike;
}

export type TemporaryPhotoStorageErrorCode =
  | "temporary-photo-not-found"
  | "temporary-photo-storage-read-failed";

export class TemporaryPhotoStorageError extends Error {
  constructor(
    readonly code: TemporaryPhotoStorageErrorCode,
    message: string,
  ) {
    super(message);
    this.name = "TemporaryPhotoStorageError";
  }
}

export async function readAndValidateTemporaryPhotoMetadata(
  bucket: StorageBucketLike,
  uid: string,
  uploadId: string,
  now: Date,
): Promise<VerifiedTemporaryPhoto> {
  const expectedObjectPath = buildTemporaryPhotoObjectPath(uid, uploadId);
  const file = bucket.file(expectedObjectPath);

  let metadata: StorageObjectMetadataLike;
  try {
    const response = await file.getMetadata();
    metadata = response[0];
  } catch (error: unknown) {
    if (isNotFoundStorageError(error)) {
      throw new TemporaryPhotoStorageError(
        "temporary-photo-not-found",
        "Temporary photo object does not exist.",
      );
    }

    throw new TemporaryPhotoStorageError(
      "temporary-photo-storage-read-failed",
      "Temporary photo metadata could not be read.",
    );
  }

  const metadataObjectPath =
    typeof metadata.name === "string" && metadata.name.trim().length > 0 ?
      metadata.name.trim() :
      expectedObjectPath;

  return validateTemporaryPhotoMetadata(
    expectedObjectPath,
    {
      objectPath: metadataObjectPath,
      contentType: metadata.contentType,
      size: metadata.size,
      timeCreated: metadata.timeCreated,
    },
    now,
  );
}

function isNotFoundStorageError(error: unknown): boolean {
  if (typeof error !== "object" || error === null) {
    return false;
  }

  const candidate = error as {
    readonly code?: unknown;
    readonly statusCode?: unknown;
  };

  return candidate.code === 404 || candidate.statusCode === 404;
}
