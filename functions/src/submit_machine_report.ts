import {
  type DocumentData,
  type DocumentReference,
  type Firestore,
  Timestamp,
  type Transaction,
} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {
  SUBMIT_MACHINE_REPORT_OPERATION,
  SubmitMachineReportValidationError,
  buildMachineReportDeduplicationId,
  buildMachineReportId,
  parseStoredMachineReportResult,
  parseSubmitMachineReportInput,
  type SubmitMachineReportResult,
} from "./submit_machine_report_core";

const ACTIVE_ACCOUNT_STATUS = "active";

const RESTRICTED_ACCOUNT_STATUSES =
  new Set(["restricted", "suspended"]);

export async function submitMachineReportForUser(
  firestore: Firestore,
  uid: string,
  rawInput: unknown,
): Promise<SubmitMachineReportResult> {
  const normalizedUid = uid.trim();

  if (normalizedUid.length === 0) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required.",
    );
  }

  let input;

  try {
    input = parseSubmitMachineReportInput(rawInput);
  } catch (error: unknown) {
    if (
      error instanceof
      SubmitMachineReportValidationError
    ) {
      throw new HttpsError(
        "invalid-argument",
        error.message,
        {appCode: "invalid-machine-report"},
      );
    }

    throw error;
  }

  const dedupeId =
    buildMachineReportDeduplicationId(
      normalizedUid,
      input.requestId,
    );

  const reportId =
    buildMachineReportId(
      normalizedUid,
      input.requestId,
    );

  const dedupeRef = firestore
    .collection("request_deduplication")
    .doc(dedupeId);

  const completedDedupe = await dedupeRef.get();

  if (completedDedupe.exists) {
    try {
      return parseStoredMachineReportResult(
        completedDedupe.data()?.result,
      );
    } catch {
      throw invalidStoredResult();
    }
  }

  const machineRef = firestore
    .collection("vending_machines")
    .doc(input.machineId);

  const reportRef = firestore
    .collection("machine_reports")
    .doc(reportId);

  const userRef = firestore
    .collection("users")
    .doc(normalizedUid);

  const photoRef =
    input.photoId === null ?
      null :
      machineRef
        .collection("photos")
        .doc(input.photoId);

  return firestore.runTransaction<
    SubmitMachineReportResult
  >(
    async (transaction) => {
      const dedupeSnapshot =
        await transaction.get(dedupeRef);

      if (dedupeSnapshot.exists) {
        try {
          return parseStoredMachineReportResult(
            dedupeSnapshot.data()?.result,
          );
        } catch {
          throw invalidStoredResult();
        }
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

      const machineData =
        machineSnapshot.data();

      if (
        machineData === undefined ||
        machineData.schemaVersion !== 2
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Only v2 vending machines can receive reports.",
          {appCode: "machine-schema-unsupported"},
        );
      }

      if (photoRef !== null) {
        const photoSnapshot =
          await transaction.get(photoRef);

        if (!photoSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "The reported photo does not exist on this vending machine.",
            {appCode: "machine-photo-not-found"},
          );
        }
      }

      const now = Timestamp.now();

      applyUserStatusWrite(
        transaction,
        userRef,
        userSnapshot.exists,
        userStatusWrite,
        now,
      );

      transaction.create(reportRef, {
        machineId: input.machineId,
        photoId: input.photoId,
        category: input.category,
        message: input.message,
        status: "new",
        reportedBy: normalizedUid,
        createdAt: now,
        reviewedAt: null,
        reviewedBy: null,
        resolution: null,
        requestId: input.requestId,
      });

      const result:
        SubmitMachineReportResult = {
          machineId: input.machineId,
          reportId,
          submitted: true,
        };

      transaction.create(dedupeRef, {
        uid: normalizedUid,
        operation:
          SUBMIT_MACHINE_REPORT_OPERATION,
        requestId: input.requestId,
        status: "completed",
        result,
        createdAt: now,
        updatedAt: now,
      });

      // Deliberately no write to:
      // - vending_machines/{machineId}
      // - machine_product_index
      // - vending_machines/{machineId}/revisions
      //
      // Receiving a report must never modify public data immediately.

      return result;
    },
  );
}

function resolveUserStatusWrite(
  exists: boolean,
  data: DocumentData | undefined,
): "none" | "initialize" {
  if (!exists) {
    return "initialize";
  }

  const status = data?.accountStatus;

  if (
    status === undefined ||
    status === null ||
    status === ""
  ) {
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
      "This account cannot submit vending-machine reports.",
      {
        appCode: "account-restricted",
        accountStatus: status,
      },
    );
  }

  throw new HttpsError(
    "permission-denied",
    "The account status is not valid for reports.",
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

function invalidStoredResult(): HttpsError {
  return new HttpsError(
    "internal",
    "Stored idempotency result is invalid.",
    {appCode: "idempotency-record-invalid"},
  );
}
