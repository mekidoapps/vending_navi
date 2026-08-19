import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {shouldEnforceAppCheck} from "./app_check_policy";

import {createVendingMachineForUser} from "./create_vending_machine";
import {updateVendingMachineProductsForUser} from "./update_vending_machine_products";
import {addVendingMachinePhotoForUser} from "./add_vending_machine_photo";
import {submitMachineCorrectionForUser} from "./submit_machine_correction";
import {submitMachineReportForUser} from "./submit_machine_report";
import {recognizeVendingMachinePhotoForUser} from "./photo_recognition/recognize_vending_machine_photo";
import type {
  RecognitionProvider,
} from "./photo_recognition/recognition_provider";
import {
  createRecognitionProviderForEnvironment,
} from "./photo_recognition/recognition_provider_environment";
import {buildHealthPayload} from "./health_payload";

const enforceAppCheckForRuntime = shouldEnforceAppCheck(process.env);

function adminFirestore() {
  if (getApps().length === 0) {
    initializeApp();
  }
  return getFirestore();
}

function adminStorageBucket() {
  if (getApps().length === 0) {
    initializeApp();
  }
  return getStorage().bucket();
}

let recognitionProvider: RecognitionProvider | null = null;

function runtimeRecognitionProvider() {
  recognitionProvider ??=
    createRecognitionProviderForEnvironment(process.env);
  return recognitionProvider;
}

/**
 * Infrastructure-only callable used to confirm the local Functions emulator.
 * It performs no reads or writes and refuses execution outside the emulator.
 */
export const v2EmulatorHealth = onCall(() => {
  if (process.env.FUNCTIONS_EMULATOR !== "true") {
    throw new HttpsError(
      "failed-precondition",
      "v2EmulatorHealth is available only in the local emulator.",
    );
  }

  return buildHealthPayload();
});

/**
 * Formal v2 vending-machine creation entry point.
 *
 * Phase 6:
 * - email / Google authenticated callers
 * - manufacturer quick registration
 * - location-only registration
 * - server-derived geohash/evidence/status/history/index
 * - requestId idempotency
 *
 * Photo registration and App Check enforcement are connected in later phases.
 */
export const createVendingMachine = onCall(
  {
    enforceAppCheck: enforceAppCheckForRuntime,
  },
  async (request) => {
    if (request.auth === undefined) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required.",
      );
    }

    try {
      return await createVendingMachineForUser(
        adminFirestore(),
        adminStorageBucket(),
        request.auth.uid,
        request.data,
      );
    } catch (error: unknown) {
      if (error instanceof HttpsError) {
        throw error;
      }

      const requestId =
        typeof request.data === "object" &&
        request.data !== null &&
        "requestId" in request.data &&
        typeof request.data.requestId === "string" ?
          request.data.requestId :
          null;

      console.error("createVendingMachine failed.", {
        uid: request.auth.uid,
        requestId,
        errorName:
          error instanceof Error ? error.name : "UnknownError",
      });

      throw new HttpsError(
        "internal",
        "The vending machine could not be created.",
      );
    }
  },
);


/**
 * Phase 7 photo-recognition entry point.
 *
 * The client supplies only recognitionRequestId + uploadId.
 * Storage path, provider/model, master resolution and recognition session
 * are all server controlled.
 */
export const recognizeVendingMachinePhoto = onCall(
  {
    enforceAppCheck: enforceAppCheckForRuntime,
    timeoutSeconds: 60,
  },
  async (request) => {
    if (request.auth === undefined) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required.",
      );
    }

    try {
      return await recognizeVendingMachinePhotoForUser(
        adminFirestore(),
        adminStorageBucket(),
        runtimeRecognitionProvider(),
        request.auth.uid,
        request.data,
      );
    } catch (error: unknown) {
      if (error instanceof HttpsError) {
        throw error;
      }

      const recognitionRequestId =
        typeof request.data === "object" &&
        request.data !== null &&
        "recognitionRequestId" in request.data &&
        typeof request.data.recognitionRequestId === "string" ?
          request.data.recognitionRequestId :
          null;

      console.error("recognizeVendingMachinePhoto failed.", {
        uid: request.auth.uid,
        recognitionRequestId,
        errorName:
          error instanceof Error ? error.name : "UnknownError",
      });

      throw new HttpsError(
        "internal",
        "The vending machine photo could not be recognized.",
      );
    }
  },
);


/**
 * Phase 8 product-information update entry point.
 *
 * Public vending-machine writes remain server controlled.
 * Product state, revision and search index are committed atomically.
 */
