import type {
  DocumentData,
  DocumentReference,
  Firestore,
  Transaction,
} from "firebase-admin/firestore";
import {
  GeoPoint,
  Timestamp,
} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {
  type ProductEvidenceType,
  isMasterId,
} from "./create_vending_machine_core";
import type {
  FormalPhotoStorageBucketLike,
  PreparedPhotoRegistration,
} from "./photo_recognition/photo_registration_finalization";
import {
  preparePhotoRegistration,
} from "./photo_recognition/photo_registration_finalization";
import {
  buildRecognitionSessionId,
} from "./photo_recognition/recognition_operation_store";
import {
  UPDATE_VENDING_MACHINE_PRODUCTS_OPERATION,
  UpdateVendingMachineProductsValidationError,
  type ExistingProductState,
  type ProductUpdateOperation,
  buildProductUpdateDeduplicationId,
  collectPhotoSourcedProductIds,
  collectReferencedProductIds,
  groupProductUpdateOperations,
  isConfirmedEvidence,
  parseUpdateVendingMachineProductsInput,
  resolveProductUpdatePlan,
} from "./update_vending_machine_products_core";

const ACTIVE_ACCOUNT_STATUS = "active";
const RESTRICTED_ACCOUNT_STATUSES =
  new Set(["restricted", "suspended"]);

interface ProductMasterRecord {
  readonly productId: string;
  readonly genreIds: readonly string[];
  readonly isActive: boolean;
}

interface ProductUpdateWork {
  readonly productId: string;
  readonly operations: readonly ProductUpdateOperation[];
  readonly productRef: DocumentReference;
  readonly indexRef: DocumentReference;
  readonly existingData: DocumentData | undefined;
  readonly indexExists: boolean;
  readonly master: ProductMasterRecord | null;
  readonly plan: ReturnType<typeof resolveProductUpdatePlan>;
}

export interface UpdateVendingMachineProductsResult {
  readonly machineId: string;
  readonly updated: boolean;
  readonly changedProductIds: readonly string[];
}

