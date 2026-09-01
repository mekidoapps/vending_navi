import {randomUUID} from "node:crypto";

import {getApps, initializeApp} from "firebase-admin/app";
import {
  GeoPoint,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";

import {
  buildProductUpdateDeduplicationId,
} from "../src/update_vending_machine_products_core";
import {
  buildRecognitionSessionId,
} from "../src/photo_recognition/recognition_operation_store";

const PROJECT_ID = "vendingnavi";
const STORAGE_BUCKET = "vendingnavi.firebasestorage.app";

const AUTH_EMULATOR = "127.0.0.1:9099";
const FIRESTORE_EMULATOR = "127.0.0.1:8080";
const STORAGE_EMULATOR = "127.0.0.1:9199";
const FUNCTIONS_EMULATOR = "127.0.0.1:5001";

const FUNCTIONS_BASE =
  `http://${FUNCTIONS_EMULATOR}/${PROJECT_ID}/us-central1`;

const FIRESTORE_REST_BASE =
  `http://${FIRESTORE_EMULATOR}` +
  `/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

const PHOTO_RECOGNIZED_PRODUCT_ID = "asahi_calpis";

const TEST_JPEG = Buffer.from(
  [
    "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP",
    "////////////////////////////////",
    "////////////////////////////////",
    "////////////////////2wBDAf//////",
    "////////////////////////////////",
    "////////////////////////////////",
    "////////////////////wAARCAABAAED",
    "ASIAAhEBAxEB/8QAFQABAQAAAAAAAAAA",
    "AAAAAAAAAAf/xAAUEAEAAAAAAAAAAAAA",
    "AAAAAAAA/9oADAMBAAIQAxAAAAF//8QA",
    "FBABAAAAAAAAAAAAAAAAAAAAAP/aAAgB",
    "AQABBQJ//8QAFBEBAAAAAAAAAAAAAAAA",
    "AAAAAP/aAAgBAwEBPwF//8QAFBEBAAAA",
    "AAAAAAAAAAAAAAAAAP/aAAgBAgEBPwF/",
    "/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/a",
    "AAgBAQAGPwJ//8QAFBABAAAAAAAAAAAA",
    "AAAAAAAAAP/aAAgBAQABPyF//9oADAMB",
    "AAIAAwAAABD/xAAUEQEAAAAAAAAAAAAA",
    "AAAAAAAA/9oACAEDAQE/EB//xAAUEQEA",
    "AAAAAAAAAAAAAAAAAAAA/9oACAECAQE/",
    "EB//xAAUEAEAAAAAAAAAAAAAAAAAAAAA",
    "/9oACAEBAAE/EB//2Q==",
  ].join(""),
  "base64",
);

interface AuthResult {
  readonly uid: string;
  readonly idToken: string;
}

interface CallableEnvelope<T> {
  readonly result?: T;
  readonly data?: T;
  readonly error?: unknown;
}

interface CreateMachineResult {
  readonly machineId: string;
  readonly created: boolean;
  readonly duplicateCandidates: readonly string[];
}

interface UpdateProductsResult {
  readonly machineId: string;
  readonly updated: boolean;
  readonly changedProductIds: readonly string[];
}

interface RecognitionResult {
  readonly manufacturerCandidates: readonly {
    readonly manufacturerId: string;
  }[];
  readonly productCandidates: readonly {
    readonly productId: string;
  }[];
  readonly unresolvedLabels: readonly string[];
  readonly recognitionStatus: "completed" | "failed";
}

interface Fixture {
  readonly manufacturerId: string;
  readonly inferredProductId: string;
  readonly manualProductId: string;
}

function configureEnvironment(): void {
  process.env.GCLOUD_PROJECT = PROJECT_ID;
  process.env.GOOGLE_CLOUD_PROJECT = PROJECT_ID;
  process.env.FIREBASE_AUTH_EMULATOR_HOST = AUTH_EMULATOR;
  process.env.FIRESTORE_EMULATOR_HOST = FIRESTORE_EMULATOR;
  process.env.FIREBASE_STORAGE_EMULATOR_HOST = STORAGE_EMULATOR;
}

async function main(): Promise<void> {
  configureEnvironment();

  const app =
    getApps().find((item) => item.name === "p802d-e2e") ??
    initializeApp(
      {
        projectId: PROJECT_ID,
        storageBucket: STORAGE_BUCKET,
      },
      "p802d-e2e",
    );

  const firestore = getFirestore(app);
  const bucket = getStorage(app).bucket(STORAGE_BUCKET);

  const fixture = await findFixture(firestore);
  const auth = await createEmulatorUser();

  const createdMachineIds: string[] = [];
  const temporaryPaths: string[] = [];

  try {
    console.log("=== P8-02D PRODUCT UPDATE E2E ===");
    console.log(`uid=${auth.uid}`);
    console.log(`manufacturer=${fixture.manufacturerId}`);
    console.log(`inferred=${fixture.inferredProductId}`);
    console.log(`manual=${fixture.manualProductId}`);

    // ========================================================
    // 1. Real manufacturer registration supplies an inferred
    //    product that can later be confirmed.
    // ========================================================

    const createRequestId = randomUUID();

    const created = await callFunction<CreateMachineResult>(
      "createVendingMachine",
      auth.idToken,
      {
        requestId: createRequestId,
        registrationMethod: "manufacturer",
        location: {
          latitude: 35.681236,
          longitude: 139.767125,
        },
        name: "P8-02D update verification",
        manufacturerId: fixture.manufacturerId,
        confirmedProductIds: [],
        temporaryPhotoUploadId: null,
        placeDescription: "Emulator verification",
        installationType: "outdoor",
      },
    );

    assert(created.created === true);
    createdMachineIds.push(created.machineId);

    const machineRef = firestore
      .collection("vending_machines")
      .doc(created.machineId);

    const initialMachine = await machineRef.get();

    assert(initialMachine.exists);
    assert(initialMachine.data()?.schemaVersion === 2);
    assert(initialMachine.data()?.status === "active");

    const inferredBefore = await machineRef
      .collection("products")
      .doc(fixture.inferredProductId)
      .get();

    assert(
      inferredBefore.exists,
      "Manufacturer registration must create inferred fixture product.",
    );
    assert(
      inferredBefore.data()?.evidenceType ===
        "manufacturer_inferred",
    );
    assert(inferredBefore.data()?.availability === "unknown");

    const initialRevisionCount =
      (await machineRef.collection("revisions").get()).size;

    assert(
      initialRevisionCount === 1,
      "Machine creation must begin with one revision.",
    );

    // ========================================================
    // 2. addConfirmed
    // ========================================================

    const addRequestId = randomUUID();

    const addResult = await callFunction<UpdateProductsResult>(
      "updateVendingMachineProducts",
      auth.idToken,
      {
        requestId: addRequestId,
        machineId: created.machineId,
        operations: [
          {
            type: "addConfirmed",
            productId: fixture.manualProductId,
            source: "manual",
          },
        ],
        temporaryPhotoUploadId: null,
      },
    );

    assert(addResult.updated === true);
    assert(
      addResult.changedProductIds.length === 1 &&
      addResult.changedProductIds[0] === fixture.manualProductId,
    );

    const manualProductRef = machineRef
      .collection("products")
      .doc(fixture.manualProductId);

    let manualProduct = await manualProductRef.get();

    assert(manualProduct.exists);
    assert(
      manualProduct.data()?.evidenceType ===
        "manual_confirmed",
    );
    assert(manualProduct.data()?.availability === "available");
    assert(manualProduct.data()?.isActive === true);
    assert(
      !Object.prototype.hasOwnProperty.call(
        manualProduct.data() ?? {},
        "confirmedBy",
      ),
      "Public manual product must not expose confirmedBy.",
    );

    const manualPrivateProduct = await firestore
      .collection("vending_machine_private")
      .doc(created.machineId)
      .collection("products")
      .doc(fixture.manualProductId)
      .get();

    assert(manualPrivateProduct.exists);
    assert(manualPrivateProduct.data()?.confirmedBy === auth.uid);

    let manualIndex = await firestore
      .collection("machine_product_index")
      .doc(`${created.machineId}_${fixture.manualProductId}`)
      .get();

    assert(manualIndex.exists);
    assert(manualIndex.data()?.isActive === true);
    assert(
      manualIndex.data()?.evidenceType ===
        "manual_confirmed",
    );
    assert(manualIndex.data()?.availability === "available");

    let machineAfterUpdate = await machineRef.get();

    assert(
      machineAfterUpdate.data()?.updatedAt instanceof Timestamp,
    );
    assert(
      machineAfterUpdate.data()?.lastProductUpdatedAt
        instanceof Timestamp,
    );

    let revisions = await machineRef.collection("revisions").get();

    assert(revisions.size === initialRevisionCount + 1);

    const addRevision = revisions.docs.find(
      (document) =>
        document.data().requestId === addRequestId,
    );

    assert(addRevision !== undefined);
    assert(addRevision.data().updateType === "productsUpdated");
    assert(addRevision.data().source === "manual");
    assert(addRevision.data().updatedBy === auth.uid);

    const dedupeId = buildProductUpdateDeduplicationId(
      auth.uid,
      addRequestId,
    );

    const dedupe = await firestore
      .collection("request_deduplication")
      .doc(dedupeId)
      .get();

    assert(dedupe.exists);
    assert(
      dedupe.data()?.operation ===
        "updateVendingMachineProducts",
    );

    // ========================================================
    // 3. Same requestId replay must not write a second revision.
    // ========================================================

    const replay = await callFunction<UpdateProductsResult>(
      "updateVendingMachineProducts",
      auth.idToken,
      {
        requestId: addRequestId,
        machineId: created.machineId,
        operations: [
          {
            type: "addConfirmed",
            productId: fixture.manualProductId,
            source: "manual",
          },
        ],
        temporaryPhotoUploadId: null,
      },
    );

    assert(replay.machineId === created.machineId);
    assert(replay.updated === true);

    revisions = await machineRef.collection("revisions").get();

    assert(
      revisions.size === initialRevisionCount + 1,
      "Idempotent replay must not create another revision.",
    );

    // ========================================================
    // 4. soldOut true
    // ========================================================

    await callFunction<UpdateProductsResult>(
      "updateVendingMachineProducts",
      auth.idToken,
      {
        requestId: randomUUID(),
        machineId: created.machineId,
        operations: [
          {
            type: "setSoldOut",
            productId: fixture.manualProductId,
            soldOut: true,
          },
        ],
        temporaryPhotoUploadId: null,
      },
    );

    manualProduct = await manualProductRef.get();
    manualIndex = await firestore
      .collection("machine_product_index")
      .doc(`${created.machineId}_${fixture.manualProductId}`)
      .get();

    assert(manualProduct.data()?.availability === "soldOut");
    assert(manualIndex.data()?.availability === "soldOut");

    // ========================================================
    // 5. soldOut false
    // ========================================================

    await callFunction<UpdateProductsResult>(
      "updateVendingMachineProducts",
      auth.idToken,
      {
        requestId: randomUUID(),
        machineId: created.machineId,
        operations: [
          {
            type: "setSoldOut",
            productId: fixture.manualProductId,
            soldOut: false,
          },
        ],
        temporaryPhotoUploadId: null,
      },
    );

    manualProduct = await manualProductRef.get();
    manualIndex = await firestore
      .collection("machine_product_index")
      .doc(`${created.machineId}_${fixture.manualProductId}`)
      .get();

    assert(manualProduct.data()?.availability === "available");
    assert(manualIndex.data()?.availability === "available");

    // ========================================================
    // 6. manufacturer_inferred -> manual_confirmed
    // ========================================================

    await callFunction<UpdateProductsResult>(
      "updateVendingMachineProducts",
      auth.idToken,
      {
        requestId: randomUUID(),
        machineId: created.machineId,
        operations: [
          {
            type: "confirmInferred",
            productId: fixture.inferredProductId,
          },
        ],
        temporaryPhotoUploadId: null,
      },
    );

    const inferredAfter = await machineRef
      .collection("products")
      .doc(fixture.inferredProductId)
      .get();

    const inferredIndex = await firestore
      .collection("machine_product_index")
      .doc(`${created.machineId}_${fixture.inferredProductId}`)
      .get();

    assert(
      inferredAfter.data()?.evidenceType ===
        "manual_confirmed",
    );
    assert(inferredAfter.data()?.availability === "available");
    assert(
      !Object.prototype.hasOwnProperty.call(
        inferredAfter.data() ?? {},
        "confirmedBy",
      ),
      "Public confirmed inferred product must not expose confirmedBy.",
    );

    const inferredPrivateProduct = await firestore
      .collection("vending_machine_private")
      .doc(created.machineId)
      .collection("products")
      .doc(fixture.inferredProductId)
      .get();

    assert(inferredPrivateProduct.exists);
    assert(inferredPrivateProduct.data()?.confirmedBy === auth.uid);

    assert(
      inferredIndex.data()?.evidenceType ===
        "manual_confirmed",
    );
    assert(inferredIndex.data()?.availability === "available");

    // ========================================================
    // 7. deactivate = logical delete
    // ========================================================

    await callFunction<UpdateProductsResult>(
      "updateVendingMachineProducts",
      auth.idToken,
      {
        requestId: randomUUID(),
        machineId: created.machineId,
        operations: [
          {
            type: "deactivate",
            productId: fixture.manualProductId,
          },
        ],
        temporaryPhotoUploadId: null,
      },
    );

    manualProduct = await manualProductRef.get();
    manualIndex = await firestore
      .collection("machine_product_index")
      .doc(`${created.machineId}_${fixture.manualProductId}`)
      .get();

    assert(
      manualProduct.exists,
      "Deactivate must not physically delete product document.",
    );
    assert(manualProduct.data()?.isActive === false);
    assert(manualIndex.exists);
    assert(manualIndex.data()?.isActive === false);

    // ========================================================
    // 8. Photo-recognition sourced update
    // ========================================================

    const photoCreate = await callFunction<CreateMachineResult>(
      "createVendingMachine",
      auth.idToken,
      {
        requestId: randomUUID(),
        registrationMethod: "locationOnly",
        location: {
          latitude: 35.682,
          longitude: 139.768,
        },
        name: "P8-02D photo update verification",
        manufacturerId: null,
        confirmedProductIds: [],
        temporaryPhotoUploadId: null,
        placeDescription: null,
        installationType: "unknown",
      },
    );

    createdMachineIds.push(photoCreate.machineId);

    const uploadId = randomUUID();
    const recognitionRequestId = randomUUID();

    const temporaryPhotoPath =
      `machine_uploads/${auth.uid}/${uploadId}/original.jpg`;

    temporaryPaths.push(temporaryPhotoPath);

    await bucket.file(temporaryPhotoPath).save(
      TEST_JPEG,
      {
        resumable: false,
        metadata: {
          contentType: "image/jpeg",
        },
      },
    );

    const recognition =
      await callFunction<RecognitionResult>(
        "recognizeVendingMachinePhoto",
        auth.idToken,
        {
          recognitionRequestId,
          uploadId,
        },
      );

    assert(recognition.recognitionStatus === "completed");

    const recognizedIds = new Set(
      recognition.productCandidates.map(
        (candidate) => candidate.productId,
      ),
    );

    assert(
      recognizedIds.has(PHOTO_RECOGNIZED_PRODUCT_ID),
      "Emulator Recognition Provider must return asahi_calpis.",
    );

    // A client cannot turn an unrelated Product ID into photo evidence.
    const forgedPhotoResult = await rawCallable(
      "updateVendingMachineProducts",
      auth.idToken,
      {
        requestId: randomUUID(),
        machineId: photoCreate.machineId,
        operations: [
          {
            type: "addConfirmed",
            productId: fixture.manualProductId,
            source: "photo",
          },
        ],
        temporaryPhotoUploadId: uploadId,
      },
    );

    assert(
      forgedPhotoResult.error !== undefined,
      "Unrecognized Product ID must not become photo_confirmed.",
    );

    const photoUpdateRequestId = randomUUID();

    const photoUpdate =
      await callFunction<UpdateProductsResult>(
        "updateVendingMachineProducts",
        auth.idToken,
        {
          requestId: photoUpdateRequestId,
          machineId: photoCreate.machineId,
          operations: [
            {
              type: "addConfirmed",
              productId: PHOTO_RECOGNIZED_PRODUCT_ID,
              source: "photo",
            },
          ],
          temporaryPhotoUploadId: uploadId,
        },
      );

    assert(photoUpdate.updated === true);

    const photoMachineRef = firestore
      .collection("vending_machines")
      .doc(photoCreate.machineId);

    const photoProduct = await photoMachineRef
      .collection("products")
      .doc(PHOTO_RECOGNIZED_PRODUCT_ID)
      .get();

    assert(photoProduct.exists);
    assert(
      photoProduct.data()?.evidenceType ===
        "photo_confirmed",
    );
    assert(photoProduct.data()?.availability === "available");
    assert(
      !Object.prototype.hasOwnProperty.call(
        photoProduct.data() ?? {},
        "confirmedBy",
      ),
      "Public photo-confirmed product must not expose confirmedBy.",
    );

    const photoPrivateProduct = await firestore
      .collection("vending_machine_private")
      .doc(photoCreate.machineId)
      .collection("products")
      .doc(PHOTO_RECOGNIZED_PRODUCT_ID)
      .get();

    assert(photoPrivateProduct.exists);
    assert(photoPrivateProduct.data()?.confirmedBy === auth.uid);

    const photoIndex = await firestore
      .collection("machine_product_index")
      .doc(
        `${photoCreate.machineId}_${PHOTO_RECOGNIZED_PRODUCT_ID}`,
      )
      .get();

    assert(photoIndex.exists);
    assert(
      photoIndex.data()?.evidenceType ===
        "photo_confirmed",
    );

    const photoRevisions =
      await photoMachineRef.collection("revisions").get();

    const photoRevision = photoRevisions.docs.find(
      (document) =>
        document.data().requestId === photoUpdateRequestId,
    );

    assert(photoRevision !== undefined);
    assert(photoRevision.data().source === "photoRecognition");

    const sessionId =
      buildRecognitionSessionId(auth.uid, uploadId);

    const session = await firestore
      .collection("photo_recognition_sessions")
      .doc(sessionId)
      .get();

    assert(session.exists);
    assert(
      session.data()?.finalizedMachineId ===
        photoCreate.machineId,
    );
    assert(
      session.data()?.finalizedRequestId ===
        photoUpdateRequestId,
    );

    const [temporaryPhotoStillExists] =
      await bucket.file(temporaryPhotoPath).exists();

    assert(
      temporaryPhotoStillExists,
      "Product update must preserve temp photo for P8-04 photo addition.",
    );

    // ========================================================
    // 9. restricted account must be rejected.
    // ========================================================

    await firestore
      .collection("users")
      .doc(auth.uid)
      .set(
        {
          accountStatus: "restricted",
        },
        {merge: true},
      );

    const restricted = await rawCallable(
      "updateVendingMachineProducts",
      auth.idToken,
      {
        requestId: randomUUID(),
        machineId: created.machineId,
        operations: [
          {
            type: "setSoldOut",
            productId: fixture.inferredProductId,
            soldOut: true,
          },
        ],
        temporaryPhotoUploadId: null,
      },
    );

    assert(
      restricted.error !== undefined,
      "Restricted account must not update public data.",
    );

    // Restore for the rules checks; rules themselves do not inspect
    // accountStatus, but this keeps the fixture semantically normal.
    await firestore
      .collection("users")
      .doc(auth.uid)
      .set(
        {
          accountStatus: "active",
        },
        {merge: true},
      );

    // ========================================================
    // 10. Firestore client writes remain blocked by Rules.
    //     These use authenticated REST, NOT Admin SDK.
    // ========================================================

    await expectFirestoreWriteDenied(
      auth.idToken,
      `vending_machines/${created.machineId}`,
      {
        name: {stringValue: "client tamper"},
      },
    );

    await expectFirestoreWriteDenied(
      auth.idToken,
      `vending_machines/${created.machineId}` +
        `/products/${fixture.inferredProductId}`,
      {
        availability: {stringValue: "soldOut"},
      },
    );

    await expectFirestoreWriteDenied(
      auth.idToken,
      `machine_product_index/` +
        `${created.machineId}_${fixture.inferredProductId}`,
      {
        availability: {stringValue: "soldOut"},
      },
    );

    await expectFirestoreWriteDenied(
      auth.idToken,
      `vending_machines/${created.machineId}` +
        `/revisions/client_attempt_${Date.now()}`,
      {
        updateType: {stringValue: "productsUpdated"},
      },
    );

    console.log("");
    console.log(
      [
        "P8-02D VERIFIED",
        "manualAdd=ok",
        "soldOut=ok",
        "confirmInferred=ok",
        "deactivate=ok",
        "idempotency=ok",
        "photoEvidence=ok",
        "photoForgeryRejected=ok",
        "restrictedAccount=ok",
        "clientWritesDenied=ok",
      ].join(" "),
    );
  } finally {
    await cleanup(
      firestore,
      bucket,
      auth,
      createdMachineIds,
      temporaryPaths,
    );
  }
}

async function findFixture(
  firestore: ReturnType<typeof getFirestore>,
): Promise<Fixture> {
  const activeProducts = await firestore
    .collection("products")
    .where("isActive", "==", true)
    .limit(100)
    .get();

  const activeProductIds = new Set(
    activeProducts.docs.map((document) => document.id),
  );

  assert(
    activeProductIds.has(PHOTO_RECOGNIZED_PRODUCT_ID),
    "asahi_calpis must exist in the seeded master fixture.",
  );

  const manufacturers = await firestore
    .collection("manufacturers")
    .where("isActive", "==", true)
    .limit(100)
    .get();

  for (const manufacturer of manufacturers.docs) {
    const rawPreset = manufacturer.data().presetProductIds;

    const activePresetIds = Array.isArray(rawPreset) ?
      rawPreset
        .filter(
          (value: unknown): value is string =>
            typeof value === "string" &&
            activeProductIds.has(value),
        ) :
      [];

    if (activePresetIds.length === 0) {
      continue;
    }

    const presetSet = new Set(activePresetIds);

    const manualProductId =
      [...activeProductIds].find(
        (productId) =>
          !presetSet.has(productId) &&
          productId !== PHOTO_RECOGNIZED_PRODUCT_ID &&
          productId !== "asahi_calpis_water",
      );

    if (manualProductId === undefined) {
      continue;
    }

    return {
      manufacturerId: manufacturer.id,
      inferredProductId: activePresetIds[0],
      manualProductId,
    };
  }

  throw new Error(
    "Could not find a manufacturer/update Product fixture. " +
      "Run npm run seed:master first.",
  );
}

async function createEmulatorUser(): Promise<AuthResult> {
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
        email:
          `p802d-${Date.now()}-${randomUUID().slice(0, 8)}` +
          "@example.test",
        password: "P802D-test-password-123!",
        returnSecureToken: true,
      }),
    },
  );

  const body = await response.json() as {
    readonly localId?: string;
    readonly idToken?: string;
    readonly error?: unknown;
  };

  if (
    !response.ok ||
    typeof body.localId !== "string" ||
    typeof body.idToken !== "string"
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

async function callFunction<T>(
  functionName: string,
  idToken: string,
  data: Record<string, unknown>,
): Promise<T> {
  const envelope =
    await rawCallable(functionName, idToken, data);

  if (envelope.error !== undefined) {
    throw new Error(
      `${functionName} returned error: ` +
        JSON.stringify(envelope.error),
    );
  }

  const result = envelope.result ?? envelope.data;

  if (
    typeof result !== "object" ||
    result === null ||
    Array.isArray(result)
  ) {
    throw new Error(
      `${functionName} returned invalid response: ` +
        JSON.stringify(envelope),
    );
  }

  return result as T;
}

async function rawCallable(
  functionName: string,
  idToken: string,
  data: Record<string, unknown>,
): Promise<CallableEnvelope<unknown>> {
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

  return await response.json() as CallableEnvelope<unknown>;
}

async function expectFirestoreWriteDenied(
  idToken: string,
  documentPath: string,
  fields: Record<string, unknown>,
): Promise<void> {
  const response = await fetch(
    `${FIRESTORE_REST_BASE}/${documentPath}`,
    {
      method: "PATCH",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${idToken}`,
      },
      body: JSON.stringify({fields}),
    },
  );

  if (response.ok) {
    throw new Error(
      `Firestore client write unexpectedly succeeded: ${documentPath}`,
    );
  }

  assert(
    response.status === 403,
    `Expected Rules denial 403 for ${documentPath}, ` +
      `received ${response.status}.`,
  );
}

