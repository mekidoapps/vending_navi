import {randomUUID} from "node:crypto";

import {
  getApps,
  initializeApp,
} from "firebase-admin/app";
import {
  GeoPoint,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";

import {
  buildMachineReportDeduplicationId,
} from "../src/submit_machine_report_core";

const PROJECT_ID =
  process.env.GCLOUD_PROJECT ?? "vendingnavi";

const AUTH_EMULATOR =
  process.env.FIREBASE_AUTH_EMULATOR_HOST ??
  "127.0.0.1:9099";

const FIRESTORE_EMULATOR =
  process.env.FIRESTORE_EMULATOR_HOST ??
  "127.0.0.1:8080";

const FUNCTIONS_EMULATOR =
  process.env.FUNCTIONS_EMULATOR_HOST ??
  "127.0.0.1:5001";

const FUNCTIONS_BASE =
  `http://${FUNCTIONS_EMULATOR}` +
  `/${PROJECT_ID}/us-central1`;

const FIRESTORE_REST_BASE =
  `http://${FIRESTORE_EMULATOR}` +
  `/v1/projects/${PROJECT_ID}` +
  `/databases/(default)/documents`;

const PREFERRED_MACHINE_ID =
  "machine_v2_station_east";

const LEGACY_MACHINE_ID =
  "machine_p806_legacy";

const FOREIGN_MACHINE_ID =
  "machine_p806_foreign";

const LOCAL_PHOTO_ID =
  `p_${"a".repeat(30)}`;

const FOREIGN_PHOTO_ID =
  `p_${"b".repeat(30)}`;

const MISSING_PHOTO_ID =
  `p_${"c".repeat(30)}`;

const DIRECT_WRITE_ID =
  "client_direct_p806_report";

interface AuthResult {
  readonly uid: string;
  readonly idToken: string;
}

interface CallableEnvelope<T> {
  readonly result?: T;
  readonly data?: T;
  readonly error?: unknown;
}

interface ReportResult {
  readonly machineId: string;
  readonly reportId: string;
  readonly submitted: true;
}

function configureEnvironment(): void {
  process.env.GCLOUD_PROJECT = PROJECT_ID;
  process.env.GOOGLE_CLOUD_PROJECT = PROJECT_ID;
  process.env.FIREBASE_AUTH_EMULATOR_HOST =
    AUTH_EMULATOR;
  process.env.FIRESTORE_EMULATOR_HOST =
    FIRESTORE_EMULATOR;
}

async function main(): Promise<void> {
  configureEnvironment();

  const app =
    getApps().find(
      (item) => item.name === "p806-report-e2e",
    ) ??
    initializeApp(
      {projectId: PROJECT_ID},
      "p806-report-e2e",
    );

  const firestore = getFirestore(app);

  const machine =
    await findActiveV2Machine(firestore);

  const machineRef = firestore
    .collection("vending_machines")
    .doc(machine.id);

  const auth = await createEmulatorUser();

  const successfulRequestIds: string[] = [];
  const reportIds: string[] = [];

  try {
    console.log(
      "=== P8-06 MACHINE REPORT E2E ===",
    );
    console.log(`uid=${auth.uid}`);
    console.log(`machine=${machine.id}`);

    await prepareSpecialFixtures(
      firestore,
      machine.id,
    );

    const beforeMachine =
      await machineRef.get();

    assert(
      beforeMachine.exists,
      "Target machine must exist.",
    );

    const beforeMachineData =
      beforeMachine.data();

    assert(
      beforeMachineData !== undefined,
      "Target machine data must exist.",
    );

    const beforeRevisionCount =
      (
        await machineRef
          .collection("revisions")
          .get()
      ).size;

    const beforeIndexes =
      await readMachineIndexes(
        firestore,
        machine.id,
      );

    const beforeReportCount =
      await countMachineReports(
        firestore,
        machine.id,
      );

    // ======================================================
    // 1. Valid machine report
    // ======================================================

    const requestId = randomUUID();

    successfulRequestIds.push(requestId);

    const input = {
      requestId,
      machineId: machine.id,
      photoId: null,
      category: "machineRemoved",
      message: "P8-06 Emulator verification",
    };

    const result =
      await callFunction<ReportResult>(
        "submitMachineReport",
        auth.idToken,
        input,
      );

    reportIds.push(result.reportId);

    assert(
      result.machineId === machine.id,
      "Result machineId must match.",
    );

    assert(
      result.submitted === true,
      "Report must be submitted.",
    );

    assert(
      /^r_[0-9a-f]{30}$/.test(
        result.reportId,
      ),
      "Report ID must use deterministic format.",
    );

    const reportRef = firestore
      .collection("machine_reports")
      .doc(result.reportId);

    const report =
      await reportRef.get();

    assert(
      report.exists,
      "Report document must exist.",
    );

    const reportData =
      report.data() ?? {};

    assert(
      reportData.machineId === machine.id,
      "Report machineId must match.",
    );

    assert(
      reportData.photoId === null,
      "Machine report must store null photoId.",
    );

    assert(
      reportData.category === "machineRemoved",
      "Report category must be stored.",
    );

    assert(
      reportData.message ===
        "P8-06 Emulator verification",
      "Report message must be stored.",
    );

    assert(
      reportData.status === "new",
      "Report status must be new.",
    );

    assert(
      reportData.reportedBy === auth.uid,
      "Report reportedBy must match UID.",
    );

    assert(
      reportData.requestId === requestId,
      "Report requestId must be stored.",
    );

    assert(
      reportData.createdAt instanceof Timestamp,
      "Report createdAt must be Timestamp.",
    );

    assert(
      reportData.reviewedAt === null,
      "New report must not be reviewed.",
    );

    assert(
      reportData.reviewedBy === null,
      "New report must not have reviewer.",
    );

    assert(
      reportData.resolution === null,
      "New report must not have resolution.",
    );

    // ======================================================
    // 2. Public data must remain unchanged.
    // ======================================================

    const afterMachine =
      await machineRef.get();

    assert(
      canonicalize(beforeMachineData) ===
        canonicalize(afterMachine.data() ?? {}),
      "Report must not change vending-machine public data.",
    );

    const afterRevisionCount =
      (
        await machineRef
          .collection("revisions")
          .get()
      ).size;

    assert(
      afterRevisionCount === beforeRevisionCount,
      "Report must not create a revision.",
    );

    const afterIndexes =
      await readMachineIndexes(
        firestore,
        machine.id,
      );

    assert(
      JSON.stringify(afterIndexes) ===
        JSON.stringify(beforeIndexes),
      "Report must not change machine_product_index.",
    );

    const afterReportCount =
      await countMachineReports(
        firestore,
        machine.id,
      );

    assert(
      afterReportCount ===
        beforeReportCount + 1,
      "Valid request must create exactly one report.",
    );

    // ======================================================
    // 3. Same requestId replay
    // ======================================================

    const replay =
      await callFunction<ReportResult>(
        "submitMachineReport",
        auth.idToken,
        input,
      );

    assert(
      replay.reportId === result.reportId,
      "Replay must return same reportId.",
    );

    assert(
      await countMachineReports(
        firestore,
        machine.id,
      ) === afterReportCount,
      "Replay must not create another report.",
    );

    const dedupeId =
      buildMachineReportDeduplicationId(
        auth.uid,
        requestId,
      );

    const dedupe =
      await firestore
        .collection("request_deduplication")
        .doc(dedupeId)
        .get();

    assert(
      dedupe.exists,
      "Idempotency record must exist.",
    );

    assert(
      dedupe.data()?.operation ===
        "submitMachineReport",
      "Idempotency operation must match.",
    );

    // ======================================================
    // 4. Valid photo report
    // ======================================================

    const photoRequestId = randomUUID();

    successfulRequestIds.push(photoRequestId);

    const photoResult =
      await callFunction<ReportResult>(
        "submitMachineReport",
        auth.idToken,
        {
          requestId: photoRequestId,
          machineId: machine.id,
          photoId: LOCAL_PHOTO_ID,
          category: "inappropriatePhoto",
          message: "P8-06 photo verification",
        },
      );

    reportIds.push(photoResult.reportId);

    const photoReport =
      await firestore
        .collection("machine_reports")
        .doc(photoResult.reportId)
        .get();

    assert(
      photoReport.exists,
      "Photo report must be stored.",
    );

    assert(
      photoReport.data()?.photoId ===
        LOCAL_PHOTO_ID,
      "Report must store target photoId.",
    );

    assert(
      photoReport.data()?.category ===
        "inappropriatePhoto",
      "Photo report category must be stored.",
    );

    // ======================================================
    // 5. Foreign photo must be rejected.
    // ======================================================

    const foreignPhoto =
      await rawCallable<ReportResult>(
        "submitMachineReport",
        auth.idToken,
        {
          requestId: randomUUID(),
          machineId: machine.id,
          photoId: FOREIGN_PHOTO_ID,
          category: "inappropriatePhoto",
          message: null,
        },
      );

    assert(
      foreignPhoto.error !== undefined,
      "Photo belonging to another machine must be rejected.",
    );

    // ======================================================
    // 6. Missing photo must be rejected.
    // ======================================================

    const missingPhoto =
      await rawCallable<ReportResult>(
        "submitMachineReport",
        auth.idToken,
        {
          requestId: randomUUID(),
          machineId: machine.id,
          photoId: MISSING_PHOTO_ID,
          category: "inappropriatePhoto",
          message: null,
        },
      );

    assert(
      missingPhoto.error !== undefined,
      "Missing photo must be rejected.",
    );

    // ======================================================
    // 7. Legacy machine must be rejected.
    // ======================================================

    const legacy =
      await rawCallable<ReportResult>(
        "submitMachineReport",
        auth.idToken,
        {
          requestId: randomUUID(),
          machineId: LEGACY_MACHINE_ID,
          photoId: null,
          category: "other",
          message: "legacy report",
        },
      );

    assert(
      legacy.error !== undefined,
      "Legacy vending machine must be rejected.",
    );

    // ======================================================
    // 8. Unauthenticated request must be rejected.
    // ======================================================

    const unauthenticated =
      await rawCallable<ReportResult>(
        "submitMachineReport",
        null,
        {
          requestId: randomUUID(),
          machineId: machine.id,
          photoId: null,
          category: "other",
          message: null,
        },
      );

    assert(
      unauthenticated.error !== undefined,
      "Unauthenticated report must be rejected.",
    );

    // ======================================================
    // 9. Restricted account must be rejected.
    // ======================================================

    await firestore
      .collection("users")
      .doc(auth.uid)
      .set(
        {accountStatus: "restricted"},
        {merge: true},
      );

    const restricted =
      await rawCallable<ReportResult>(
        "submitMachineReport",
        auth.idToken,
        {
          requestId: randomUUID(),
          machineId: machine.id,
          photoId: null,
          category: "other",
          message: null,
        },
      );

    assert(
      restricted.error !== undefined,
      "Restricted account must be rejected.",
    );

    await firestore
      .collection("users")
      .doc(auth.uid)
      .set(
        {accountStatus: "active"},
        {merge: true},
      );

    // ======================================================
    // 10. Direct Firestore client write must be denied.
    // ======================================================

    const directWriteStatus =
      await attemptDirectClientReportWrite(
        auth.idToken,
        machine.id,
      );

    assert(
      directWriteStatus === 403 ||
        directWriteStatus === 401,
      `Direct client report write must be denied, status=${directWriteStatus}.`,
    );

    // Re-check public state after every report/error path.
    const finalMachine =
      await machineRef.get();

    assert(
      canonicalize(beforeMachineData) ===
        canonicalize(finalMachine.data() ?? {}),
      "Report paths must never change public machine data.",
    );

    assert(
      (
        await machineRef
          .collection("revisions")
          .get()
      ).size === beforeRevisionCount,
      "Report paths must never create revisions.",
    );

    assert(
      JSON.stringify(
        await readMachineIndexes(
          firestore,
          machine.id,
        ),
      ) === JSON.stringify(beforeIndexes),
      "Report paths must never alter index data.",
    );

    console.log(
      [
        "P8-06B3 VERIFIED",
        "reportStored=ok",
        "publicMachineUnchanged=ok",
        "revisionUnchanged=ok",
        "indexUnchanged=ok",
        "idempotency=ok",
        "photoBelongsToMachine=ok",
        "foreignPhotoRejected=ok",
        "missingPhotoRejected=ok",
        "legacyRejected=ok",
        "unauthenticatedRejected=ok",
        "restrictedAccount=ok",
        "clientWritesDenied=ok",
      ].join(" "),
    );
  } finally {
    for (const reportId of reportIds) {
      await firestore
        .collection("machine_reports")
        .doc(reportId)
        .delete()
        .catch(() => undefined);
    }

    for (
      const requestId of
        successfulRequestIds
    ) {
      const dedupeId =
        buildMachineReportDeduplicationId(
          auth.uid,
          requestId,
        );

      await firestore
        .collection("request_deduplication")
        .doc(dedupeId)
        .delete()
        .catch(() => undefined);
    }

    await firestore
      .collection("machine_reports")
      .doc(DIRECT_WRITE_ID)
      .delete()
      .catch(() => undefined);

    await cleanupSpecialFixtures(
      firestore,
      machine.id,
    );

    await firestore
      .collection("users")
      .doc(auth.uid)
      .delete()
      .catch(() => undefined);

    await deleteEmulatorUserBestEffort(
      auth.idToken,
    );
  }
}

async function findActiveV2Machine(
  firestore: ReturnType<typeof getFirestore>,
): Promise<{readonly id: string}> {
  const preferred =
    await firestore
      .collection("vending_machines")
      .doc(PREFERRED_MACHINE_ID)
      .get();

  const preferredData =
    preferred.data();

  if (
    preferred.exists &&
    preferredData?.schemaVersion === 2 &&
    preferredData.status === "active"
  ) {
    return {id: preferred.id};
  }

  const snapshot =
    await firestore
      .collection("vending_machines")
      .limit(100)
      .get();

  for (const document of snapshot.docs) {
    const data = document.data();

    if (
      data.schemaVersion === 2 &&
      data.status === "active"
    ) {
      return {id: document.id};
    }
  }

  throw new Error(
    "No active v2 vending-machine fixture found. Seed vending_machine_fixture first.",
  );
}

async function prepareSpecialFixtures(
  firestore: ReturnType<typeof getFirestore>,
  machineId: string,
): Promise<void> {
  const now = Timestamp.now();

  await firestore
    .collection("vending_machines")
    .doc(machineId)
    .collection("photos")
    .doc(LOCAL_PHOTO_ID)
    .set({
      storagePath:
        `vending_machines/${machineId}/photos/${LOCAL_PHOTO_ID}/original.jpg`,
      thumbnailPath: null,
      status: "active",
      uploadedBy: "p806_verifier",
      uploadedAt: now,
      recognitionStatus: "completed",
      recognitionProvider: "fixture",
      isPrimary: false,
    });

  await firestore
    .collection("vending_machines")
    .doc(LEGACY_MACHINE_ID)
    .set({
      name: "P8-06 legacy machine",
      manufacturer: "legacy",
      lat: 35.0,
      lng: 139.0,
      createdAt: now,
      updatedAt: now,
    });

  const foreignRef = firestore
    .collection("vending_machines")
    .doc(FOREIGN_MACHINE_ID);

  await foreignRef.set({
    schemaVersion: 2,
    name: "P8-06 foreign machine",
    manufacturerId: null,
    manufacturerStatus: "unknown",
    location: new GeoPoint(35.0, 139.0),
    geohash: "xn4z55",
    placeDescription: null,
    installationType: "unknown",
    status: "active",
    mergedIntoMachineId: null,
    dataLevel: "locationOnly",
    primaryPhotoId: FOREIGN_PHOTO_ID,
    createdBy: "p806_verifier",
    createdAt: now,
    updatedAt: now,
    lastProductUpdatedAt: null,
  });

  await foreignRef
    .collection("photos")
    .doc(FOREIGN_PHOTO_ID)
    .set({
      storagePath:
        `vending_machines/${FOREIGN_MACHINE_ID}/photos/${FOREIGN_PHOTO_ID}/original.jpg`,
      thumbnailPath: null,
      status: "active",
      uploadedBy: "p806_verifier",
      uploadedAt: now,
      recognitionStatus: "completed",
      recognitionProvider: "fixture",
      isPrimary: true,
    });
}

async function cleanupSpecialFixtures(
  firestore: ReturnType<typeof getFirestore>,
  machineId: string,
): Promise<void> {
  await firestore
    .collection("vending_machines")
    .doc(machineId)
    .collection("photos")
    .doc(LOCAL_PHOTO_ID)
    .delete()
    .catch(() => undefined);

  const foreignRef = firestore
    .collection("vending_machines")
    .doc(FOREIGN_MACHINE_ID);

  await foreignRef
    .collection("photos")
    .doc(FOREIGN_PHOTO_ID)
    .delete()
    .catch(() => undefined);

  await foreignRef
    .delete()
    .catch(() => undefined);

  await firestore
    .collection("vending_machines")
    .doc(LEGACY_MACHINE_ID)
    .delete()
    .catch(() => undefined);
}

async function countMachineReports(
  firestore: ReturnType<typeof getFirestore>,
  machineId: string,
): Promise<number> {
  const snapshot =
    await firestore
      .collection("machine_reports")
      .where("machineId", "==", machineId)
      .get();

  return snapshot.size;
}

async function readMachineIndexes(
  firestore: ReturnType<typeof getFirestore>,
  machineId: string,
): Promise<unknown[]> {
  const snapshot =
    await firestore
      .collection("machine_product_index")
      .where("machineId", "==", machineId)
      .get();

  return snapshot.docs
    .map((document) => ({
      id: document.id,
      data: canonicalValue(document.data()),
    }))
    .sort((left, right) =>
      left.id.localeCompare(right.id),
    );
}

function canonicalize(
  value: unknown,
): string {
  return JSON.stringify(
    canonicalValue(value),
  );
}

function canonicalValue(
  value: unknown,
): unknown {
  if (value instanceof Timestamp) {
    return {
      __type: "Timestamp",
      seconds: value.seconds,
      nanoseconds: value.nanoseconds,
    };
  }

  if (value instanceof GeoPoint) {
    return {
      __type: "GeoPoint",
      latitude: value.latitude,
      longitude: value.longitude,
    };
  }

  if (Array.isArray(value)) {
    return value.map(canonicalValue);
  }

  if (
    typeof value === "object" &&
    value !== null
  ) {
    return Object.fromEntries(
      Object.entries(
        value as Record<string, unknown>,
      )
        .sort(([left], [right]) =>
          left.localeCompare(right),
        )
        .map(([key, item]) => [
          key,
          canonicalValue(item),
        ]),
    );
  }

  return value;
}

async function createEmulatorUser():
Promise<AuthResult> {
  const response = await fetch(
    `http://${AUTH_EMULATOR}` +
      "/identitytoolkit.googleapis.com/v1/" +
      "accounts:signUp?key=fake-key",
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
      body: JSON.stringify({
        email:
          `p806-${Date.now()}-${Math.random()}` +
          "@example.test",
        password:
          "P806-test-password-123!",
        returnSecureToken: true,
      }),
    },
  );

  const body = await response.json() as {
    localId?: unknown;
    idToken?: unknown;
    error?: unknown;
  };

  if (
    !response.ok ||
    typeof body.localId !== "string" ||
    typeof body.idToken !== "string"
  ) {
    throw new Error(
      "Auth emulator sign-up failed: " +
        JSON.stringify(
          body.error ?? body,
        ),
    );
  }

  return {
    uid: body.localId,
    idToken: body.idToken,
  };
}

