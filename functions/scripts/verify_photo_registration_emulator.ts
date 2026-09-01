import {createHash, randomUUID} from "node:crypto";

import {getApps, initializeApp} from "firebase-admin/app";
import {
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";

import {
  buildRequestDeduplicationId,
} from "../src/create_vending_machine_core";
import {
  buildFormalPhotoStoragePath,
  buildPhotoRegistrationIds,
} from "../src/photo_recognition/photo_registration_finalization";
import {
  buildRecognitionSessionId,
} from "../src/photo_recognition/recognition_operation_store";

const PROJECT_ID = "vendingnavi";
const STORAGE_BUCKET = "vendingnavi.firebasestorage.app";

const AUTH_EMULATOR = "127.0.0.1:9099";
const FIRESTORE_EMULATOR = "127.0.0.1:8080";
const STORAGE_EMULATOR = "127.0.0.1:9199";
const FUNCTIONS_HOST = "127.0.0.1:5001";

const FUNCTIONS_BASE =
  `http://${FUNCTIONS_HOST}/${PROJECT_ID}/us-central1`;

const PROVIDER_KEY = "p714_fixture_provider";

// AIそのものはP7-11で検証済み。
// P7-14では「認識済み写真を正式登録する経路」だけを検証するため、
// 小さな固定JPEGを一時Storageへ配置する。
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

interface AuthSignUpResponse {
  readonly localId?: string;
  readonly idToken?: string;
  readonly error?: unknown;
}

interface CallableEnvelope<T> {
  readonly result?: T;
  readonly data?: T;
  readonly error?: unknown;
}

interface CreateVendingMachineResult {
  readonly machineId: string;
  readonly created: boolean;
  readonly duplicateCandidates: readonly string[];
}

interface ActiveMasterFixture {
  readonly manufacturerId: string;
  readonly recognizedProductId: string;
  readonly manuallyAddedProductId: string;
}

function configureEmulatorEnvironment(): void {
  process.env.GCLOUD_PROJECT = PROJECT_ID;
  process.env.GOOGLE_CLOUD_PROJECT = PROJECT_ID;
  process.env.FIREBASE_AUTH_EMULATOR_HOST = AUTH_EMULATOR;
  process.env.FIRESTORE_EMULATOR_HOST = FIRESTORE_EMULATOR;
  process.env.FIREBASE_STORAGE_EMULATOR_HOST = STORAGE_EMULATOR;
}

function sha256(value: Buffer): string {
  return createHash("sha256").update(value).digest("hex");
}

function assert(
  condition: unknown,
  message = "Assertion failed.",
): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

async function createEmulatorUser(): Promise<{
  readonly uid: string;
  readonly idToken: string;
}> {
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
          `p714-${Date.now()}-${randomUUID().slice(0, 8)}` +
          "@example.test",
        password: "P714-test-password-123!",
        returnSecureToken: true,
      }),
    },
  );

  const body = await response.json() as AuthSignUpResponse;

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

async function findActiveMasterFixture(
  firestore: ReturnType<typeof getFirestore>,
): Promise<ActiveMasterFixture> {
  const manufacturerSnapshot = await firestore
    .collection("manufacturers")
    .where("isActive", "==", true)
    .limit(20)
    .get();

  if (manufacturerSnapshot.empty) {
    throw new Error(
      "No active manufacturer master found. " +
        "Run the existing seed_master_fixture script first.",
    );
  }

  const productSnapshot = await firestore
    .collection("products")
    .where("isActive", "==", true)
    .limit(50)
    .get();

  const activeProductIds = productSnapshot.docs
    .map((document) => document.id)
    .filter((id) => id.length > 0);

  if (activeProductIds.length < 2) {
    throw new Error(
      "At least two active Product master records are required.",
    );
  }

  return {
    manufacturerId: manufacturerSnapshot.docs[0].id,
    recognizedProductId: activeProductIds[0],
    manuallyAddedProductId: activeProductIds[1],
  };
}

