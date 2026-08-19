import {createHash} from "node:crypto";

import {
  Firestore,
  Timestamp,
} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

const ONE_HOUR_MS = 60 * 60 * 1000;

export const OPERATION_RATE_LIMIT_POLICIES = {
  createVendingMachine: {
    windowMs: ONE_HOUR_MS,
    maxRequests: 30,
  },
  recognizeVendingMachinePhoto: {
    windowMs: ONE_HOUR_MS,
    maxRequests: 20,
  },
  updateVendingMachineProducts: {
    windowMs: ONE_HOUR_MS,
    maxRequests: 60,
  },
  addVendingMachinePhoto: {
    windowMs: ONE_HOUR_MS,
    maxRequests: 30,
  },
  submitMachineCorrection: {
    windowMs: ONE_HOUR_MS,
    maxRequests: 30,
  },
  submitMachineReport: {
    windowMs: ONE_HOUR_MS,
    maxRequests: 30,
  },
} as const;

export type RateLimitedOperation =
  keyof typeof OPERATION_RATE_LIMIT_POLICIES;

export interface RateLimitWindow {
  readonly startedAtMs: number;
  readonly endsAtMs: number;
}

export function buildRateLimitWindow(
  nowMs: number,
  windowMs: number,
): RateLimitWindow {
  if (!Number.isFinite(nowMs) || nowMs < 0) {
    throw new TypeError("nowMs must be a non-negative finite number.");
  }

  if (!Number.isInteger(windowMs) || windowMs <= 0) {
    throw new TypeError("windowMs must be a positive integer.");
  }

  const startedAtMs =
    Math.floor(nowMs / windowMs) * windowMs;

  return {
    startedAtMs,
    endsAtMs: startedAtMs + windowMs,
  };
}

export function buildOperationRateLimitDocumentId(
  uid: string,
  operation: RateLimitedOperation,
): string {
  const normalizedUid = uid.trim();

  if (normalizedUid.length === 0) {
    throw new TypeError("uid is required.");
  }

  return createHash("sha256")
    .update(`operationRateLimit:${normalizedUid}:${operation}`)
    .digest("hex");
}

export async function enforceOperationRateLimit(
  firestore: Firestore,
  uid: string,
  operation: RateLimitedOperation,
  nowMs = Date.now(),
): Promise<void> {
  const normalizedUid = uid.trim();

  if (normalizedUid.length === 0) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required.",
    );
  }

  const policy = OPERATION_RATE_LIMIT_POLICIES[operation];
  const window = buildRateLimitWindow(nowMs, policy.windowMs);

  const documentId =
    buildOperationRateLimitDocumentId(normalizedUid, operation);

  const ref = firestore
    .collection("operation_rate_limits")
    .doc(documentId);

  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);

    let currentCount = 0;

    if (snapshot.exists) {
      const data = snapshot.data();
      const storedWindowStartedAt = data?.windowStartedAt;

      const isCurrentWindow =
        storedWindowStartedAt instanceof Timestamp &&
        storedWindowStartedAt.toMillis() === window.startedAtMs;

      if (isCurrentWindow) {
        const storedCount = data?.count;

        if (
          !Number.isInteger(storedCount) ||
          storedCount < 0
        ) {
          throw new HttpsError(
            "internal",
            "The rate-limit state is invalid.",
            {appCode: "rate-limit-state-invalid"},
          );
        }

        currentCount = storedCount;
      }
    }

    if (currentCount >= policy.maxRequests) {
      const retryAfterSeconds = Math.max(
        1,
        Math.ceil((window.endsAtMs - nowMs) / 1000),
      );

      throw new HttpsError(
        "resource-exhausted",
        "Too many requests. Please try again later.",
        {
          appCode: "rate-limit-exceeded",
          retryAfterSeconds,
        },
      );
    }

    transaction.set(ref, {
      uid: normalizedUid,
      operation,
      windowStartedAt: Timestamp.fromMillis(
        window.startedAtMs,
      ),
      windowEndsAt: Timestamp.fromMillis(
        window.endsAtMs,
      ),
      count: currentCount + 1,
      updatedAt: Timestamp.fromMillis(nowMs),
    });
  });
}