async function callFunction<T>(
  functionName: string,
  idToken: string,
  data: Record<string, unknown>,
): Promise<T> {
  const envelope =
    await rawCallable<T>(
      functionName,
      idToken,
      data,
    );

  if (envelope.error !== undefined) {
    throw new Error(
      `${functionName} failed: ` +
        JSON.stringify(envelope.error),
    );
  }

  const result =
    envelope.result ?? envelope.data;

  if (result === undefined) {
    throw new Error(
      `${functionName} returned no result.`,
    );
  }

  return result;
}

async function rawCallable<T>(
  functionName: string,
  idToken: string | null,
  data: Record<string, unknown>,
): Promise<CallableEnvelope<T>> {
  const headers:
    Record<string, string> = {
      "content-type": "application/json",
    };

  if (idToken !== null) {
    headers.authorization =
      `Bearer ${idToken}`;
  }

  const response = await fetch(
    `${FUNCTIONS_BASE}/${functionName}`,
    {
      method: "POST",
      headers,
      body: JSON.stringify({data}),
    },
  );

  return await response.json() as
    CallableEnvelope<T>;
}

async function attemptDirectClientReportWrite(
  idToken: string,
  machineId: string,
): Promise<number> {
  const response = await fetch(
    `${FIRESTORE_REST_BASE}` +
      `/machine_reports/${DIRECT_WRITE_ID}`,
    {
      method: "PATCH",
      headers: {
        "content-type": "application/json",
        authorization:
          `Bearer ${idToken}`,
      },
      body: JSON.stringify({
        fields: {
          machineId: {
            stringValue: machineId,
          },
          category: {
            stringValue: "other",
          },
          status: {
            stringValue: "new",
          },
          reportedBy: {
            stringValue: "client",
          },
        },
      }),
    },
  );

  return response.status;
}

async function deleteEmulatorUserBestEffort(
  idToken: string,
): Promise<void> {
  try {
    await fetch(
      `http://${AUTH_EMULATOR}` +
        "/identitytoolkit.googleapis.com/v1/" +
        "accounts:delete?key=fake-key",
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        body: JSON.stringify({
          idToken,
        }),
      },
    );
  } catch {
    // Emulator cleanup is best effort.
  }
}

function assert(
  condition: unknown,
  message = "Assertion failed.",
): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

void main().catch(
  (error: unknown) => {
    console.error(
      "P8-06B3 verification failed.",
      error,
    );
    process.exitCode = 1;
  },
);
