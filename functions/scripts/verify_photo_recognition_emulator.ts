import {createHash, randomUUID} from "node:crypto";
import {readFile} from "node:fs/promises";
import path from "node:path";

import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";

const PROJECT_ID = "vendingnavi";
const STORAGE_BUCKET = "vendingnavi.firebasestorage.app";
const AUTH_EMULATOR = "127.0.0.1:9099";
const FIRESTORE_EMULATOR = "127.0.0.1:8080";
const STORAGE_EMULATOR = "127.0.0.1:9199";
const FUNCTIONS_BASE =
  `http://127.0.0.1:5001/${PROJECT_ID}/us-central1`;
const PROVIDER_KEY = "emulator_photo_recognition_fixture";

interface AuthSignUpResponse {
  readonly idToken?: string;
  readonly localId?: string;
  readonly error?: {
    readonly message?: string;
  };
}

interface CallableEnvelope<T> {
  readonly result?: T;
  readonly data?: T;
  readonly error?: unknown;
}

interface RecognitionResponse {
  readonly manufacturerCandidates: readonly {
    readonly manufacturerId: string;
  }[];
  readonly productCandidates: readonly {
    readonly productId: string;
  }[];
  readonly unresolvedLabels: readonly string[];
  readonly recognitionStatus: "completed" | "failed";
}

