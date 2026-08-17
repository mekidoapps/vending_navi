import type {
  DocumentData,
  DocumentReference,
  Firestore,
  Transaction,
} from "firebase-admin/firestore";
import { Timestamp } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import {
  ADD_VENDING_MACHINE_PHOTO_OPERATION,
  type AddVendingMachinePhotoResult,
  buildAddedPhotoId,
  buildAddVendingMachinePhotoDedupeId,
  parseAddVendingMachinePhotoInput,
  parseStoredAddVendingMachinePhotoResult,
} from "./add_vending_machine_photo_core";
import {
  type FormalPhotoStorageBucketLike,
  buildFormalPhotoStoragePath,
  deleteTemporaryPhotoBestEffort,
  preparePhotoRegistration,
  saveFormalPhoto,
} from "./photo_recognition/photo_registration_finalization";
import { buildTemporaryPhotoBinding } from "./photo_recognition/temporary_photo_binding";

const ACTIVE_ACCOUNT_STATUS = "active";
const RESTRICTED_ACCOUNT_STATUSES = new Set(["restricted", "suspended"]);

type UserStatusWrite = "none" | "initialize" | "backfill";

export async function addVendingMachinePhotoForUser(
  firestore: Firestore,
  bucket: FormalPhotoStorageBucketLike,
  uid: string,
  rawInput: unknown,
): Promise<AddVendingMachinePhotoResult> {
  const normalizedUid = uid.trim();

  if (normalizedUid.length === 0) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  let input;
  try {
    input = parseAddVendingMachinePhotoInput(rawInput);
  } catch {
    throw new HttpsError(
      "invalid-argument",
      "The add-photo request is invalid.",
      { appCode: "invalid-add-photo-request" },
    );
  }

  const dedupeId = buildAddVendingMachinePhotoDedupeId(
    normalizedUid,
    input.requestId,
  );

  const dedupeRef = firestore.collection("request_deduplication").doc(dedupeId);

  // A successful replay must not depend on the temporary photo still
  // existing because successful finalization removes it best-effort.
  const completedDedupe = await dedupeRef.get();
  if (completedDedupe.exists) {
    return parseStoredAddVendingMachinePhotoResult(
      completedDedupe.data()?.result,
    );
  }

  const nowDate = new Date();
  const now = Timestamp.fromDate(nowDate);

  // Reject normal authorization / target-state failures before reserving
  // formal Storage. The transaction repeats these checks for race safety.
  const preflightUserRef = firestore
    .collection("users")
    .doc(normalizedUid);

  const preflightUserSnapshot =
    await preflightUserRef.get();

  resolveUserStatusWrite(
    preflightUserSnapshot.exists,
    preflightUserSnapshot.data(),
  );

  const preflightMachineRef = firestore
    .collection("vending_machines")
    .doc(input.machineId);

  const preflightMachineSnapshot =
    await preflightMachineRef.get();

  if (!preflightMachineSnapshot.exists) {
    throw new HttpsError(
      "not-found",
      "The vending machine does not exist.",
      {appCode: "machine-not-found"},
    );
  }

  const preflightMachineData =
    preflightMachineSnapshot.data();

  if (
    preflightMachineData === undefined ||
    preflightMachineData.schemaVersion !== 2
  ) {
    throw new HttpsError(
      "failed-precondition",
      "The vending machine schema is unsupported.",
      {appCode: "unsupported-machine-schema"},
    );
  }

  if (preflightMachineData.status !== "active") {
    throw new HttpsError(
      "failed-precondition",
      "Photos can only be added to active vending machines.",
      {appCode: "machine-not-active"},
    );
  }

  parsePrimaryPhotoId(
    preflightMachineData.primaryPhotoId,
  );

  const photoContext = await preparePhotoRegistration(
    firestore,
    bucket,
    normalizedUid,
    input.temporaryPhotoUploadId,
    nowDate,
  );

  const photoId = buildAddedPhotoId(
    normalizedUid,
    input.machineId,
    input.temporaryPhotoUploadId,
  );

  const formalPhotoPath = buildFormalPhotoStoragePath(input.machineId, photoId);

  // Refuse an already-published recognition before touching formal
  // Storage. The transaction below repeats this check for race safety.
  const sessionBeforeSave = await firestore
    .collection("photo_recognition_sessions")
    .doc(photoContext.sessionId)
    .get();

  const sessionBeforeSaveData = sessionBeforeSave.data();

  if (
    !sessionBeforeSave.exists ||
    sessionBeforeSaveData === undefined ||
    sessionBeforeSaveData.uid !== normalizedUid ||
    sessionBeforeSaveData.uploadId !== input.temporaryPhotoUploadId ||
    sessionBeforeSaveData.status !== "completed"
  ) {
    throw new HttpsError(
      "failed-precondition",
      "The photo recognition session changed before finalization.",
      { appCode: "recognition-session-mismatch" },
    );
  }

  const preFinalizedMachineId = optionalTrimmedString(
    sessionBeforeSaveData.finalizedMachineId,
  );

  if (
    preFinalizedMachineId !== null &&
    preFinalizedMachineId !== input.machineId
  ) {
    throw new HttpsError(
      "already-exists",
      "This recognized photo has already been used for another machine.",
      {
        appCode: "recognition-session-already-finalized",
      },
    );
  }

  if (optionalTrimmedString(sessionBeforeSaveData.finalizedPhotoId) !== null) {
    throw new HttpsError(
      "already-exists",
      "This recognized photo has already been published.",
      {
        appCode: "recognition-photo-already-finalized",
      },
    );
  }

  // The exact recognized bytes are now safe to reserve at the formal path.
  // photoId is upload-scoped, so concurrent attempts target the same object
  // instead of producing request-scoped orphan files.
  await saveFormalPhoto(bucket, formalPhotoPath, photoContext.photo);

  const recognitionBinding = buildTemporaryPhotoBinding(photoContext.photo);

  const machineRef = firestore
    .collection("vending_machines")
    .doc(input.machineId);

  const photoRef = machineRef.collection("photos").doc(photoId);

  const revisionRef = machineRef.collection("revisions").doc();

  const userRef = firestore.collection("users").doc(normalizedUid);

  const recognitionSessionRef = firestore
    .collection("photo_recognition_sessions")
    .doc(photoContext.sessionId);

  const result = await firestore.runTransaction<AddVendingMachinePhotoResult>(
    async (transaction) => {
      const dedupeSnapshot = await transaction.get(dedupeRef);

      if (dedupeSnapshot.exists) {
        return parseStoredAddVendingMachinePhotoResult(
          dedupeSnapshot.data()?.result,
        );
      }

      const userSnapshot = await transaction.get(userRef);

      const userStatusWrite = resolveUserStatusWrite(
        userSnapshot.exists,
        userSnapshot.data(),
      );

      const machineSnapshot = await transaction.get(machineRef);

      if (!machineSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "The vending machine does not exist.",
          { appCode: "machine-not-found" },
        );
      }

      const machineData = machineSnapshot.data();

      if (machineData === undefined || machineData.schemaVersion !== 2) {
        throw new HttpsError(
          "failed-precondition",
          "The vending machine schema is unsupported.",
          { appCode: "unsupported-machine-schema" },
        );
      }

      if (machineData.status !== "active") {
        throw new HttpsError(
          "failed-precondition",
          "Photos can only be added to active vending machines.",
          { appCode: "machine-not-active" },
        );
      }

      const existingPrimaryPhotoId = parsePrimaryPhotoId(
        machineData.primaryPhotoId,
      );

      const primaryPhotoChanged = existingPrimaryPhotoId === null;

      const sessionSnapshot = await transaction.get(recognitionSessionRef);

      if (!sessionSnapshot.exists) {
        throw new HttpsError(
          "failed-precondition",
          "The photo recognition session is unavailable.",
          { appCode: "recognition-session-not-found" },
        );
      }

      const sessionData = sessionSnapshot.data();

      if (
        sessionData === undefined ||
        sessionData.uid !== normalizedUid ||
        sessionData.uploadId !== input.temporaryPhotoUploadId ||
        sessionData.status !== "completed"
      ) {
        throw new HttpsError(
          "failed-precondition",
          "The photo recognition session changed before finalization.",
          { appCode: "recognition-session-mismatch" },
        );
      }

      verifyRecognitionBinding(sessionData, recognitionBinding);

      const finalizedMachineId = optionalTrimmedString(
        sessionData.finalizedMachineId,
      );

      if (
        finalizedMachineId !== null &&
        finalizedMachineId !== input.machineId
      ) {
        throw new HttpsError(
          "already-exists",
          "This recognized photo has already been used for another machine.",
          {
            appCode: "recognition-session-already-finalized",
          },
        );
      }

      const finalizedPhotoId = optionalTrimmedString(
        sessionData.finalizedPhotoId,
      );

      // updateVendingMachineProducts may already have bound the
      // recognition session to this same machine. That is expected.
      // A finalized photo, however, must never be published twice.
      if (finalizedPhotoId !== null) {
        throw new HttpsError(
          "already-exists",
          "This recognized photo has already been published.",
          {
            appCode: "recognition-photo-already-finalized",
          },
        );
      }

      const existingPhotoSnapshot = await transaction.get(photoRef);

      if (existingPhotoSnapshot.exists) {
        throw new HttpsError(
          "already-exists",
          "The vending-machine photo already exists.",
          { appCode: "photo-already-exists" },
        );
      }

      applyUserStatusWrite(
        transaction,
        userRef,
        userSnapshot.exists,
        userStatusWrite,
        now,
      );

      transaction.create(photoRef, {
        storagePath: formalPhotoPath,
        thumbnailPath: null,
        status: "active",
        uploadedBy: normalizedUid,
        uploadedAt: now,
        recognitionStatus: "completed",
        recognitionProvider: photoContext.provider,
        isPrimary: primaryPhotoChanged,
      });

      const machineUpdate: Record<string, unknown> = {
        updatedAt: now,
      };

      if (primaryPhotoChanged) {
        machineUpdate.primaryPhotoId = photoId;
      }

      transaction.update(machineRef, machineUpdate);

      transaction.create(revisionRef, {
        updateType: "photoAdded",
        source: "photoRecognition",
        updatedBy: normalizedUid,
        updatedAt: now,
        changedFields: primaryPhotoChanged
          ? ["photos", "primaryPhotoId"]
          : ["photos"],
        beforeSnapshot: {
          primaryPhotoId: existingPrimaryPhotoId,
        },
        afterSnapshot: {
          primaryPhotoId: primaryPhotoChanged
            ? photoId
            : existingPrimaryPhotoId,
          addedPhotoId: photoId,
        },
        requestId: input.requestId,
      });

      // Preserve updateVendingMachineProducts' finalizedRequestId/
      // finalizedAt if it already bound this recognition session.
      // Photo publication gets its own audit fields.
      transaction.update(recognitionSessionRef, {
        finalizedMachineId: input.machineId,
        finalizedPhotoId: photoId,
        photoFinalizedRequestId: input.requestId,
        photoFinalizedAt: now,
      });

      const transactionResult: AddVendingMachinePhotoResult = {
        machineId: input.machineId,
        photoId,
        added: true,
        primaryPhotoChanged,
      };

      transaction.create(dedupeRef, {
        uid: normalizedUid,
        operation: ADD_VENDING_MACHINE_PHOTO_OPERATION,
        requestId: input.requestId,
        status: "completed",
        result: transactionResult,
        createdAt: now,
        updatedAt: now,
      });

      return transactionResult;
    },
  );

  await deleteTemporaryPhotoBestEffort(bucket, photoContext.photo.objectPath);

  return result;
}