export const updateVendingMachineProducts = onCall(
  {
    enforceAppCheck: enforceAppCheckForRuntime,
  },
  async (request) => {
    if (request.auth === undefined) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required.",
      );
    }

    try {
      return await updateVendingMachineProductsForUser(
        adminFirestore(),
        adminStorageBucket(),
        request.auth.uid,
        request.data,
      );
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      const requestId =
        typeof request.data === "object" &&
        request.data !== null &&
        "requestId" in request.data &&
        typeof request.data.requestId === "string"
          ? request.data.requestId
          : null;

      const machineId =
        typeof request.data === "object" &&
        request.data !== null &&
        "machineId" in request.data &&
        typeof request.data.machineId === "string"
          ? request.data.machineId
          : null;

      console.error("updateVendingMachineProducts failed.", {
        uid: request.auth.uid,
        requestId,
        machineId,
        errorName:
          error instanceof Error
            ? error.name
            : "UnknownError",
      });

      throw new HttpsError(
        "internal",
        "The vending machine products could not be updated.",
      );
    }
  },
);


/**
 * Phase 8 vending-machine photo-addition entry point.
 *
 * The client supplies only requestId + machineId + temporaryPhotoUploadId.
 * The server validates the exact recognized bytes, creates the formal photo
 * document/storage path, records a revision and performs request deduplication.
 */
export const addVendingMachinePhoto = onCall(
  {
    enforceAppCheck: enforceAppCheckForRuntime,
  },
  async (request) => {
    if (request.auth === undefined) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required.",
      );
    }

    try {
      return await addVendingMachinePhotoForUser(
        adminFirestore(),
        adminStorageBucket(),
        request.auth.uid,
        request.data,
      );
    } catch (error: unknown) {
      if (error instanceof HttpsError) {
        throw error;
      }

      const requestId =
        typeof request.data === "object" &&
        request.data !== null &&
        "requestId" in request.data &&
        typeof request.data.requestId === "string"
          ? request.data.requestId
          : null;

      const machineId =
        typeof request.data === "object" &&
        request.data !== null &&
        "machineId" in request.data &&
        typeof request.data.machineId === "string"
          ? request.data.machineId
          : null;

      console.error("addVendingMachinePhoto failed.", {
        uid: request.auth.uid,
        requestId,
        machineId,
        errorName:
          error instanceof Error
            ? error.name
            : "UnknownError",
      });

      throw new HttpsError(
        "internal",
        "The vending-machine photo could not be added.",
      );
    }
  },
);


/**
 * Phase 8 basic-information correction proposal entry point.
 *
 * High-impact vending-machine information is not overwritten immediately.
 * The callable stores a structured correction proposal for later review.
 */
export const submitMachineCorrection = onCall(
  {
    enforceAppCheck: enforceAppCheckForRuntime,
  },
  async (request) => {
    if (request.auth === undefined) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required.",
      );
    }

    try {
      return await submitMachineCorrectionForUser(
        adminFirestore(),
        request.auth.uid,
        request.data,
      );
    } catch (error: unknown) {
      if (error instanceof HttpsError) {
        throw error;
      }

      const requestId =
        typeof request.data === "object" &&
        request.data !== null &&
        "requestId" in request.data &&
        typeof request.data.requestId === "string"
          ? request.data.requestId
          : null;

      const machineId =
        typeof request.data === "object" &&
        request.data !== null &&
        "machineId" in request.data &&
        typeof request.data.machineId === "string"
          ? request.data.machineId
          : null;

      console.error("submitMachineCorrection failed.", {
        uid: request.auth.uid,
        requestId,
        machineId,
        errorName:
          error instanceof Error
            ? error.name
            : "UnknownError",
      });

      throw new HttpsError(
        "internal",
        "The vending-machine correction could not be submitted.",
      );
    }
  },
);


/**
 * Phase 8 vending-machine report entry point.
 *
 * Reports are moderation inputs only. Receiving a report must not
 * modify, hide or remove public vending-machine data automatically.
 */
export const submitMachineReport = onCall(
  {
    enforceAppCheck: enforceAppCheckForRuntime,
  },
  async (request) => {
    if (request.auth === undefined) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required.",
      );
    }

    try {
      return await submitMachineReportForUser(
        adminFirestore(),
        request.auth.uid,
        request.data,
      );
    } catch (error: unknown) {
      if (error instanceof HttpsError) {
        throw error;
      }

      const requestId =
        typeof request.data === "object" &&
        request.data !== null &&
        "requestId" in request.data &&
        typeof request.data.requestId === "string"
          ? request.data.requestId
          : null;

      const machineId =
        typeof request.data === "object" &&
        request.data !== null &&
        "machineId" in request.data &&
        typeof request.data.machineId === "string"
          ? request.data.machineId
          : null;

      console.error("submitMachineReport failed.", {
        uid: request.auth.uid,
        requestId,
        machineId,
        errorName:
          error instanceof Error
            ? error.name
            : "UnknownError",
      });

      throw new HttpsError(
        "internal",
        "Failed to submit the vending-machine report.",
        {appCode: "machine-report-failed"},
      );
    }
  },
);