async function cleanup(
  firestore: ReturnType<typeof getFirestore>,
  bucket: ReturnType<ReturnType<typeof getStorage>["bucket"]>,
  auth: AuthResult,
  machineIds: readonly string[],
  temporaryPaths: readonly string[],
): Promise<void> {
  for (const path of temporaryPaths) {
    await bucket
      .file(path)
      .delete({ignoreNotFound: true})
      .catch(() => undefined);
  }

  const sessions = await firestore
    .collection("photo_recognition_sessions")
    .where("uid", "==", auth.uid)
    .get();

  for (const document of sessions.docs) {
    await document.ref.delete().catch(() => undefined);
  }

  const dedupes = await firestore
    .collection("request_deduplication")
    .where("uid", "==", auth.uid)
    .get();

  for (const document of dedupes.docs) {
    await document.ref.delete().catch(() => undefined);
  }

  for (const machineId of machineIds) {
    const machineRef = firestore
      .collection("vending_machines")
      .doc(machineId);

    for (const subcollection of [
      "products",
      "photos",
      "revisions",
    ]) {
      const snapshot =
        await machineRef.collection(subcollection).get();

      for (const document of snapshot.docs) {
        await document.ref.delete().catch(() => undefined);
      }
    }

    const indexes = await firestore
      .collection("machine_product_index")
      .where("machineId", "==", machineId)
      .get();

    for (const document of indexes.docs) {
      await document.ref.delete().catch(() => undefined);
    }

    await machineRef.delete().catch(() => undefined);
  }

  await firestore
    .collection("users")
    .doc(auth.uid)
    .delete()
    .catch(() => undefined);

  await deleteEmulatorUserBestEffort(auth.idToken);
}

async function deleteEmulatorUserBestEffort(
  idToken: string,
): Promise<void> {
  try {
    await fetch(
      `http://${AUTH_EMULATOR}` +
        "/identitytoolkit.googleapis.com/v1/accounts:delete" +
        "?key=fake-api-key",
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        body: JSON.stringify({idToken}),
      },
    );
  } catch {
    // Emulator cleanup only.
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

void main().catch((error: unknown) => {
  console.error(
    "P8-02D updateVendingMachineProducts verification failed.",
    error,
  );
  process.exitCode = 1;
});
