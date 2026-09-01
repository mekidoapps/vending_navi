import type {DocumentData, DocumentReference, Firestore, Transaction} from "firebase-admin/firestore";
import {GeoPoint, Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {
  CREATE_VENDING_MACHINE_OPERATION,
  CreateVendingMachineValidationError,
  buildAutoMachineName,
  buildRequestDeduplicationId,
  encodeGeohash,
  isMasterId,
  mergePhotoProductWritePlans,
  mergeProductWritePlans,
  parseCreateVendingMachineInput,
  resolvePhotoManufacturerStatus,
} from "./create_vending_machine_core";

import type {
  FormalPhotoStorageBucketLike,
  PreparedPhotoRegistration,
} from "./photo_recognition/photo_registration_finalization";
import {
  buildFormalPhotoStoragePath,
  buildPhotoRegistrationIds,
  deleteTemporaryPhotoBestEffort,
  preparePhotoRegistration,
  saveFormalPhoto,
} from "./photo_recognition/photo_registration_finalization";

export interface CreateVendingMachineResult {
  readonly machineId: string;
  readonly created: true;
  readonly duplicateCandidates: readonly string[];
}

interface ProductMasterRecord {
  readonly productId: string;
  readonly genreIds: readonly string[];
  readonly isActive: boolean;
}

interface ManufacturerMasterRecord {
  readonly manufacturerId: string;
  readonly displayShortName: string;
  readonly presetProductIds: readonly string[];
}

const ACTIVE_ACCOUNT_STATUS = "active";
const ALLOWED_RESTRICTED_STATUSES = new Set(["restricted", "suspended"]);

export async function createVendingMachineForUser(
  firestore: Firestore,
  bucket: FormalPhotoStorageBucketLike | null,
  uid: string,
  rawInput: unknown,
): Promise<CreateVendingMachineResult> {
  const normalizedUid = uid.trim();
  if (normalizedUid.length === 0) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  let input;
  try {
    input = parseCreateVendingMachineInput(rawInput);
  } catch (error: unknown) {
    if (error instanceof CreateVendingMachineValidationError) {
      throw new HttpsError(
        "invalid-argument",
        error.message,
        {appCode: "invalid-argument"},
      );
    }
    throw error;
  }

  const dedupeId = buildRequestDeduplicationId(
    normalizedUid,
    input.requestId,
  );
  const dedupeRef = firestore
    .collection("request_deduplication")
    .doc(dedupeId);

  // A completed replay must not depend on the temporary image still
  // existing after best-effort cleanup.
  const completedDedupe = await dedupeRef.get();
  if (completedDedupe.exists) {
    return parseStoredResult(completedDedupe.data()?.result);
  }

  let photoContext: PreparedPhotoRegistration | null = null;
  let photoId: string | null = null;
  let formalPhotoPath: string | null = null;
  let machineRef: DocumentReference;

  if (input.registrationMethod === "photo") {
    if (bucket === null || input.temporaryPhotoUploadId === null) {
      throw new HttpsError(
        "failed-precondition",
        "Photo registration storage is unavailable.",
        {appCode: "photo-storage-unavailable"},
      );
    }

    photoContext = await preparePhotoRegistration(
      firestore,
      bucket,
      normalizedUid,
      input.temporaryPhotoUploadId,
      new Date(),
    );

    const ids = buildPhotoRegistrationIds(
      normalizedUid,
      input.requestId,
      input.temporaryPhotoUploadId,
    );
    machineRef = firestore.collection("vending_machines").doc(ids.machineId);
    photoId = ids.photoId;
    formalPhotoPath = buildFormalPhotoStoragePath(ids.machineId, ids.photoId);
    await saveFormalPhoto(bucket, formalPhotoPath, photoContext.photo);
  } else {
    machineRef = firestore.collection("vending_machines").doc();
  }

  const userRef = firestore.collection("users").doc(normalizedUid);
  const privateMachineRef = firestore
    .collection("vending_machine_private")
    .doc(machineRef.id);
  const revisionRef = machineRef.collection("revisions").doc();

  const result = await firestore.runTransaction<CreateVendingMachineResult>(
    async (transaction) => {
      const dedupeSnapshot = await transaction.get(dedupeRef);
      if (dedupeSnapshot.exists) {
        return parseStoredResult(dedupeSnapshot.data()?.result);
      }

      const userSnapshot = await transaction.get(userRef);
      const userStatusWrite = resolveUserStatusWrite(
        userSnapshot.exists,
        userSnapshot.data(),
      );

      let recognitionSessionRef: DocumentReference | null = null;
      if (input.registrationMethod === "photo" && photoContext !== null) {
        recognitionSessionRef = firestore
          .collection("photo_recognition_sessions")
          .doc(photoContext.sessionId);
        const sessionSnapshot = await transaction.get(recognitionSessionRef);
        const sessionData = sessionSnapshot.data();

        if (
          !sessionSnapshot.exists ||
          sessionData === undefined ||
          sessionData.uid !== normalizedUid ||
          sessionData.uploadId !== input.temporaryPhotoUploadId ||
          sessionData.status !== "completed"
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Photo recognition session changed before finalization.",
            {appCode: "recognition-session-mismatch"},
          );
        }

        const finalizedMachineId =
          typeof sessionData.finalizedMachineId === "string" ?
            sessionData.finalizedMachineId.trim() :
            "";
        if (
          finalizedMachineId.length > 0 &&
          finalizedMachineId !== machineRef.id
        ) {
          throw new HttpsError(
            "already-exists",
            "This recognized photo has already been used for another machine.",
            {appCode: "recognition-session-already-finalized"},
          );
        }
      }

      let manufacturer: ManufacturerMasterRecord | null = null;
      if (input.manufacturerId !== null) {
        manufacturer = await readManufacturer(
          transaction,
          firestore,
          input.manufacturerId,
        );
      }

      const presetIds = input.registrationMethod === "manufacturer" ?
        manufacturer?.presetProductIds ?? [] :
        [];
      const requestedProductIds = new Set<string>([
        ...input.confirmedProductIds,
        ...presetIds,
      ]);

      const productMasters = new Map<string, ProductMasterRecord>();
      for (const productId of requestedProductIds) {
        const product = await readProduct(
          transaction,
          firestore,
          productId,
        );
        if (product !== null) {
          productMasters.set(productId, product);
        }
      }

      for (const confirmedId of input.confirmedProductIds) {
        const master = productMasters.get(confirmedId);
        if (master === undefined || !master.isActive) {
          throw new HttpsError(
            "not-found",
            "A confirmed Product ID does not exist or is inactive.",
            {
              appCode: "product-not-found",
              productId: confirmedId,
            },
          );
        }
      }

      const activePresetIds = presetIds.filter((productId) => {
        return productMasters.get(productId)?.isActive === true;
      });

      const productPlans =
        input.registrationMethod === "photo" && photoContext !== null ?
          mergePhotoProductWritePlans(
            input.confirmedProductIds,
            photoContext.recognizedProductIds,
          ) :
          mergeProductWritePlans(
            input.confirmedProductIds,
            activePresetIds,
          );
      const now = Timestamp.now();
      const geoPoint = new GeoPoint(
        input.location.latitude,
        input.location.longitude,
      );
      const geohash = encodeGeohash(
        input.location.latitude,
        input.location.longitude,
      );
      const machineName =
        input.name ??
        buildAutoMachineName(manufacturer?.displayShortName ?? null);

      applyUserStatusWrite(
        transaction,
        userRef,
        userSnapshot.exists,
        userStatusWrite,
        now,
      );

      const manufacturerStatus =
        input.registrationMethod === "photo" && photoContext !== null ?
          resolvePhotoManufacturerStatus(
            input.manufacturerId,
            photoContext.recognizedManufacturerIds,
          ) :
          input.registrationMethod === "manufacturer" ?
            "confirmed" :
            "unknown";
      const dataLevel =
        input.confirmedProductIds.length > 0 ?
          "productsConfirmed" :
          input.manufacturerId !== null ?
            "manufacturerOnly" :
            "locationOnly";

      transaction.create(machineRef, {
        schemaVersion: 2,
        name: machineName,
        manufacturerId: input.manufacturerId,
        manufacturerStatus,
        location: geoPoint,
        geohash,
        placeDescription: input.placeDescription,
        installationType: input.installationType,
        status: "active",
        mergedIntoMachineId: null,
        dataLevel,
        primaryPhotoId: photoId,
        createdAt: now,
        updatedAt: now,
        lastProductUpdatedAt: productPlans.length > 0 ? now : null,
      });

      transaction.create(privateMachineRef, {
        machineId: machineRef.id,
        createdBy: normalizedUid,
        createdAt: now,
        updatedAt: now,
      });

      if (
        input.registrationMethod === "photo" &&
        photoContext !== null &&
        photoId !== null &&
        formalPhotoPath !== null
      ) {
        const photoRef = machineRef.collection("photos").doc(photoId);
        transaction.create(photoRef, {
          storagePath: formalPhotoPath,
          thumbnailPath: null,
          status: "active",
          uploadedBy: normalizedUid,
          uploadedAt: now,
          recognitionStatus: "completed",
          recognitionProvider: photoContext.provider,
          isPrimary: true,
        });
      }

      for (const plan of productPlans) {
        const productMaster = productMasters.get(plan.productId);
        if (productMaster === undefined || !productMaster.isActive) {
          continue;
        }

        const productRef = machineRef
          .collection("products")
          .doc(plan.productId);

        transaction.create(productRef, {
          productId: plan.productId,
          evidenceType: plan.evidenceType,
          availability: plan.availability,
          isActive: true,
          confirmedAt: plan.isConfirmed ? now : null,
          createdAt: now,
          updatedAt: now,
        });

        if (plan.isConfirmed) {
          const privateProductRef = privateMachineRef
            .collection("products")
            .doc(plan.productId);

          transaction.set(privateProductRef, {
            productId: plan.productId,
            confirmedBy: normalizedUid,
            confirmedAt: now,
            createdAt: now,
            updatedAt: now,
          }, {merge: true});
        }

        const indexId = `${machineRef.id}_${plan.productId}`;
        const indexRef = firestore
          .collection("machine_product_index")
          .doc(indexId);

        transaction.create(indexRef, {
          machineId: machineRef.id,
          productId: plan.productId,
          genreIds: productMaster.genreIds,
          location: geoPoint,
          geohash,
          evidenceType: plan.evidenceType,
          availability: plan.availability,
          isActive: true,
          machineStatus: "active",
          machineUpdatedAt: now,
          updatedAt: now,
        });
      }

      const changedFields = [
        "name",
        "manufacturerId",
        "manufacturerStatus",
        "location",
        "geohash",
        "placeDescription",
        "installationType",
        "status",
        "dataLevel",
      ];
      if (productPlans.length > 0) {
        changedFields.push("products");
      }
      if (photoId !== null) {
        changedFields.push("primaryPhotoId", "photos");
      }

      transaction.create(revisionRef, {
        updateType: "machineCreated",
        source:
          input.registrationMethod === "photo" ?
            "photoRecognition" :
            input.registrationMethod === "manufacturer" ?
              "manufacturerPreset" :
              "manual",
        updatedBy: normalizedUid,
        updatedAt: now,
        changedFields,
        beforeSnapshot: null,
        afterSnapshot: {
          name: machineName,
          manufacturerId: input.manufacturerId,
          manufacturerStatus,
          location: {
            latitude: input.location.latitude,
            longitude: input.location.longitude,
          },
          placeDescription: input.placeDescription,
          installationType: input.installationType,
          status: "active",
          dataLevel,
          primaryPhotoId: photoId,
          productIds: productPlans.map((item) => item.productId),
        },
        requestId: input.requestId,
      });

      const result: CreateVendingMachineResult = {
        machineId: machineRef.id,
        created: true,
        duplicateCandidates: [],
      };

      if (
        recognitionSessionRef !== null &&
        photoId !== null
      ) {
        transaction.update(recognitionSessionRef, {
          finalizedMachineId: machineRef.id,
          finalizedPhotoId: photoId,
          finalizedRequestId: input.requestId,
          finalizedAt: now,
        });
      }

      transaction.create(dedupeRef, {
        uid: normalizedUid,
        operation: CREATE_VENDING_MACHINE_OPERATION,
        requestId: input.requestId,
        status: "completed",
        result,
        createdAt: now,
        updatedAt: now,
      });

      return result;
    },
  );

  if (photoContext !== null && bucket !== null) {
    await deleteTemporaryPhotoBestEffort(
      bucket,
      photoContext.photo.objectPath,
    );
  }

  return result;
}