function parsePrimaryPhotoId(value: unknown): string | null {
  if (value === null) {
    return null;
  }

  if (typeof value === "string" && value.trim().length > 0) {
    return value.trim();
  }

  throw new HttpsError(
    "failed-precondition",
    "The vending machine photo state is invalid.",
    { appCode: "machine-photo-state-invalid" },
  );
}

function verifyRecognitionBinding(
  sessionData: DocumentData,
  actual: {
    readonly objectPath: string;
    readonly contentSha256: string;
    readonly sizeBytes: number;
  },
): void {
  const expectedObjectPath = optionalTrimmedString(sessionData.photoObjectPath);

  const expectedHash =
    optionalTrimmedString(sessionData.photoContentSha256)?.toLowerCase() ??
    null;

  const expectedSize = sessionData.photoSizeBytes;

  if (
    expectedObjectPath === null ||
    expectedHash === null ||
    !Number.isSafeInteger(expectedSize) ||
    expectedSize <= 0 ||
    expectedObjectPath !== actual.objectPath ||
    expectedHash !== actual.contentSha256 ||
    expectedSize !== actual.sizeBytes
  ) {
    throw new HttpsError(
      "failed-precondition",
      "The recognized photo binding changed before finalization.",
      {
        appCode: "recognition-photo-binding-mismatch",
      },
    );
  }
}

