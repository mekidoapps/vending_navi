const MAX_TEMP_PHOTO_BYTES = 5 * 1024 * 1024;
const MAX_TEMP_PHOTO_AGE_MS = 24 * 60 * 60 * 1000;
const JPEG_CONTENT_TYPE = "image/jpeg";

export interface TemporaryPhotoObjectMetadata {
  readonly objectPath: string;
  readonly contentType: string | null | undefined;
  readonly size: string | number | null | undefined;
  readonly timeCreated: string | Date | null | undefined;
}

export interface VerifiedTemporaryPhoto {
  readonly objectPath: string;
  readonly sizeBytes: number;
  readonly createdAt: Date;
}

export type TemporaryPhotoValidationCode =
  | "temporary-photo-path-invalid"
  | "temporary-photo-content-type-invalid"
  | "temporary-photo-size-invalid"
  | "temporary-photo-too-large"
  | "temporary-photo-created-at-invalid"
  | "temporary-photo-expired";

export class TemporaryPhotoValidationError extends Error {
  constructor(
    readonly code: TemporaryPhotoValidationCode,
    message: string,
  ) {
    super(message);
    this.name = "TemporaryPhotoValidationError";
  }
}

export function buildTemporaryPhotoObjectPath(
  uid: string,
  uploadId: string,
): string {
  const normalizedUid = uid.trim();
  const normalizedUploadId = uploadId.trim().toLowerCase();

  if (
    normalizedUid.length === 0 ||
    normalizedUid.includes("/") ||
    normalizedUid.includes("\\")
  ) {
    throw new TemporaryPhotoValidationError(
      "temporary-photo-path-invalid",
      "Temporary photo uid is invalid.",
    );
  }

  if (
    normalizedUploadId.length === 0 ||
    normalizedUploadId.includes("/") ||
    normalizedUploadId.includes("\\")
  ) {
    throw new TemporaryPhotoValidationError(
      "temporary-photo-path-invalid",
      "Temporary photo uploadId is invalid.",
    );
  }

  return `machine_uploads/${normalizedUid}/${normalizedUploadId}/original.jpg`;
}

export function validateTemporaryPhotoMetadata(
  expectedObjectPath: string,
  metadata: TemporaryPhotoObjectMetadata,
  now: Date,
): VerifiedTemporaryPhoto {
  if (metadata.objectPath !== expectedObjectPath) {
    throw new TemporaryPhotoValidationError(
      "temporary-photo-path-invalid",
      "Temporary photo object path does not match the authenticated upload.",
    );
  }

  const contentType = metadata.contentType?.trim().toLowerCase() ?? "";
  if (contentType !== JPEG_CONTENT_TYPE) {
    throw new TemporaryPhotoValidationError(
      "temporary-photo-content-type-invalid",
      "Temporary photo must be image/jpeg.",
    );
  }

  const sizeBytes = parseSizeBytes(metadata.size);
  if (sizeBytes > MAX_TEMP_PHOTO_BYTES) {
    throw new TemporaryPhotoValidationError(
      "temporary-photo-too-large",
      "Temporary photo exceeds 5 MiB.",
    );
  }

  const createdAt = parseCreatedAt(metadata.timeCreated);
  const nowMs = now.getTime();
  if (!Number.isFinite(nowMs)) {
    throw new TemporaryPhotoValidationError(
      "temporary-photo-created-at-invalid",
      "Validation clock is invalid.",
    );
  }

  const ageMs = nowMs - createdAt.getTime();
  if (ageMs < 0) {
    throw new TemporaryPhotoValidationError(
      "temporary-photo-created-at-invalid",
      "Temporary photo creation time is in the future.",
    );
  }

  if (ageMs > MAX_TEMP_PHOTO_AGE_MS) {
    throw new TemporaryPhotoValidationError(
      "temporary-photo-expired",
      "Temporary photo is older than 24 hours.",
    );
  }

  return {
    objectPath: expectedObjectPath,
    sizeBytes,
    createdAt,
  };
}

function parseSizeBytes(
  value: string | number | null | undefined,
): number {
  const numericValue =
    typeof value === "number" ?
      value :
      typeof value === "string" && value.trim().length > 0 ?
        Number(value.trim()) :
        Number.NaN;

  if (
    !Number.isSafeInteger(numericValue) ||
    numericValue <= 0
  ) {
    throw new TemporaryPhotoValidationError(
      "temporary-photo-size-invalid",
      "Temporary photo size metadata is invalid.",
    );
  }

  return numericValue;
}

function parseCreatedAt(
  value: string | Date | null | undefined,
): Date {
  const parsed =
    value instanceof Date ?
      new Date(value.getTime()) :
      typeof value === "string" && value.trim().length > 0 ?
        new Date(value) :
        new Date(Number.NaN);

  if (!Number.isFinite(parsed.getTime())) {
    throw new TemporaryPhotoValidationError(
      "temporary-photo-created-at-invalid",
      "Temporary photo creation metadata is invalid.",
    );
  }

  return parsed;
}

export const TEMPORARY_PHOTO_LIMITS = Object.freeze({
  contentType: JPEG_CONTENT_TYPE,
  maxBytes: MAX_TEMP_PHOTO_BYTES,
  maxAgeMs: MAX_TEMP_PHOTO_AGE_MS,
});