async function readManufacturer(
  transaction: Transaction,
  firestore: Firestore,
  manufacturerId: string,
): Promise<ManufacturerMasterRecord> {
  const reference = firestore
    .collection("manufacturers")
    .doc(manufacturerId);
  const snapshot = await transaction.get(reference);
  const data = snapshot.data();

  if (
    !snapshot.exists ||
    data === undefined ||
    data.isActive !== true
  ) {
    throw new HttpsError(
      "not-found",
      "Manufacturer ID does not exist or is inactive.",
      {
        appCode: "manufacturer-not-found",
        manufacturerId,
      },
    );
  }

  const displayShortName =
    typeof data.displayShortName === "string" ?
      data.displayShortName.trim() :
      "";
  if (displayShortName.length === 0) {
    throw new HttpsError(
      "internal",
      "Manufacturer master is incomplete.",
      {appCode: "manufacturer-master-invalid"},
    );
  }

  const presetProductIds = Array.isArray(data.presetProductIds) ?
    data.presetProductIds
      .filter(
        (value: unknown): value is string =>
          typeof value === "string" && isMasterId(value.trim()),
      )
      .map((value: string) => value.trim()) :
    [];

  return {
    manufacturerId,
    displayShortName,
    presetProductIds: [...new Set(presetProductIds)],
  };
}