export async function updateVendingMachineProductsForUser(
  firestore: Firestore,
  bucket: FormalPhotoStorageBucketLike | null,
  uid: string,
  rawInput: unknown,
): Promise<UpdateVendingMachineProductsResult> {
  const normalizedUid = uid.trim();

  if (normalizedUid.length === 0) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required.",
    );
  }

  let input;
  try {
    input = parseUpdateVendingMachineProductsInput(rawInput);
  } catch (error: unknown) {
    if (
      error instanceof
      UpdateVendingMachineProductsValidationError
    ) {
      throw new HttpsError(
        "invalid-argument",
        error.message,
        {appCode: "invalid-product-update"},
      );
    }

    throw error;
  }

  const dedupeId = buildProductUpdateDeduplicationId(
    normalizedUid,
    input.requestId,
  );

  const dedupeRef = firestore
    .collection("request_deduplication")
    .doc(dedupeId);

  // Replays must not depend on an old temporary photo still existing.
  const completedDedupe = await dedupeRef.get();
  if (completedDedupe.exists) {
    return parseStoredResult(completedDedupe.data()?.result);
  }

  const photoProductIds =
    collectPhotoSourcedProductIds(input.operations);

  let photoContext: PreparedPhotoRegistration | null = null;

  if (photoProductIds.length > 0) {
    if (input.temporaryPhotoUploadId === null) {
      throw new HttpsError(
        "invalid-argument",
        "Photo-sourced updates require temporaryPhotoUploadId.",
        {appCode: "photo-upload-required"},
      );
    }

    if (bucket === null) {
      throw new HttpsError(
        "failed-precondition",
        "Photo verification storage is unavailable.",
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

    for (const productId of photoProductIds) {
      if (!photoContext.recognizedProductIds.has(productId)) {
        throw new HttpsError(
          "failed-precondition",
          "A photo-sourced Product ID was not recognized from this photo.",
          {
            appCode: "photo-product-not-recognized",
            productId,
          },
        );
      }
    }
  } else if (input.temporaryPhotoUploadId !== null) {
    throw new HttpsError(
      "invalid-argument",
      "temporaryPhotoUploadId requires a photo-sourced update.",
      {appCode: "unused-photo-upload"},
    );
  }

  const machineRef = firestore
    .collection("vending_machines")
    .doc(input.machineId);

  const privateMachineRef = firestore
    .collection("vending_machine_private")
    .doc(input.machineId);

  const userRef = firestore
    .collection("users")
    .doc(normalizedUid);

  const revisionRef = machineRef
    .collection("revisions")
    .doc();

  const result =
    await firestore.runTransaction<UpdateVendingMachineProductsResult>(
      async (transaction) => {
        const dedupeSnapshot = await transaction.get(dedupeRef);

        if (dedupeSnapshot.exists) {
          return parseStoredResult(
            dedupeSnapshot.data()?.result,
          );
        }

        const userSnapshot = await transaction.get(userRef);

        const userStatusWrite = resolveUserStatusWrite(
          userSnapshot.exists,
          userSnapshot.data(),
        );

        const machineSnapshot =
          await transaction.get(machineRef);

        if (!machineSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "The vending machine does not exist.",
            {appCode: "machine-not-found"},
          );
        }

        const machineData = machineSnapshot.data();

        if (
          machineData === undefined ||
          machineData.schemaVersion !== 2
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Only v2 vending machines can be updated.",
            {appCode: "machine-schema-unsupported"},
          );
        }

        if (machineData.status !== "active") {
          throw new HttpsError(
            "failed-precondition",
            "This vending machine cannot currently be updated.",
            {appCode: "machine-not-active"},
          );
        }

        const location = machineData.location;
        const geohash =
          typeof machineData.geohash === "string" ?
            machineData.geohash.trim() :
            "";

        if (!(location instanceof GeoPoint) || geohash.length === 0) {
          throw new HttpsError(
            "failed-precondition",
            "The vending machine location data is incomplete.",
            {appCode: "machine-location-invalid"},
          );
        }

        let recognitionSessionRef: DocumentReference | null = null;
        let recognitionSessionNeedsMachineBinding = false;

        if (
          photoContext !== null &&
          input.temporaryPhotoUploadId !== null
        ) {
          const sessionId = buildRecognitionSessionId(
            normalizedUid,
            input.temporaryPhotoUploadId,
          );

          recognitionSessionRef = firestore
            .collection("photo_recognition_sessions")
            .doc(sessionId);

          const sessionSnapshot =
            await transaction.get(recognitionSessionRef);

          const sessionData = sessionSnapshot.data();

          if (
            !sessionSnapshot.exists ||
            sessionData === undefined ||
            sessionData.uid !== normalizedUid ||
            sessionData.uploadId !==
              input.temporaryPhotoUploadId ||
            sessionData.status !== "completed"
          ) {
            throw new HttpsError(
              "failed-precondition",
              "Photo recognition session changed before update.",
              {appCode: "recognition-session-mismatch"},
            );
          }

          const expiresAt = sessionData.expiresAt;

          if (
            !(expiresAt instanceof Timestamp) ||
            expiresAt.toMillis() <= Date.now()
          ) {
            throw new HttpsError(
              "failed-precondition",
              "Photo recognition session has expired.",
              {appCode: "recognition-session-expired"},
            );
          }

          const sessionProductIds =
            parseSessionProductIds(
              sessionData.productCandidateIds,
            );

          for (const productId of photoProductIds) {
            if (!sessionProductIds.has(productId)) {
              throw new HttpsError(
                "failed-precondition",
                "Photo recognition candidates changed before update.",
                {
                  appCode: "recognition-session-mismatch",
                  productId,
                },
              );
            }
          }

          const finalizedMachineId =
            typeof sessionData.finalizedMachineId === "string" ?
              sessionData.finalizedMachineId.trim() :
              "";

          if (
            finalizedMachineId.length > 0 &&
            finalizedMachineId !== input.machineId
          ) {
            throw new HttpsError(
              "already-exists",
              "This recognized photo is already bound to another machine.",
              {
                appCode: "recognition-session-already-finalized",
              },
            );
          }

          recognitionSessionNeedsMachineBinding =
            finalizedMachineId.length === 0;
        }

        const grouped =
          groupProductUpdateOperations(input.operations);

        const referencedProductIds =
          collectReferencedProductIds(input.operations);

        const work: ProductUpdateWork[] = [];

        // Every read is completed before transaction writes begin.
        for (const productId of referencedProductIds) {
          const operations = grouped.get(productId);

          if (operations === undefined) {
            throw new HttpsError(
              "internal",
              "Product update grouping failed.",
              {appCode: "product-update-internal"},
            );
          }

          const productRef = machineRef
            .collection("products")
            .doc(productId);

          const indexRef = firestore
            .collection("machine_product_index")
            .doc(`${input.machineId}_${productId}`);

          const masterRef = firestore
            .collection("products")
            .doc(productId);

          const productSnapshot =
            await transaction.get(productRef);

          const masterSnapshot =
            await transaction.get(masterRef);

          const indexSnapshot =
            await transaction.get(indexRef);

          const current = productSnapshot.exists ?
            parseExistingProductState(
              productSnapshot.data(),
              productId,
            ) :
            null;

          const master = masterSnapshot.exists ?
            parseProductMaster(
              masterSnapshot.data(),
              productId,
            ) :
            null;

          if (
            operations.some(
              (operation) =>
                operation.type === "addConfirmed",
            ) &&
            (master === null || !master.isActive)
          ) {
            throw new HttpsError(
              "not-found",
              "A Product ID does not exist or is inactive.",
              {
                appCode: "product-not-found",
                productId,
              },
            );
          }

          let plan;

          try {
            plan = resolveProductUpdatePlan(
              current,
              operations,
            );
          } catch (error: unknown) {
            if (
              error instanceof
              UpdateVendingMachineProductsValidationError
            ) {
              throw new HttpsError(
                "failed-precondition",
                error.message,
                {
                  appCode: "product-update-not-allowed",
                  productId,
                },
              );
            }

            throw error;
          }

          if (
            plan.changed &&
            !indexSnapshot.exists &&
            master === null
          ) {
            throw new HttpsError(
              "failed-precondition",
              "The product search index cannot be rebuilt.",
              {
                appCode: "product-index-rebuild-unavailable",
                productId,
              },
            );
          }

          work.push({
            productId,
            operations,
            productRef,
            indexRef,
            existingData: productSnapshot.data(),
            indexExists: indexSnapshot.exists,
            master,
            plan,
          });
        }

        const changed =
          work.filter((item) => item.plan.changed);

        const changedProductIds =
          changed.map((item) => item.productId);

        const now = Timestamp.now();

        applyUserStatusWrite(
          transaction,
          userRef,
          userSnapshot.exists,
          userStatusWrite,
          now,
        );

        for (const item of changed) {
          const {plan} = item;

          const becameConfirmed =
            isConfirmedEvidence(plan.after.evidenceType) &&
            (
              plan.before === null ||
              !isConfirmedEvidence(
                plan.before.evidenceType,
              ) ||
              !plan.before.isActive
            );

          if (plan.createsDocument) {
            transaction.create(item.productRef, {
              productId: item.productId,
              evidenceType: plan.after.evidenceType,
              availability: plan.after.availability,
              isActive: plan.after.isActive,
              confirmedAt:
                isConfirmedEvidence(plan.after.evidenceType) ?
                  now :
                  null,
              createdAt: now,
              updatedAt: now,
            });
          } else {
            const productPatch: Record<string, unknown> = {
              evidenceType: plan.after.evidenceType,
              availability: plan.after.availability,
              isActive: plan.after.isActive,
              updatedAt: now,
            };

            if (becameConfirmed) {
              productPatch.confirmedAt = now;
            }

            transaction.update(
              item.productRef,
              productPatch,
            );
          }

          if (becameConfirmed) {
            const privateProductRef = privateMachineRef
              .collection("products")
              .doc(item.productId);

            transaction.set(privateProductRef, {
              productId: item.productId,
              confirmedBy: normalizedUid,
              confirmedAt: now,
              updatedAt: now,
            }, {merge: true});
          }

          const indexData: Record<string, unknown> = {
            machineId: input.machineId,
            productId: item.productId,
            location,
            geohash,
            evidenceType: plan.after.evidenceType,
            availability: plan.after.availability,
            isActive: plan.after.isActive,
            machineStatus: machineData.status,
            machineUpdatedAt: now,
            updatedAt: now,
          };

          if (item.master !== null) {
            indexData.genreIds = item.master.genreIds;
          }

          if (item.indexExists) {
            transaction.update(
              item.indexRef,
              indexData,
            );
          } else {
            transaction.create(
              item.indexRef,
              indexData,
            );
          }
        }

        if (changed.length > 0) {
          transaction.update(machineRef, {
            updatedAt: now,
            lastProductUpdatedAt: now,
          });

          transaction.create(revisionRef, {
            updateType: "productsUpdated",
            source:
              photoProductIds.length > 0 ?
                "photoRecognition" :
                "manual",
            updatedBy: normalizedUid,
            updatedAt: now,
            changedFields: [
              "products",
              "lastProductUpdatedAt",
            ],
            beforeSnapshot: {
              products: changed.map((item) =>
                serializeProductState(
                  item.plan.before,
                ),
              ),
            },
            afterSnapshot: {
              products: changed.map((item) =>
                serializeProductState(
                  item.plan.after,
                ),
              ),
            },
            requestId: input.requestId,
          });
        }

        if (
          recognitionSessionRef !== null &&
          recognitionSessionNeedsMachineBinding
        ) {
          transaction.update(recognitionSessionRef, {
            finalizedMachineId: input.machineId,
            finalizedRequestId: input.requestId,
            finalizedAt: now,
          });
        }

        const updateResult:
          UpdateVendingMachineProductsResult = {
            machineId: input.machineId,
            updated: changed.length > 0,
            changedProductIds,
          };

        transaction.create(dedupeRef, {
          uid: normalizedUid,
          operation:
            UPDATE_VENDING_MACHINE_PRODUCTS_OPERATION,
          requestId: input.requestId,
          status: "completed",
          result: updateResult,
          createdAt: now,
          updatedAt: now,
        });

        return updateResult;
      },
    );

  // Do not delete the temporary photo here.
  // P8-04 addVendingMachinePhoto may still formalize the same upload.

  return result;
}

