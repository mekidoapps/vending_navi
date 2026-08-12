import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {createVendingMachineForUser} from "./create_vending_machine";
import {buildHealthPayload} from "./health_payload";

function adminFirestore() {
  if (getApps().length === 0) {
    initializeApp();
  }
  return getFirestore();
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
    enforceAppCheck: false,
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
