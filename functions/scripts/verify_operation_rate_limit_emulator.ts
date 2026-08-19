import {randomUUID} from "node:crypto";

import {getApps, initializeApp} from "firebase-admin/app";
import {
  Firestore,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";

import {
  OPERATION_RATE_LIMIT_POLICIES,
  buildOperationRateLimitDocumentId,
  buildRateLimitWindow,
} from "../src/operation_rate_limit";

const PROJECT_ID = "vendingnavi";
const AUTH_EMULATOR = "127.0.0.1:9099";
const FIRESTORE_EMULATOR = "127.0.0.1:8080";
const FUNCTIONS_BASE =
  `http://127.0.0.1:5001/${PROJECT_ID}/us-central1`;

interface EmulatorUser {
  readonly uid: string;
  readonly idToken: string;
}

interface AuthSignUpResponse {
  readonly idToken?: string;
  readonly localId?: string;
  readonly error?: {
    readonly message?: string;
  };
}

interface CallableError {
  readonly status?: string;
  readonly message?: string;
  readonly details?: {
    readonly appCode?: string;
    readonly retryAfterSeconds?: number;
  };
}

interface CallableEnvelope {
  readonly data?: unknown;
  readonly result?: unknown;
  readonly error?: CallableError;
}

interface CallableResult {
  readonly httpStatus: number;
  readonly body: CallableEnvelope;
}

function requireEnvironment(): void {
  const required = new Map([
    ["FIREBASE_AUTH_EMULATOR_HOST", AUTH_EMULATOR],
    ["FIRESTORE_EMULATOR_HOST", FIRESTORE_EMULATOR],
  ]);

  for (const [key, expected] of required) {
    if (process.env[key] !== expected) {
      throw new Error(
        `${key} must be exactly "${expected}".`,
      );
    }
  }

  if (
    process.env.GCLOUD_PROJECT !== PROJECT_ID &&
    process.env.GOOGLE_CLOUD_PROJECT !== PROJECT_ID
  ) {
    throw new Error(
      `Set GCLOUD_PROJECT=${PROJECT_ID} or ` +
      `GOOGLE_CLOUD_PROJECT=${PROJECT_ID}.`,
    );
  }
}

function adminFirestore(): Firestore {
  if (getApps().length === 0) {
    initializeApp({
      projectId: PROJECT_ID,
    });
  }

  return getFirestore();
}

async function createEmulatorUser(): Promise<EmulatorUser> {
  const email =
    `p904-${Date.now()}-${randomUUID().slice(0, 8)}@example.com`;
  const password = "Test123456!";

  const response = await fetch(
    `http://${AUTH_EMULATOR}` +
    "/identitytoolkit.googleapis.com/v1/accounts:signUp" +
    "?key=fake-api-key",
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
      body: JSON.stringify({
        email,
        password,
        returnSecureToken: true,
      }),
    },
  );

  const body = await response.json() as AuthSignUpResponse;

  if (
    !response.ok ||
    typeof body.idToken !== "string" ||
    typeof body.localId !== "string"
  ) {
    throw new Error(
      `Auth emulator sign-up failed: ${JSON.stringify(body)}`,
    );
  }

  return {
    uid: body.localId,
    idToken: body.idToken,
  };
}