async function readProduct(
  transaction: Transaction,
  firestore: Firestore,
  productId: string,
): Promise<ProductMasterRecord | null> {
  const reference = firestore.collection("products").doc(productId);
  const snapshot = await transaction.get(reference);
  const data = snapshot.data();

  if (!snapshot.exists || data === undefined) {
    return null;
  }

  const genreIds = Array.isArray(data.genreIds) ?
    data.genreIds
      .filter(
        (value: unknown): value is string =>
          typeof value === "string" && value.trim().length > 0,
      )
      .map((value: string) => value.trim()) :
    [];

  return {
    productId,
    genreIds: [...new Set(genreIds)],
    isActive: data.isActive === true,
  };
}

function resolveUserStatusWrite(
  exists: boolean,
  data: DocumentData | undefined,
): "none" | "initialize" {
  if (!exists) {
    return "initialize";
  }

  const rawStatus = data?.accountStatus;
  if (rawStatus === undefined || rawStatus === null) {
    // Phase 5 created users without accountStatus. The first formal public
    // write migrates that authenticated profile to the v2-required default.
    return "initialize";
  }

  if (rawStatus === ACTIVE_ACCOUNT_STATUS) {
    return "none";
  }

  if (
    typeof rawStatus === "string" &&
    ALLOWED_RESTRICTED_STATUSES.has(rawStatus)
  ) {
    throw new HttpsError(
      "permission-denied",
      "This account cannot create or update public data.",
      {
        appCode: "account-restricted",
        accountStatus: rawStatus,
      },
    );
  }

  throw new HttpsError(
    "permission-denied",
    "The account status is not valid for public writes.",
    {
      appCode: "account-restricted",
    },
  );
}