function optionalTrimmedString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const normalized = value.trim();
  return normalized.length === 0 ? null : normalized;
}

function resolveUserStatusWrite(
  exists: boolean,
  data: DocumentData | undefined,
): UserStatusWrite {
  if (!exists) {
    return "initialize";
  }

  const status = data?.accountStatus;

  // Phase 5 user documents may predate accountStatus.
  if (status === undefined || status === null || status === "") {
    return "backfill";
  }

  if (status === ACTIVE_ACCOUNT_STATUS) {
    return "none";
  }

  if (typeof status === "string" && RESTRICTED_ACCOUNT_STATUSES.has(status)) {
    throw new HttpsError(
      "permission-denied",
      "This account cannot modify public vending-machine data.",
      {
        appCode: "account-restricted",
        accountStatus: status,
      },
    );
  }

  throw new HttpsError(
    "permission-denied",
    "This account cannot modify public vending-machine data.",
    { appCode: "account-restricted" },
  );
}

function applyUserStatusWrite(
  transaction: Transaction,
  userRef: DocumentReference,
  exists: boolean,
  write: UserStatusWrite,
  now: Timestamp,
): void {
  if (write === "none") {
    return;
  }

  if (!exists || write === "initialize") {
    transaction.set(
      userRef,
      {
        accountStatus: ACTIVE_ACCOUNT_STATUS,
        createdAt: now,
        updatedAt: now,
      },
      { merge: true },
    );
    return;
  }

  transaction.set(
    userRef,
    {
      accountStatus: ACTIVE_ACCOUNT_STATUS,
      updatedAt: now,
    },
    { merge: true },
  );
}
