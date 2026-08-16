import {createHash} from "node:crypto";

import type {Firestore} from "firebase-admin/firestore";
import {Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {isMasterId} from "../create_vending_machine_core";
import {
  buildRecognitionSessionId,
} from "./recognition_operation_store";
import {
  buildTemporaryPhotoBinding,
} from "./temporary_photo_binding";
import type {
  StorageDownloadBucketLike,
  StorageDownloadFileLike,
  TemporaryPhotoContent,
} from "./temporary_photo_content_adapter";
import {
  readValidatedTemporaryPhotoContent,
} from "./temporary_photo_content_adapter";

export interface FormalPhotoStorageFileLike
extends StorageDownloadFileLike {
  save(
    data: Buffer,
    options?: {
      readonly resumable?: boolean;
      readonly metadata?: {
        readonly contentType?: string;
      };
    },
  ): Promise<unknown>;
  delete(
    options?: {readonly ignoreNotFound?: boolean},
  ): Promise<unknown>;
}

export interface FormalPhotoStorageBucketLike
extends StorageDownloadBucketLike {
  file(objectPath: string): FormalPhotoStorageFileLike;
}

export interface PreparedPhotoRegistration {
  readonly sessionId: string;
  readonly provider: string;
  readonly recognizedManufacturerIds: ReadonlySet<string>;
  readonly recognizedProductIds: ReadonlySet<string>;
  readonly photo: TemporaryPhotoContent;
}

export interface PhotoRegistrationIds {
  readonly machineId: string;
  readonly photoId: string;
}

export async function preparePhotoRegistration(
  firestore: Firestore,
  bucket: FormalPhotoStorageBucketLike,
  uid: string,
  uploadId: string,
  now: Date,
): Promise<PreparedPhotoRegistration> {
  const sessionId = buildRecognitionSessionId(uid, uploadId);
  const sessionSnapshot = await firestore
    .collection("photo_recognition_sessions")
    .doc(sessionId)
    .get();

  if (!sessionSnapshot.exists) {
    throw new HttpsError(
      "failed-precondition",
      "Photo recognition must be completed before registration.",
      {appCode: "recognition-session-not-found"},
    );
  }

  const data = sessionSnapshot.data();
  if (data === undefined) {
    throw new HttpsError(
      "failed-precondition",
      "Photo recognition session is invalid.",
      {appCode: "recognition-session-invalid"},
    );
  }

  if (
    data.uid !== uid ||
    data.uploadId !== uploadId ||
    data.status !== "completed"
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Photo recognition session does not match this registration.",
      {appCode: "recognition-session-mismatch"},
    );
  }

  const expiresAt = parseTimestamp(data.expiresAt);
  if (expiresAt.getTime() <= now.getTime()) {
    throw new HttpsError(
      "failed-precondition",
      "Photo recognition session has expired.",
      {appCode: "recognition-session-expired"},
    );
  }

  const provider =
    typeof data.provider === "string" ? data.provider.trim() : "";
  if (provider.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "Photo recognition provider is missing.",
      {appCode: "recognition-session-invalid"},
    );
  }

  const recognizedManufacturerIds = parseMasterIdSet(
    data.manufacturerCandidateIds,
    "manufacturerCandidateIds",
  );
  const recognizedProductIds = parseMasterIdSet(
    data.productCandidateIds,
    "productCandidateIds",
  );

  const expectedObjectPath =
    typeof data.photoObjectPath === "string" ?
      data.photoObjectPath.trim() :
      "";
  const expectedHash =
    typeof data.photoContentSha256 === "string" ?
      data.photoContentSha256.trim().toLowerCase() :
      "";
  const expectedSize = data.photoSizeBytes;

  if (
    expectedObjectPath.length === 0 ||
    !/^[0-9a-f]{64}$/.test(expectedHash) ||
    !Number.isSafeInteger(expectedSize) ||
    (expectedSize as number) <= 0
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Photo recognition binding is incomplete.",
      {appCode: "recognition-photo-binding-invalid"},
    );
  }

  let photo: TemporaryPhotoContent;
  try {
    photo = await readValidatedTemporaryPhotoContent(
      bucket,
      uid,
      uploadId,
      now,
    );
  } catch {
    throw new HttpsError(
      "failed-precondition",
      "Temporary photo is unavailable or expired.",
      {appCode: "temporary-photo-unavailable"},
    );
  }

  const actualBinding = buildTemporaryPhotoBinding(photo);
  if (
    actualBinding.objectPath !== expectedObjectPath ||
    actualBinding.contentSha256 !== expectedHash ||
    actualBinding.sizeBytes !== expectedSize
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Temporary photo no longer matches the recognized image.",
      {appCode: "temporary-photo-binding-mismatch"},
    );
  }

  return {
    sessionId,
    provider,
    recognizedManufacturerIds,
    recognizedProductIds,
    photo,
  };
}