function applyUserStatusWrite(
  transaction: Transaction,
  userRef: DocumentReference,
  userExists: boolean,
  write: "none" | "initialize",
  now: Timestamp,
): void {
  if (write === "none") {
    return;
  }

  if (userExists) {
    transaction.set(
      userRef,
      {
        accountStatus: ACTIVE_ACCOUNT_STATUS,
        updatedAt: now,
      },
      {merge: true},
    );
    return;
  }

  transaction.set(userRef, {
    accountStatus: ACTIVE_ACCOUNT_STATUS,
    createdAt: now,
    updatedAt: now,
  });
}

function parseStoredResult(value: unknown): CreateVendingMachineResult {
  if (
    typeof value !== "object" ||
    value === null ||
    Array.isArray(value)
  ) {
    throw new HttpsError(
      "internal",
      "Stored idempotency result is invalid.",
      {appCode: "idempotency-record-invalid"},
    );
  }

  const data = value as Record<string, unknown>;
  if (
    typeof data.machineId !== "string" ||
    data.machineId.trim().length === 0 ||
    data.created !== true ||
    !Array.isArray(data.duplicateCandidates)
  ) {
    throw new HttpsError(
      "internal",
      "Stored idempotency result is invalid.",
      {appCode: "idempotency-record-invalid"},
    );
  }

  return {
    machineId: data.machineId,
    created: true,
    duplicateCandidates: data.duplicateCandidates.filter(
      (item: unknown): item is string => typeof item === "string",
    ),
  };
}
