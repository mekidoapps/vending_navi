import {
  type DocumentData,
  type DocumentReference,
  type Firestore,
  GeoPoint,
  Timestamp,
  type Transaction,
} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {
  SUBMIT_MACHINE_CORRECTION_OPERATION,
  SubmitMachineCorrectionValidationError,
  buildMachineCorrectionDeduplicationId,
  buildMachineCorrectionId,
  parseSubmitMachineCorrectionInput,
  removeUnchangedCorrectionFields,
  type CurrentMachineCorrectionState,
  type MachineCorrectionChanges,
} from "./submit_machine_correction_core";

const ACTIVE_ACCOUNT_STATUS = "active";
const RESTRICTED_ACCOUNT_STATUSES =
  new Set(["restricted", "suspended"]);

const INSTALLATION_TYPES =
  new Set(["outdoor", "indoor", "unknown"]);

export interface SubmitMachineCorrectionResult {
  readonly machineId: string;
  readonly correctionId: string;
  readonly submitted: true;
}

export async function submitMachineCorrectionForUser(
  firestore: Firestore,
  uid: string,
  rawInput: unknown,
): Promise<SubmitMachineCorrectionResult> {
  const normalizedUid = uid.trim();

  if (normalizedUid.length === 0) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required.",
    );
  }

  let input;
  try {
    input = parseSubmitMachineCorrectionInput(rawInput);
  } catch (error: unknown) {
    if (
      error instanceof
      SubmitMachineCorrectionValidationError
    ) {
      throw new HttpsError(
        "invalid-argument",
        error.message,
        {appCode: "invalid-machine-correction"},
      );
    }

    throw error;
  }

  const dedupeId =
    buildMachineCorrectionDeduplicationId(
      normalizedUid,
      input.requestId,
    );

  const correctionId =
    buildMachineCorrectionId(
      normalizedUid,
      input.requestId,
    );

  const dedupeRef = firestore
    .collection("request_deduplication")
    .doc(dedupeId);

  const completedDedupe = await dedupeRef.get();
  if (completedDedupe.exists) {
    return parseStoredResult(
      completedDedupe.data()?.result,
    );
  }

  const machineRef = firestore
    .collection("vending_machines")
    .doc(input.machineId);

  const userRef = firestore
    .collection("users")
    .doc(normalizedUid);

  const correctionRef = firestore
    .collection("machine_corrections")
    .doc(correctionId);

  return firestore.runTransaction<
    SubmitMachineCorrectionResult
  >(
    async (transaction) => {
      const dedupeSnapshot =
        await transaction.get(dedupeRef);

      if (dedupeSnapshot.exists) {
        return parseStoredResult(
          dedupeSnapshot.data()?.result,
        );
      }

      const userSnapshot =
        await transaction.get(userRef);

      const userStatusWrite =
        resolveUserStatusWrite(
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
          "Only v2 vending machines can receive corrections.",
          {appCode: "machine-schema-unsupported"},
        );
      }

      if (machineData.status !== "active") {
        throw new HttpsError(
          "failed-precondition",
          "This vending machine cannot currently receive corrections.",
          {appCode: "machine-not-active"},
        );
      }

      const current =
        parseCurrentMachineState(machineData);

      const effectiveChanges =
        removeUnchangedCorrectionFields(
          input.changes,
          current,
        );

      if (
        Object.keys(effectiveChanges).length === 0
      ) {
        throw new HttpsError(
          "invalid-argument",
          "The correction does not change any current information.",
          {appCode: "correction-no-changes"},
        );
      }

      const proposedManufacturerId =
        effectiveChanges.manufacturerId;

      if (
        Object.hasOwn(
          effectiveChanges,
          "manufacturerId",
        ) &&
        typeof proposedManufacturerId === "string"
      ) {
        await assertActiveManufacturer(
          transaction,
          firestore,
          proposedManufacturerId,
        );
      }

      const now = Timestamp.now();

      applyUserStatusWrite(
        transaction,
        userRef,
        userSnapshot.exists,
        userStatusWrite,
        now,
      );

      const storedChanges =
        serializeCorrectionChanges(
          effectiveChanges,
        );

      transaction.create(correctionRef, {
        machineId: input.machineId,
        changes: storedChanges,
        message: input.message,
        status: "new",
        submittedBy: normalizedUid,
        createdAt: now,
        reviewedAt: null,
        reviewedBy: null,
        resolution: null,
        requestId: input.requestId,
      });

      const result:
        SubmitMachineCorrectionResult = {
          machineId: input.machineId,
          correctionId,
          submitted: true,
        };

      transaction.create(dedupeRef, {
        uid: normalizedUid,
        operation:
          SUBMIT_MACHINE_CORRECTION_OPERATION,
        requestId: input.requestId,
        status: "completed",
        result,
        createdAt: now,
        updatedAt: now,
      });

      return result;
    },
  );
}