async function callCallable(
  functionName: string,
  idToken: string,
  data: unknown,
): Promise<CallableResult> {
  const response = await fetch(
    `${FUNCTIONS_BASE}/${functionName}`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${idToken}`,
      },
      body: JSON.stringify({data}),
    },
  );

  const body = await response.json() as CallableEnvelope;

  return {
    httpStatus: response.status,
    body,
  };
}

function errorStatus(result: CallableResult): string | null {
  return result.body.error?.status ?? null;
}

function assertNotRateLimited(
  result: CallableResult,
  context: string,
): void {
  if (errorStatus(result) === "RESOURCE_EXHAUSTED") {
    throw new Error(
      `${context} was unexpectedly rate limited: ` +
      JSON.stringify(result.body),
    );
  }
}

async function verifyClientRulesDenied(
  user: EmulatorUser,
  documentId: string,
): Promise<void> {
  const base =
    `http://${FIRESTORE_EMULATOR}/v1/projects/${PROJECT_ID}` +
    "/databases/(default)/documents/operation_rate_limits/" +
    encodeURIComponent(documentId);

  const readResponse = await fetch(base, {
    headers: {
      authorization: `Bearer ${user.idToken}`,
    },
  });

  if (readResponse.status !== 403) {
    throw new Error(
      "Authenticated client read of operation_rate_limits " +
      `must be denied; got HTTP ${readResponse.status}.`,
    );
  }

  const writeResponse = await fetch(
    `${base}?updateMask.fieldPaths=count`,
    {
      method: "PATCH",
      headers: {
        authorization: `Bearer ${user.idToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        fields: {
          count: {
            integerValue: "999",
          },
        },
      }),
    },
  );

  if (writeResponse.status !== 403) {
    throw new Error(
      "Authenticated client write of operation_rate_limits " +
      `must be denied; got HTTP ${writeResponse.status}.`,
    );
  }
}

async function main(): Promise<void> {
  requireEnvironment();

  const firestore = adminFirestore();

  const primaryUser = await createEmulatorUser();
  const secondaryUser = await createEmulatorUser();

  const reportPolicy =
    OPERATION_RATE_LIMIT_POLICIES.submitMachineReport;

  console.log("=== P9-04 RATE LIMIT E2E ===");
  console.log(`primaryUid=${primaryUser.uid}`);
  console.log(`secondaryUid=${secondaryUser.uid}`);
  console.log(
    `reportLimit=${reportPolicy.maxRequests}/${reportPolicy.windowMs}ms`,
  );
  console.log("");

  // Deliberately invalid business payload.
  //
  // Rate limiting happens before business-input validation, so these requests
  // consume quota without creating report documents or mutating public data.
  const invalidPayload = {};

  for (
    let index = 1;
    index <= reportPolicy.maxRequests;
    index += 1
  ) {
    const result = await callCallable(
      "submitMachineReport",
      primaryUser.idToken,
      invalidPayload,
    );

    assertNotRateLimited(
      result,
      `request ${index}/${reportPolicy.maxRequests}`,
    );
  }

  console.log(
    `UNDER_LIMIT_VERIFIED count=${reportPolicy.maxRequests}`,
  );

  const exceeded = await callCallable(
    "submitMachineReport",
    primaryUser.idToken,
    invalidPayload,
  );

  if (
    errorStatus(exceeded) !== "RESOURCE_EXHAUSTED" ||
    exceeded.body.error?.details?.appCode !==
      "rate-limit-exceeded"
  ) {
    throw new Error(
      "Expected RESOURCE_EXHAUSTED / rate-limit-exceeded: " +
      JSON.stringify(exceeded.body),
    );
  }

  const retryAfterSeconds =
    exceeded.body.error.details.retryAfterSeconds;

  if (
    typeof retryAfterSeconds !== "number" ||
    retryAfterSeconds < 1
  ) {
    throw new Error(
      "retryAfterSeconds must be a positive number.",
    );
  }

  console.log(
    `LIMIT_EXCEEDED_VERIFIED retryAfterSeconds=${retryAfterSeconds}`,
  );

  // Same operation, different user: independent quota.
  const secondaryReport = await callCallable(
    "submitMachineReport",
    secondaryUser.idToken,
    invalidPayload,
  );

  assertNotRateLimited(
    secondaryReport,
    "different user / same operation",
  );

  console.log("USER_ISOLATION_VERIFIED");

  // Same user, different operation: independent quota.
  const correctionResult = await callCallable(
    "submitMachineCorrection",
    primaryUser.idToken,
    invalidPayload,
  );

  assertNotRateLimited(
    correctionResult,
    "same user / different operation",
  );

  console.log("OPERATION_ISOLATION_VERIFIED");

  const reportDocumentId =
    buildOperationRateLimitDocumentId(
      primaryUser.uid,
      "submitMachineReport",
    );

  // Clients must never access this internal collection.
  await verifyClientRulesDenied(
    primaryUser,
    reportDocumentId,
  );

  console.log("CLIENT_RULES_DENIED_VERIFIED");

  // Simulate an expired fixed window through Admin SDK.
  const nowMs = Date.now();
  const currentWindow = buildRateLimitWindow(
    nowMs,
    reportPolicy.windowMs,
  );

  const reportRef = firestore
    .collection("operation_rate_limits")
    .doc(reportDocumentId);

  await reportRef.set({
    uid: primaryUser.uid,
    operation: "submitMachineReport",
    windowStartedAt: Timestamp.fromMillis(
      currentWindow.startedAtMs - reportPolicy.windowMs,
    ),
    windowEndsAt: Timestamp.fromMillis(
      currentWindow.startedAtMs,
    ),
    count: reportPolicy.maxRequests,
    updatedAt: Timestamp.fromMillis(
      currentWindow.startedAtMs - 1,
    ),
  });

  const afterWindowChange = await callCallable(
    "submitMachineReport",
    primaryUser.idToken,
    invalidPayload,
  );

  assertNotRateLimited(
    afterWindowChange,
    "new fixed window",
  );

  const snapshot = await reportRef.get();
  const data = snapshot.data();

  if (
    data?.count !== 1 ||
    !(data?.windowStartedAt instanceof Timestamp) ||
    data.windowStartedAt.toMillis() !==
      currentWindow.startedAtMs
  ) {
    throw new Error(
      "Fixed-window reset state is invalid: " +
      JSON.stringify(data),
    );
  }

  console.log("WINDOW_RESET_VERIFIED");
  console.log("");
  console.log(
    "P9_04_RATE_LIMIT_VERIFIED " +
    "underLimit=ok " +
    "limitExceeded=ok " +
    "userIsolation=ok " +
    "operationIsolation=ok " +
    "windowReset=ok " +
    "clientRulesDenied=ok",
  );
}

main().catch((error: unknown) => {
  console.error("");
  console.error("P9_04_RATE_LIMIT_FAILED");

  if (error instanceof Error) {
    console.error(error.stack ?? error.message);
  } else {
    console.error(error);
  }

  process.exitCode = 1;
});