function parseExistingProductState(
  data: DocumentData | undefined,
  productId: string,
): ExistingProductState {
  if (data === undefined) {
    throw new HttpsError(
      "failed-precondition",
      "The existing product data is invalid.",
      {
        appCode: "machine-product-invalid",
        productId,
      },
    );
  }

  if (data.productId !== productId) {
    throw new HttpsError(
      "failed-precondition",
      "The existing product ID is inconsistent.",
      {
        appCode: "machine-product-invalid",
        productId,
      },
    );
  }

  const evidenceType =
    parseEvidenceType(data.evidenceType, productId);

  const availability =
    parseAvailability(data.availability, productId);

  if (typeof data.isActive !== "boolean") {
    throw new HttpsError(
      "failed-precondition",
      "The existing product active state is invalid.",
      {
        appCode: "machine-product-invalid",
        productId,
      },
    );
  }

  return {
    productId,
    evidenceType,
    availability,
    isActive: data.isActive,
  };
}

function parseEvidenceType(
  value: unknown,
  productId: string,
): ProductEvidenceType {
  if (
    value === "manual_confirmed" ||
    value === "photo_confirmed" ||
    value === "manufacturer_inferred"
  ) {
    return value;
  }

  throw new HttpsError(
    "failed-precondition",
    "The existing product evidence is invalid.",
    {
      appCode: "machine-product-invalid",
      productId,
    },
  );
}