function parseCurrentMachineState(
  data: DocumentData,
): CurrentMachineCorrectionState {
  const name =
    typeof data.name === "string" ?
      data.name.trim() :
      "";

  const manufacturerId =
    typeof data.manufacturerId === "string" ?
      data.manufacturerId.trim() :
      null;

  const location = data.location;

  const placeDescription =
    typeof data.placeDescription === "string" ?
      data.placeDescription.trim() :
      null;

  const installationType =
    typeof data.installationType === "string" ?
      data.installationType.trim() :
      "";

  if (
    name.length === 0 ||
    !(location instanceof GeoPoint) ||
    !INSTALLATION_TYPES.has(installationType)
  ) {
    throw new HttpsError(
      "failed-precondition",
      "The vending machine basic information is incomplete.",
      {appCode: "machine-data-invalid"},
    );
  }

  return {
    name,
    manufacturerId:
      manufacturerId !== null &&
      manufacturerId.length > 0 ?
        manufacturerId :
        null,
    location: {
      latitude: location.latitude,
      longitude: location.longitude,
    },
    placeDescription:
      placeDescription !== null &&
      placeDescription.length > 0 ?
        placeDescription :
        null,
    installationType,
  };
}

async function assertActiveManufacturer(
  transaction: Transaction,
  firestore: Firestore,
  manufacturerId: string,
): Promise<void> {
  const reference = firestore
    .collection("manufacturers")
    .doc(manufacturerId);

  const snapshot =
    await transaction.get(reference);

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
}

function serializeCorrectionChanges(
  changes: MachineCorrectionChanges,
): Record<string, unknown> {
  const result: Record<string, unknown> = {};

  if (changes.name !== undefined) {
    result.name = changes.name;
  }

  if (
    Object.hasOwn(changes, "manufacturerId")
  ) {
    result.manufacturerId =
      changes.manufacturerId ?? null;
  }

  if (changes.location !== undefined) {
    result.location = new GeoPoint(
      changes.location.latitude,
      changes.location.longitude,
    );
  }

  if (
    Object.hasOwn(
      changes,
      "placeDescription",
    )
  ) {
    result.placeDescription =
      changes.placeDescription ?? null;
  }

  if (
    changes.installationType !== undefined
  ) {
    result.installationType =
      changes.installationType;
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

function parseStoredResult(
  value: unknown,
): SubmitMachineCorrectionResult {
  if (
    typeof value !== "object" ||
    value === null ||
    Array.isArray(value)
  ) {
    throw invalidStoredResult();
  }

  const data =
    value as Record<string, unknown>;

  if (
    typeof data.machineId !== "string" ||
    data.machineId.trim().length === 0 ||
    typeof data.correctionId !== "string" ||
    data.correctionId.trim().length === 0 ||
    data.submitted !== true
  ) {
    throw invalidStoredResult();
  }

  return {
    machineId: data.machineId.trim(),
    correctionId:
      data.correctionId.trim(),
    submitted: true,
  };
}

function invalidStoredResult(): HttpsError {
  return new HttpsError(
    "internal",
    "Stored idempotency result is invalid.",
    {appCode: "idempotency-record-invalid"},
  );
}