function requireEmulatorEnvironment(): void {
  const required = new Map([
    ["FIREBASE_AUTH_EMULATOR_HOST", AUTH_EMULATOR],
    ["FIRESTORE_EMULATOR_HOST", FIRESTORE_EMULATOR],
    ["FIREBASE_STORAGE_EMULATOR_HOST", STORAGE_EMULATOR],
  ]);

  for (const [key, expected] of required) {
    if (process.env[key] !== expected) {
      throw new Error(
        `${key} must be exactly "${expected}" for this emulator-only script.`,
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

function sha256(value: string | Buffer): string {
  return createHash("sha256").update(value).digest("hex");
}

async function createEmulatorUser(): Promise<{
  readonly uid: string;
  readonly idToken: string;
}> {
  const email = `p710-${Date.now()}-${randomUUID().slice(0, 8)}@example.com`;
  const password = "Test123456!";

  const response = await fetch(
    `http://${AUTH_EMULATOR}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
    {
      method: "POST",
      headers: {"content-type": "application/json"},
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

async function callRecognition(
  idToken: string,
  recognitionRequestId: string,
  uploadId: string,
): Promise<RecognitionResponse> {
  const response = await fetch(
    `${FUNCTIONS_BASE}/recognizeVendingMachinePhoto`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${idToken}`,
      },
      body: JSON.stringify({
        data: {
          recognitionRequestId,
          uploadId,
        },
      }),
    },
  );

  const envelope =
    await response.json() as CallableEnvelope<RecognitionResponse>;

  if (!response.ok || envelope.error !== undefined) {
    throw new Error(
      `Callable failed (${response.status}): ${JSON.stringify(envelope)}`,
    );
  }

  const result = envelope.result ?? envelope.data;
  if (result === undefined) {
    throw new Error(
      `Callable returned no result: ${JSON.stringify(envelope)}`,
    );
  }

  return result;
}

async function main(): Promise<void> {
  requireEmulatorEnvironment();

  const imageArg = process.argv[2];
  if (imageArg === undefined) {
    throw new Error(
      'Usage: node lib/scripts/verify_photo_recognition_emulator.js "C:/path/to/vending.jpg"',
    );
  }

  const imagePath = path.resolve(imageArg);
  const imageBytes = await readFile(imagePath);
  if (imageBytes.length === 0 || imageBytes.length > 5 * 1024 * 1024) {
    throw new Error(
      `Test JPEG must be between 1 byte and 5 MiB; got ${imageBytes.length}.`,
    );
  }
  const expectedContentSha256 = sha256(imageBytes);

  const app =
    getApps().find((candidate) => candidate.name === "p710-e2e") ??
    initializeApp(
      {
        projectId: PROJECT_ID,
        storageBucket: STORAGE_BUCKET,
      },
      "p710-e2e",
    );

  const firestore = getFirestore(app);
  const bucket = getStorage(app).bucket(STORAGE_BUCKET);

  const manufacturerProbe = await firestore
    .collection("manufacturers")
    .limit(1)
    .get();
  const productProbe = await firestore
    .collection("products")
    .limit(1)
    .get();

  if (manufacturerProbe.empty || productProbe.empty) {
    throw new Error(
      "Master fixture is missing. Run the existing seed_master_fixture script first.",
    );
  }

  const {uid, idToken} = await createEmulatorUser();
  const uploadId = randomUUID();
  const recognitionRequestId = randomUUID();
  const objectPath =
    `machine_uploads/${uid}/${uploadId}/original.jpg`;

  await bucket.file(objectPath).save(imageBytes, {
    resumable: false,
    metadata: {
      contentType: "image/jpeg",
    },
  });

  console.log("=== P7-11 PHOTO BINDING E2E ===");
  console.log(`uid=${uid}`);
  console.log(`uploadId=${uploadId}`);
  console.log(`recognitionRequestId=${recognitionRequestId}`);
  console.log(`objectPath=${objectPath}`);
  console.log("");

  const first = await callRecognition(
    idToken,
    recognitionRequestId,
    uploadId,
  );

  console.log("=== FIRST CALL ===");
  console.log(JSON.stringify(first, null, 2));

  if (first.recognitionStatus !== "completed") {
    throw new Error(
      `Expected completed recognition; got ${first.recognitionStatus}.`,
    );
  }

  const sessionId = sha256(`photoRecognitionSession:${uid}:${uploadId}`);
  const operationId = sha256(
    `recognizeVendingMachinePhoto:${uid}:${recognitionRequestId}`,
  );

  const sessionRef = firestore
    .collection("photo_recognition_sessions")
    .doc(sessionId);
  const operationRef = firestore
    .collection("request_deduplication")
    .doc(operationId);

  const sessionAfterFirst = await sessionRef.get();
  const operationAfterFirst = await operationRef.get();

  if (!sessionAfterFirst.exists) {
    throw new Error("Recognition session was not stored.");
  }
  if (!operationAfterFirst.exists) {
    throw new Error("Recognition operation was not stored.");
  }

  const sessionData = sessionAfterFirst.data();
  if (
    sessionData?.status !== "completed" ||
    sessionData?.provider !== PROVIDER_KEY ||
    sessionData?.uid !== uid ||
    sessionData?.uploadId !== uploadId ||
    sessionData?.photoObjectPath !== objectPath ||
    sessionData?.photoContentSha256 !== expectedContentSha256 ||
    sessionData?.photoSizeBytes !== imageBytes.length
  ) {
    throw new Error(
      `Recognition session/photo binding is invalid: ${JSON.stringify(sessionData)}`,
    );
  }

  const sessionUpdateTimeBefore =
    sessionAfterFirst.updateTime?.toMillis() ?? null;
  const operationUpdateTimeBefore =
    operationAfterFirst.updateTime?.toMillis() ?? null;

  const second = await callRecognition(
    idToken,
    recognitionRequestId,
    uploadId,
  );

  console.log("");
  console.log("=== SECOND CALL (SAME REQUEST ID) ===");
  console.log(JSON.stringify(second, null, 2));

  if (JSON.stringify(second) !== JSON.stringify(first)) {
    throw new Error(
      "Idempotent replay response differs from the first response.",
    );
  }

  const sessionAfterSecond = await sessionRef.get();
  const operationAfterSecond = await operationRef.get();

  const sessionUpdateTimeAfter =
    sessionAfterSecond.updateTime?.toMillis() ?? null;
  const operationUpdateTimeAfter =
    operationAfterSecond.updateTime?.toMillis() ?? null;

  if (
    sessionUpdateTimeAfter !== sessionUpdateTimeBefore ||
    operationUpdateTimeAfter !== operationUpdateTimeBefore
  ) {
    throw new Error(
      "Replay unexpectedly rewrote session/operation; AI may have rerun.",
    );
  }

  console.log("");
  console.log("=== VERIFIED ===");
  console.log("recognitionStatus=completed");
  console.log(`provider=${PROVIDER_KEY}`);
  console.log("sessionStored=true");
  console.log("photoContentSha256Bound=true");
  console.log("sameRequestReplayStable=true");
  console.log("storageUploadTarget=emulator");
  console.log("firestoreTarget=emulator");
}

main().catch((error: unknown) => {
  console.error("P7_11_E2E_FAILED");
  if (error instanceof Error) {
    console.error(`${error.name}: ${error.message}`);
  } else {
    console.error(String(error));
  }
  process.exitCode = 1;
});