export function buildPhotoRegistrationIds(
  uid: string,
  requestId: string,
  uploadId: string,
): PhotoRegistrationIds {
  const normalizedUid = uid.trim();
  const normalizedRequestId = requestId.trim();
  const normalizedUploadId = uploadId.trim();

  if (
    normalizedUid.length === 0 ||
    normalizedRequestId.length === 0 ||
    normalizedUploadId.length === 0
  ) {
    throw new Error("Photo registration identity must not be empty.");
  }

  const requestSeed = `${normalizedUid}|${normalizedRequestId}`;
  const photoSeed = `${requestSeed}|${normalizedUploadId}`;
  return {
    machineId: `p_${sha256(`machine|${requestSeed}`).slice(0, 30)}`,
    photoId: `p_${sha256(`photo|${photoSeed}`).slice(0, 30)}`,
  };
}

export function buildFormalPhotoStoragePath(
  machineId: string,
  photoId: string,
): string {
  return `vending_machines/${machineId}/${photoId}/original.jpg`;
}

export async function saveFormalPhoto(
  bucket: FormalPhotoStorageBucketLike,
  objectPath: string,
  photo: TemporaryPhotoContent,
): Promise<void> {
  try {
    await bucket.file(objectPath).save(
      photo.bytes,
      {
        resumable: false,
        metadata: {contentType: "image/jpeg"},
      },
    );
  } catch {
    throw new HttpsError(
      "internal",
      "The formal vending-machine photo could not be saved.",
      {appCode: "formal-photo-save-failed"},
    );
  }
}

export async function deleteTemporaryPhotoBestEffort(
  bucket: FormalPhotoStorageBucketLike,
  objectPath: string,
): Promise<void> {
  try {
    await bucket.file(objectPath).delete({ignoreNotFound: true});
  } catch {
    // Cleanup is intentionally best-effort. Phase 9 orphan cleanup covers
    // interrupted cleanup without failing an otherwise successful create.
  }
}

function parseTimestamp(value: unknown): Date {
  if (value instanceof Timestamp) {
    return value.toDate();
  }

  throw new HttpsError(
    "failed-precondition",
    "Photo recognition session timestamp is invalid.",
    {appCode: "recognition-session-invalid"},
  );
}

function parseMasterIdSet(
  value: unknown,
  fieldName: string,
): ReadonlySet<string> {
  if (!Array.isArray(value)) {
    throw new HttpsError(
      "failed-precondition",
      "Photo recognition session candidates are invalid.",
      {appCode: "recognition-session-invalid", fieldName},
    );
  }

  const ids = new Set<string>();
  for (const item of value) {
    if (typeof item !== "string") {
      throw new HttpsError(
        "failed-precondition",
        "Photo recognition session candidates are invalid.",
        {appCode: "recognition-session-invalid", fieldName},
      );
    }

    const normalized = item.trim();
    if (!isMasterId(normalized)) {
      throw new HttpsError(
        "failed-precondition",
        "Photo recognition session contains an invalid Master ID.",
        {appCode: "recognition-session-invalid", fieldName},
      );
    }
    ids.add(normalized);
  }
  return ids;
}

function sha256(value: string): string {
  return createHash("sha256").update(value, "utf8").digest("hex");
}