async function callCreateVendingMachine(
  idToken: string,
  data: Record<string, unknown>,
): Promise<CreateVendingMachineResult> {
  const response = await fetch(
    `${FUNCTIONS_BASE}/createVendingMachine`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${idToken}`,
      },
      body: JSON.stringify({data}),
    },
  );

  const envelope =
    await response.json() as CallableEnvelope<CreateVendingMachineResult>;

  if (!response.ok || envelope.error !== undefined) {
    throw new Error(
      `createVendingMachine failed (${response.status}): ` +
        JSON.stringify(envelope),
    );
  }

  const result = envelope.result ?? envelope.data;

  if (
    result === undefined ||
    typeof result.machineId !== "string" ||
    result.machineId.length === 0 ||
    result.created !== true ||
    !Array.isArray(result.duplicateCandidates)
  ) {
    throw new Error(
      `Invalid createVendingMachine response: ` +
        JSON.stringify(envelope),
    );
  }

  return result;
}

async function cleanupMachine(
  firestore: ReturnType<typeof getFirestore>,
  machineId: string,
): Promise<void> {
  const machineRef = firestore
    .collection("vending_machines")
    .doc(machineId);

  for (const subcollectionName of [
    "products",
    "photos",
    "revisions",
  ]) {
    const snapshot = await machineRef
      .collection(subcollectionName)
      .get();

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

async function main(): Promise<void> {
  configureEmulatorEnvironment();

  const app =
    getApps().find((candidate) => candidate.name === "p714-e2e") ??
    initializeApp(
      {
        projectId: PROJECT_ID,
        storageBucket: STORAGE_BUCKET,
      },
      "p714-e2e",
    );

  const firestore = getFirestore(app);
  const bucket = getStorage(app).bucket(STORAGE_BUCKET);

  const fixture = await findActiveMasterFixture(firestore);
  const auth = await createEmulatorUser();

  const requestId = randomUUID();
  const uploadId = randomUUID();

  const ids = buildPhotoRegistrationIds(
    auth.uid,
    requestId,
    uploadId,
  );

  const machineId = ids.machineId;
  const photoId = ids.photoId;

  const temporaryPhotoPath =
    `machine_uploads/${auth.uid}/${uploadId}/original.jpg`;

  const formalPhotoPath = buildFormalPhotoStoragePath(
    machineId,
    photoId,
  );

  const sessionId = buildRecognitionSessionId(
    auth.uid,
    uploadId,
  );

  const sessionRef = firestore
    .collection("photo_recognition_sessions")
    .doc(sessionId);

  const dedupeId = buildRequestDeduplicationId(
    auth.uid,
    requestId,
  );

  const dedupeRef = firestore
    .collection("request_deduplication")
    .doc(dedupeId);

  const now = new Date();
  const expiresAt = new Date(
    now.getTime() + 60 * 60 * 1000,
  );

  try {
    console.log("=== P7-14 PHOTO REGISTRATION E2E ===");
    console.log(`uid=${auth.uid}`);
    console.log(`requestId=${requestId}`);
    console.log(`uploadId=${uploadId}`);
    console.log(`manufacturerId=${fixture.manufacturerId}`);
    console.log(
      `recognizedProductId=${fixture.recognizedProductId}`,
    );
    console.log(
      `manuallyAddedProductId=${fixture.manuallyAddedProductId}`,
    );
    console.log("");

    await bucket.file(temporaryPhotoPath).save(
      TEST_JPEG,
      {
        resumable: false,
        metadata: {
          contentType: "image/jpeg",
        },
      },
    );

    await sessionRef.set({
      uid: auth.uid,
      uploadId,
      status: "completed",
      provider: PROVIDER_KEY,
      manufacturerCandidateIds: [
        fixture.manufacturerId,
      ],
      productCandidateIds: [
        fixture.recognizedProductId,
      ],
      photoObjectPath: temporaryPhotoPath,
      photoContentSha256: sha256(TEST_JPEG),
      photoSizeBytes: TEST_JPEG.length,
      recognizedAt: Timestamp.fromDate(now),
      expiresAt: Timestamp.fromDate(expiresAt),
    });

    const beforeMachineCount = (
      await firestore.collection("vending_machines").get()
    ).size;

    const input = {
      requestId,
      registrationMethod: "photo",
      location: {
        latitude: 35.681236,
        longitude: 139.767125,
      },
      name: null,
      manufacturerId: fixture.manufacturerId,
      confirmedProductIds: [
        fixture.recognizedProductId,
        fixture.manuallyAddedProductId,
      ],
      temporaryPhotoUploadId: uploadId,
      placeDescription: "P7-14 Emulator verification",
      installationType: "outdoor",
    };

    const first = await callCreateVendingMachine(
      auth.idToken,
      input,
    );

    assert(
      first.machineId === machineId,
      "Photo registration must return deterministic machineId.",
    );

    const afterFirstMachineCount = (
      await firestore.collection("vending_machines").get()
    ).size;

    assert(
      afterFirstMachineCount === beforeMachineCount + 1,
      "First photo registration must create exactly one machine.",
    );

    const machineSnapshot = await firestore
      .collection("vending_machines")
      .doc(machineId)
      .get();

    assert(
      machineSnapshot.exists,
      "Created photo machine must exist.",
    );

    const machine = machineSnapshot.data() ?? {};

    assert(machine.schemaVersion === 2);
    assert(machine.manufacturerId === fixture.manufacturerId);
    assert(
      machine.manufacturerStatus ===
        "recognized_and_confirmed",
      "Recognized + user-confirmed manufacturer must be marked correctly.",
    );
    assert(machine.dataLevel === "productsConfirmed");
    assert(machine.primaryPhotoId === photoId);
    assert(
      !Object.prototype.hasOwnProperty.call(machine, "createdBy"),
      "Public machine must not expose createdBy.",
    );
    assert(machine.status === "active");

    const privateMachineSnapshot = await firestore
      .collection("vending_machine_private")
      .doc(machineId)
      .get();

    assert(
      privateMachineSnapshot.exists,
      "Private machine metadata must exist.",
    );
    assert(
      privateMachineSnapshot.data()?.createdBy === auth.uid,
      "Private machine metadata must preserve creator UID.",
    );

    const photoSnapshot = await machineSnapshot.ref
      .collection("photos")
      .doc(photoId)
      .get();

    assert(
      photoSnapshot.exists,
      "Formal photo Firestore document must exist.",
    );

    const photoData = photoSnapshot.data() ?? {};

    assert(photoData.storagePath === formalPhotoPath);
    assert(photoData.status === "active");
    assert(photoData.uploadedBy === auth.uid);
    assert(photoData.recognitionStatus === "completed");
    assert(photoData.recognitionProvider === PROVIDER_KEY);
    assert(photoData.isPrimary === true);

    const recognizedProduct = await machineSnapshot.ref
      .collection("products")
      .doc(fixture.recognizedProductId)
      .get();

    const manualProduct = await machineSnapshot.ref
      .collection("products")
      .doc(fixture.manuallyAddedProductId)
      .get();

    assert(
      recognizedProduct.exists,
      "Recognized confirmed product must exist.",
    );
    assert(
      manualProduct.exists,
      "Manually-added confirmed product must exist.",
    );

    assert(
      recognizedProduct.data()?.evidenceType ===
        "photo_confirmed",
      "Recognized product must use photo_confirmed.",
    );
    assert(
      manualProduct.data()?.evidenceType ===
        "manual_confirmed",
      "User-added product must use manual_confirmed.",
    );

    for (const productSnapshot of [
      recognizedProduct,
      manualProduct,
    ]) {
      const product = productSnapshot.data() ?? {};

      assert(product.availability === "available");
      assert(product.isActive === true);
      assert(
        !Object.prototype.hasOwnProperty.call(product, "confirmedBy"),
        "Public product must not expose confirmedBy.",
      );

      const privateProductSnapshot = await firestore
        .collection("vending_machine_private")
        .doc(machineId)
        .collection("products")
        .doc(productSnapshot.id)
        .get();

      assert(
        privateProductSnapshot.exists,
        `Private confirmation metadata must exist for ${productSnapshot.id}.`,
      );
      assert(
        privateProductSnapshot.data()?.confirmedBy === auth.uid,
        `Private confirmation UID must match for ${productSnapshot.id}.`,
      );

      const index = await firestore
        .collection("machine_product_index")
        .doc(`${machineId}_${productSnapshot.id}`)
        .get();

      assert(
        index.exists,
        `Product index must exist for ${productSnapshot.id}.`,
      );

      assert(index.data()?.machineId === machineId);
      assert(index.data()?.productId === productSnapshot.id);
      assert(
        index.data()?.evidenceType === product.evidenceType,
      );
      assert(index.data()?.availability === "available");
      assert(index.data()?.isActive === true);
    }

    const productCollection = await machineSnapshot.ref
      .collection("products")
      .get();

    assert(
      productCollection.size === 2,
      "Photo registration must create exactly the two confirmed products.",
    );

    const revisionSnapshot = await machineSnapshot.ref
      .collection("revisions")
      .get();

    assert(
      revisionSnapshot.size === 1,
      "Photo registration must create exactly one revision.",
    );

    const revision = revisionSnapshot.docs[0].data();

    assert(revision.updateType === "machineCreated");
    assert(revision.source === "photoRecognition");
    assert(revision.updatedBy === auth.uid);
    assert(revision.requestId === requestId);
    assert(
      revision.afterSnapshot?.primaryPhotoId === photoId,
    );

    const sessionAfterCreate = await sessionRef.get();

    assert(
      sessionAfterCreate.exists,
      "Recognition session must remain after finalization.",
    );

    const finalizedSession = sessionAfterCreate.data() ?? {};

    assert(finalizedSession.finalizedMachineId === machineId);
    assert(finalizedSession.finalizedPhotoId === photoId);
    assert(finalizedSession.finalizedRequestId === requestId);
    assert(
      finalizedSession.finalizedAt instanceof Timestamp,
      "Recognition session must record finalizedAt.",
    );

    const dedupeSnapshot = await dedupeRef.get();

    assert(
      dedupeSnapshot.exists,
      "createVendingMachine idempotency record must exist.",
    );
    assert(
      dedupeSnapshot.data()?.operation ===
        "createVendingMachine",
    );
    assert(
      dedupeSnapshot.data()?.requestId === requestId,
    );
    assert(
      dedupeSnapshot.data()?.result?.machineId === machineId,
    );

    const [formalExists] = await bucket
      .file(formalPhotoPath)
      .exists();

    assert(
      formalExists,
      "Formal Storage photo must exist.",
    );

    const [formalBytes] = await bucket
      .file(formalPhotoPath)
      .download();

    assert(
      Buffer.compare(formalBytes, TEST_JPEG) === 0,
      "Formal photo bytes must match the recognized temporary photo.",
    );

    const [temporaryExistsAfterCreate] = await bucket
      .file(temporaryPhotoPath)
      .exists();

    assert(
      !temporaryExistsAfterCreate,
      "Temporary photo must be removed after successful finalization.",
    );

    console.log("=== FIRST CREATE VERIFIED ===");
    console.log(`machineId=${machineId}`);
    console.log(`photoId=${photoId}`);
    console.log("manufacturerStatus=recognized_and_confirmed");
    console.log("recognizedProductEvidence=photo_confirmed");
    console.log("manualProductEvidence=manual_confirmed");
    console.log("formalPhotoStored=true");
    console.log("temporaryPhotoDeleted=true");
    console.log("");

    // 重要:
    // この時点では一時写真が既に削除されている。
    // 同一requestId再送が一時写真なしでも成功することで、
    // completed dedupe がphoto準備より先に効いていることを確認する。
    const replay = await callCreateVendingMachine(
      auth.idToken,
      input,
    );

    assert(
      replay.machineId === machineId,
      "Replay must return the original machineId.",
    );

    const afterReplayMachineCount = (
      await firestore.collection("vending_machines").get()
    ).size;

    assert(
      afterReplayMachineCount === afterFirstMachineCount,
      "Replay must not create another vending machine.",
    );

    const productsAfterReplay = await machineSnapshot.ref
      .collection("products")
      .get();

    const photosAfterReplay = await machineSnapshot.ref
      .collection("photos")
      .get();

    const revisionsAfterReplay = await machineSnapshot.ref
      .collection("revisions")
      .get();

    assert(
      productsAfterReplay.size === 2,
      "Replay must not duplicate products.",
    );
    assert(
      photosAfterReplay.size === 1,
      "Replay must not duplicate photos.",
    );
    assert(
      revisionsAfterReplay.size === 1,
      "Replay must not duplicate revisions.",
    );

    console.log("=== REPLAY VERIFIED ===");
    console.log("sameMachineId=true");
    console.log("temporaryPhotoRequiredForReplay=false");
    console.log("duplicateMachine=false");
    console.log("duplicateProducts=false");
    console.log("duplicatePhotos=false");
    console.log("duplicateRevisions=false");
    console.log("");

    console.log("=== P7-14 VERIFIED ===");
    console.log("photoFinalization=true");
    console.log("photoBindingUsed=true");
    console.log("manufacturerEvidence=true");
    console.log("productEvidence=true");
    console.log("formalStorage=true");
    console.log("sessionFinalized=true");
    console.log("idempotentReplay=true");
  } finally {
    await cleanupMachine(
      firestore,
      machineId,
    );

    await dedupeRef
      .delete()
      .catch(() => undefined);

    await sessionRef
      .delete()
      .catch(() => undefined);

    await firestore
      .collection("users")
      .doc(auth.uid)
      .delete()
      .catch(() => undefined);

    await bucket
      .file(temporaryPhotoPath)
      .delete({ignoreNotFound: true})
      .catch(() => undefined);

    await bucket
      .file(formalPhotoPath)
      .delete({ignoreNotFound: true})
      .catch(() => undefined);

    await deleteEmulatorUserBestEffort(
      auth.idToken,
    );
  }
}

void main().catch((error: unknown) => {
  console.error("P7_14_E2E_FAILED");

  if (error instanceof Error) {
    console.error(`${error.name}: ${error.message}`);
  } else {
    console.error(String(error));
  }

  process.exitCode = 1;
});