function parseAvailability(
  value: unknown,
  productId: string,
): "available" | "soldOut" | "unknown" {
  if (
    value === "available" ||
    value === "soldOut" ||
    value === "unknown"
  ) {
    return value;
  }

  throw new HttpsError(
    "failed-precondition",
    "The existing product availability is invalid.",
    {
      appCode: "machine-product-invalid",
      productId,
    },
  );
}

function parseProductMaster(
  data: DocumentData | undefined,
  productId: string,
): ProductMasterRecord {
  if (data === undefined) {
    throw new HttpsError(
      "internal",
      "Product master data is invalid.",
      {
        appCode: "product-master-invalid",
        productId,
      },
    );
  }

  const genreIds = Array.isArray(data.genreIds) ?
    data.genreIds
      .filter(
        (value: unknown): value is string =>
          typeof value === "string" &&
          isMasterId(value.trim()),
      )
      .map((value: string) => value.trim()) :
    [];

  return {
    productId,
    genreIds: [...new Set(genreIds)],
    isActive: data.isActive === true,
  };
}

function parseSessionProductIds(
  value: unknown,
): ReadonlySet<string> {
  if (!Array.isArray(value)) {
    throw new HttpsError(
      "failed-precondition",
      "Photo recognition session candidates are invalid.",
      {appCode: "recognition-session-invalid"},
    );
  }

  const result = new Set<string>();

  for (const item of value) {
    if (
      typeof item !== "string" ||
      !isMasterId(item.trim())
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Photo recognition session candidates are invalid.",
        {appCode: "recognition-session-invalid"},
      );
    }

    result.add(item.trim());
  }

  return result;
}

function resolveUserStatusWrite(
  exists: boolean,
  data: DocumentData | undefined,
): "none" | "initialize" {
  if (!exists) {
    return "initialize";
  }

  const status = data?.accountStatus;

  if (status === undefined || status === null) {
    return "initialize";
  }

  if (status === ACTIVE_ACCOUNT_STATUS) {
    return "none";
  }

  if (
    typeof status === "string" &&
    RESTRICTED_ACCOUNT_STATUSES.has(status)
  ) {
    throw new HttpsError(
      "permission-denied",
      "This account cannot create or update public data.",
      {
        appCode: "account-restricted",
        accountStatus: status,
      },
    );
  }

  throw new HttpsError(
    "permission-denied",
    "The account status is not valid for public writes.",
    {appCode: "account-restricted"},
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

function serializeProductState(
  state: ExistingProductState | null,
) {
  if (state === null) {
    return null;
  }

  return {
    productId: state.productId,
    evidenceType: state.evidenceType,
    availability: state.availability,
    isActive: state.isActive,
  };
}

function parseStoredResult(
  value: unknown,
): UpdateVendingMachineProductsResult {
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
    typeof data.updated !== "boolean" ||
    !Array.isArray(data.changedProductIds)
  ) {
    throw new HttpsError(
      "internal",
      "Stored idempotency result is invalid.",
      {appCode: "idempotency-record-invalid"},
    );
  }

  return {
    machineId: data.machineId,
    updated: data.updated,
    changedProductIds:
      data.changedProductIds.filter(
        (value: unknown): value is string =>
          typeof value === "string",
      ),
  };
}
