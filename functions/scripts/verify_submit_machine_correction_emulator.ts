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
  buildMachineCorrectionDeduplicationId,
} from "../src/submit_machine_correction_core";

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

const LEGACY_MACHINE_ID =
  "machine_p805_legacy";

const INACTIVE_MACHINE_ID =
  "machine_p805_inactive";

const INACTIVE_MANUFACTURER_ID =
  "manufacturer_p805_inactive";

interface AuthResult {
  readonly uid: string;
  readonly idToken: string;
}

interface CallableEnvelope<T> {
  readonly result?: T;
  readonly data?: T;
  readonly error?: unknown;
}

interface CorrectionResult {
  readonly machineId: string;
  readonly correctionId: string;
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
      (item) => item.name === "p805-correction-e2e",
    ) ??
    initializeApp(
      {projectId: PROJECT_ID},
      "p805-correction-e2e",
    );

  const firestore = getFirestore(app);

  const machine = await findActiveV2Machine(
    firestore,
  );

  const machineRef = firestore
    .collection("vending_machines")
    .doc(machine.id);

  const auth = await createEmulatorUser();

  const requestIds: string[] = [];
  let correctionId: string | null = null;

  try {
    console.log(
      "=== P8-05 MACHINE CORRECTION E2E ===",
    );
    console.log(`uid=${auth.uid}`);
    console.log(`machine=${machine.id}`);

    await prepareSpecialFixtures(firestore);

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

    const current =
      readCurrentMachine(beforeMachineData);

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

    const beforeCorrectionCount =
      await countMachineCorrections(
        firestore,
        machine.id,
      );

    const alternativeManufacturerId =
      await findAlternativeActiveManufacturer(
        firestore,
        current.manufacturerId,
      );

    // ======================================================
    // 1. Valid correction proposal
    // ======================================================

    const requestId = randomUUID();
    requestIds.push(requestId);

    const proposedLocation = {
      latitude:
        shiftedCoordinate(
          current.location.latitude,
          -90,
          90,
        ),
      longitude:
        shiftedCoordinate(
          current.location.longitude,
          -180,
          180,
        ),
    };

    const proposedName =
      current.name === "P8-05 修正提案" ?
        "P8-05 修正提案 2" :
        "P8-05 修正提案";

    const proposedPlaceDescription =
      current.placeDescription ===
        "P8-05 Emulator修正候補" ?
        "P8-05 Emulator修正候補 2" :
        "P8-05 Emulator修正候補";

    const proposedInstallationType =
      current.installationType === "outdoor" ?
        "indoor" :
        "outdoor";

    const changes:
      Record<string, unknown> = {
        name: proposedName,
        location: proposedLocation,
        placeDescription:
          proposedPlaceDescription,
        installationType:
          proposedInstallationType,
      };

    if (alternativeManufacturerId !== null) {
      changes.manufacturerId =
        alternativeManufacturerId;
    }

    const input = {
      requestId,
      machineId: machine.id,
      changes,
      message: "P8-05 Emulator verification",
    };

    const result =
      await callFunction<CorrectionResult>(
        "submitMachineCorrection",
        auth.idToken,
        input,
      );

    correctionId = result.correctionId;

    assert(
      result.machineId === machine.id,
      "Result machineId must match.",
    );
    assert(
      result.submitted === true,
      "Correction must be submitted.",
    );
    assert(
      /^c_[0-9a-f]{30}$/.test(
        result.correctionId,
      ),
      "Correction ID must use deterministic format.",
    );

    const correctionRef = firestore
      .collection("machine_corrections")
      .doc(result.correctionId);

    const correction =
      await correctionRef.get();

    assert(
      correction.exists,
      "Correction document must exist.",
    );

    const correctionData =
      correction.data() ?? {};

    assert(
      correctionData.machineId === machine.id,
      "Correction machineId must match.",
    );
    assert(
      correctionData.status === "new",
      "Correction status must be new.",
    );
    assert(
      correctionData.submittedBy === auth.uid,
      "Correction submittedBy must match UID.",
    );
    assert(
      correctionData.requestId === requestId,
      "Correction requestId must be stored.",
    );
    assert(
      correctionData.message ===
        "P8-05 Emulator verification",
      "Correction message must be stored.",
    );
    assert(
      correctionData.createdAt instanceof Timestamp,
      "Correction createdAt must be Timestamp.",
    );
    assert(
      correctionData.reviewedAt === null,
      "New correction must not be reviewed.",
    );
    assert(
      correctionData.reviewedBy === null,
      "New correction must not have reviewer.",
    );
    assert(
      correctionData.resolution === null,
      "New correction must not have resolution.",
    );

    const storedChanges =
      correctionData.changes;

    assertPlainObject(
      storedChanges,
      "Correction changes must be an object.",
    );

    assert(
      storedChanges.name === proposedName,
      "Proposed name must be stored.",
    );

    assert(
      storedChanges.placeDescription ===
        proposedPlaceDescription,
      "Proposed place description must be stored.",
    );

    assert(
      storedChanges.installationType ===
        proposedInstallationType,
      "Proposed installation type must be stored.",
    );

    assert(
      storedChanges.location instanceof GeoPoint,
      "Proposed location must be stored as GeoPoint.",
    );

    assert(
      storedChanges.location.latitude ===
        proposedLocation.latitude &&
      storedChanges.location.longitude ===
        proposedLocation.longitude,
      "Stored proposed location must match.",
    );

    if (alternativeManufacturerId !== null) {
      assert(
        storedChanges.manufacturerId ===
          alternativeManufacturerId,
        "Proposed manufacturer must be stored.",
      );
    }

    // ======================================================
    // 2. Public vending-machine data must remain unchanged.
    // ======================================================

    const afterMachine =
      await machineRef.get();

    assert(
      canonicalMachineFields(
        beforeMachineData,
      ) ===
        canonicalMachineFields(
          afterMachine.data() ?? {},
        ),
      "Correction must not change vending-machine basic information.",
    );

    const afterRevisionCount =
      (
        await machineRef
          .collection("revisions")
          .get()
      ).size;

    assert(
      afterRevisionCount ===
        beforeRevisionCount,
      "Correction must not create a revision.",
    );

    const afterIndexes =
      await readMachineIndexes(
        firestore,
        machine.id,
      );

    assert(
      JSON.stringify(afterIndexes) ===
        JSON.stringify(beforeIndexes),
      "Correction must not change machine_product_index.",
    );

    const afterCorrectionCount =
      await countMachineCorrections(
        firestore,
        machine.id,
      );

    assert(
      afterCorrectionCount ===
        beforeCorrectionCount + 1,
      "Valid request must create exactly one correction.",
    );

    // ======================================================
    // 3. Same requestId replay
    // ======================================================

    const replay =
      await callFunction<CorrectionResult>(
        "submitMachineCorrection",
        auth.idToken,
        input,
      );

    assert(
      replay.correctionId ===
        result.correctionId,
      "Replay must return the same correctionId.",
    );

    assert(
      await countMachineCorrections(
        firestore,
        machine.id,
      ) === afterCorrectionCount,
      "Replay must not create another correction.",
    );

    const dedupeId =
      buildMachineCorrectionDeduplicationId(
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
        "submitMachineCorrection",
      "Idempotency operation must match.",
    );

    // ======================================================
    // 4. No-change request must be rejected.
    // ======================================================

    const noChange =
      await rawCallable<CorrectionResult>(
        "submitMachineCorrection",
        auth.idToken,
        {
          requestId: randomUUID(),
          machineId: machine.id,
          changes: {
            name: current.name,
          },
          message: null,
        },
      );

    assert(
      noChange.error !== undefined,
      "No-change correction must be rejected.",
    );

    // ======================================================
    // 5. Inactive manufacturer must be rejected.
    // ======================================================

    const inactiveManufacturer =
      await rawCallable<CorrectionResult>(
        "submitMachineCorrection",
        auth.idToken,
        {
          requestId: randomUUID(),
          machineId: machine.id,
          changes: {
            manufacturerId:
              INACTIVE_MANUFACTURER_ID,
          },
          message: null,
        },
      );

    assert(
      inactiveManufacturer.error !== undefined,
      "Inactive manufacturer must be rejected.",
    );

    // ======================================================
    // 6. Legacy machine must be rejected.
    // ======================================================

    const legacy =
      await rawCallable<CorrectionResult>(
        "submitMachineCorrection",
        auth.idToken,
        {
          requestId: randomUUID(),
          machineId: LEGACY_MACHINE_ID,
          changes: {
            name: "legacy correction",
          },
          message: null,
        },
      );

    assert(
      legacy.error !== undefined,
      "Legacy vending machine must be rejected.",
    );

    // ======================================================
    // 7. Inactive machine must be rejected.
    // ======================================================

    const inactive =
      await rawCallable<CorrectionResult>(
        "submitMachineCorrection",
        auth.idToken,
        {
          requestId: randomUUID(),
          machineId: INACTIVE_MACHINE_ID,
          changes: {
            name: "inactive correction",
          },
          message: null,
        },
      );

    assert(
      inactive.error !== undefined,
      "Inactive vending machine must be rejected.",
    );

    // ======================================================
    // 8. Unauthenticated request must be rejected.
    // ======================================================

    const unauthenticated =
      await rawCallable<CorrectionResult>(
        "submitMachineCorrection",
        null,
        {
          requestId: randomUUID(),
          machineId: machine.id,
          changes: {
            name: "unauthenticated correction",
          },
          message: null,
        },
      );

    assert(
      unauthenticated.error !== undefined,
      "Unauthenticated request must be rejected.",
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
      await rawCallable<CorrectionResult>(
        "submitMachineCorrection",
        auth.idToken,
        {
          requestId: randomUUID(),
          machineId: machine.id,
          changes: {
            name: "restricted correction",
          },
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
    // 10. Firestore client direct write must be denied.
    // ======================================================

    const directWriteStatus =
      await attemptDirectClientCorrectionWrite(
        auth.idToken,
        machine.id,
      );

    assert(
      directWriteStatus === 403 ||
        directWriteStatus === 401,
      `Direct client correction write must be denied, status=${directWriteStatus}.`,
    );

    console.log(
      [
        "P8-05B3 VERIFIED",
        "correctionStored=ok",
        "publicMachineUnchanged=ok",
        "revisionUnchanged=ok",
        "indexUnchanged=ok",
        "idempotency=ok",
        "noChangeRejected=ok",
        "inactiveManufacturerRejected=ok",
        "legacyRejected=ok",
        "inactiveMachineRejected=ok",
        "unauthenticatedRejected=ok",
        "restrictedAccount=ok",
        "clientWritesDenied=ok",
      ].join(" "),
    );
  } finally {
    if (correctionId !== null) {
      await firestore
        .collection("machine_corrections")
        .doc(correctionId)
        .delete()
        .catch(() => undefined);
    }

    for (const requestId of requestIds) {
      const dedupeId =
        buildMachineCorrectionDeduplicationId(
          auth.uid,
          requestId,
        );

      await firestore
        .collection("request_deduplication")
        .doc(dedupeId)
        .delete()
        .catch(() => undefined);
    }

    await cleanupSpecialFixtures(firestore);

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
  const snapshot =
    await firestore
      .collection("vending_machines")
      .limit(100)
      .get();

  for (const document of snapshot.docs) {
    const data = document.data();

    if (
      data.schemaVersion === 2 &&
      data.status === "active" &&
      typeof data.name === "string" &&
      data.location instanceof GeoPoint
    ) {
      return {id: document.id};
    }
  }

  throw new Error(
    "No active v2 vending-machine fixture found. Seed vending_machine_fixture first.",
  );
}

async function findAlternativeActiveManufacturer(
  firestore: ReturnType<typeof getFirestore>,
  currentManufacturerId: string | null,
): Promise<string | null> {
  const snapshot =
    await firestore
      .collection("manufacturers")
      .where("isActive", "==", true)
      .limit(50)
      .get();

  for (const document of snapshot.docs) {
    if (
      document.id !== currentManufacturerId
    ) {
      return document.id;
    }
  }

  return null;
}

async function prepareSpecialFixtures(
  firestore: ReturnType<typeof getFirestore>,
): Promise<void> {
  await firestore
    .collection("manufacturers")
    .doc(INACTIVE_MANUFACTURER_ID)
    .set({
      name: "P8-05 inactive manufacturer",
      displayShortName: "P8-05 inactive",
      searchKeywords: [],
      presetProductIds: [],
      isActive: false,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });

  await firestore
    .collection("vending_machines")
    .doc(LEGACY_MACHINE_ID)
    .set({
      name: "P8-05 legacy machine",
      manufacturer: "legacy",
      lat: 35.0,
      lng: 139.0,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });

  await firestore
    .collection("vending_machines")
    .doc(INACTIVE_MACHINE_ID)
    .set({
      schemaVersion: 2,
      name: "P8-05 inactive machine",
      manufacturerId: null,
      manufacturerStatus: "unknown",
      location: new GeoPoint(35.0, 139.0),
      geohash: "xn4z55",
      placeDescription: null,
      installationType: "unknown",
      status: "hidden",
      dataLevel: "locationOnly",
      primaryPhotoId: null,
      createdBy: "p805_verifier",
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      lastProductUpdatedAt: Timestamp.now(),
    });
}

async function cleanupSpecialFixtures(
  firestore: ReturnType<typeof getFirestore>,
): Promise<void> {
  await firestore
    .collection("manufacturers")
    .doc(INACTIVE_MANUFACTURER_ID)
    .delete()
    .catch(() => undefined);

  await firestore
    .collection("vending_machines")
    .doc(LEGACY_MACHINE_ID)
    .delete()
    .catch(() => undefined);

  await firestore
    .collection("vending_machines")
    .doc(INACTIVE_MACHINE_ID)
    .delete()
    .catch(() => undefined);
}

function readCurrentMachine(
  data: Record<string, unknown>,
): {
  readonly name: string;
  readonly manufacturerId: string | null;
  readonly location: GeoPoint;
  readonly placeDescription: string | null;
  readonly installationType: string;
} {
  const name =
    typeof data.name === "string" ?
      data.name.trim() :
      "";

  const manufacturerId =
    typeof data.manufacturerId === "string" &&
    data.manufacturerId.trim().length > 0 ?
      data.manufacturerId.trim() :
      null;

  const location = data.location;

  const placeDescription =
    typeof data.placeDescription === "string" &&
    data.placeDescription.trim().length > 0 ?
      data.placeDescription.trim() :
      null;

  const installationType =
    typeof data.installationType === "string" ?
      data.installationType.trim() :
      "";

  assert(
    name.length > 0,
    "Fixture machine name must be valid.",
  );

  assert(
    location instanceof GeoPoint,
    "Fixture machine location must be GeoPoint.",
  );

  assert(
    installationType.length > 0,
    "Fixture installationType must be valid.",
  );

  return {
    name,
    manufacturerId,
    location,
    placeDescription,
    installationType,
  };
}

function shiftedCoordinate(
  value: number,
  min: number,
  max: number,
): number {
  const shifted = value + 0.000123;

  if (shifted <= max) {
    return shifted;
  }

  const reverse = value - 0.000123;

  assert(
    reverse >= min,
    "Coordinate cannot be safely shifted.",
  );

  return reverse;
}

function canonicalMachineFields(
  data: Record<string, unknown>,
): string {
  const location = data.location;

  return JSON.stringify({
    name: data.name ?? null,
    manufacturerId:
      data.manufacturerId ?? null,
    location:
      location instanceof GeoPoint ?
        {
          latitude: location.latitude,
          longitude: location.longitude,
        } :
        null,
    geohash: data.geohash ?? null,
    placeDescription:
      data.placeDescription ?? null,
    installationType:
      data.installationType ?? null,
    status: data.status ?? null,
    updatedAt:
      data.updatedAt instanceof Timestamp ?
        data.updatedAt.toMillis() :
        null,
    lastProductUpdatedAt:
      data.lastProductUpdatedAt
        instanceof Timestamp ?
        data.lastProductUpdatedAt.toMillis() :
        null,
  });
}

async function readMachineIndexes(
  firestore: ReturnType<typeof getFirestore>,
  machineId: string,
): Promise<readonly string[]> {
  const snapshot =
    await firestore
      .collection("machine_product_index")
      .where("machineId", "==", machineId)
      .get();

  return snapshot.docs
    .map((document) =>
      JSON.stringify({
        id: document.id,
        data: canonicalize(
          document.data(),
        ),
      }),
    )
    .sort();
}

function canonicalize(
  value: unknown,
): unknown {
  if (value instanceof Timestamp) {
    return {
      type: "timestamp",
      millis: value.toMillis(),
    };
  }

  if (value instanceof GeoPoint) {
    return {
      type: "geopoint",
      latitude: value.latitude,
      longitude: value.longitude,
    };
  }

  if (Array.isArray(value)) {
    return value.map(canonicalize);
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
          canonicalize(item),
        ]),
    );
  }

  return value;
}

async function countMachineCorrections(
  firestore: ReturnType<typeof getFirestore>,
  machineId: string,
): Promise<number> {
  const snapshot =
    await firestore
      .collection("machine_corrections")
      .where("machineId", "==", machineId)
      .get();

  return snapshot.size;
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
          `p805-${Date.now()}-${Math.random()}` +
          "@example.test",
        password:
          "P805-test-password-123!",
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

async function attemptDirectClientCorrectionWrite(
  idToken: string,
  machineId: string,
): Promise<number> {
  const documentId =
    `client_direct_${Date.now()}`;

  const response = await fetch(
    `${FIRESTORE_REST_BASE}` +
      `/machine_corrections/${documentId}`,
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
          status: {
            stringValue: "new",
          },
          submittedBy: {
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

function assertPlainObject(
  value: unknown,
  message: string,
): asserts value is Record<string, unknown> {
  assert(
    typeof value === "object" &&
      value !== null &&
      !Array.isArray(value),
    message,
  );
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
      "P8-05B3 verification failed.",
      error,
    );
    process.exitCode = 1;
  },
);
