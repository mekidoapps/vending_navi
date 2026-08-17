import {randomUUID} from "node:crypto";

import {getApps, initializeApp} from "firebase-admin/app";
import {
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";

import {
  buildAddedPhotoId,
  buildAddVendingMachinePhotoDedupeId,
} from "../src/add_vending_machine_photo_core";
import {
  buildFormalPhotoStoragePath,
} from "../src/photo_recognition/photo_registration_finalization";
import {
  buildRecognitionSessionId,
} from "../src/photo_recognition/recognition_operation_store";

const PROJECT_ID = "vendingnavi";
const STORAGE_BUCKET =
  "vendingnavi.firebasestorage.app";

const AUTH_EMULATOR = "127.0.0.1:9099";
const FIRESTORE_EMULATOR = "127.0.0.1:8080";
const STORAGE_EMULATOR = "127.0.0.1:9199";
const FUNCTIONS_EMULATOR = "127.0.0.1:5001";

const FUNCTIONS_BASE =
  `http://${FUNCTIONS_EMULATOR}/${PROJECT_ID}/us-central1`;

const PHOTO_RECOGNIZED_PRODUCT_ID =
  "asahi_calpis";

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

interface RecognitionResult {
  readonly manufacturerCandidates: readonly {
    readonly manufacturerId: string;
  }[];
  readonly productCandidates: readonly {
    readonly productId: string;
  }[];
  readonly unresolvedLabels: readonly string[];
  readonly recognitionStatus:
    | "completed"
    | "failed";
}

interface UpdateProductsResult {
  readonly machineId: string;
  readonly updated: boolean;
  readonly changedProductIds:
    readonly string[];
}

interface AddPhotoResult {
  readonly machineId: string;
  readonly photoId: string;
  readonly added: boolean;
  readonly primaryPhotoChanged: boolean;
}

function configureEnvironment(): void {
  process.env.GCLOUD_PROJECT = PROJECT_ID;
  process.env.GOOGLE_CLOUD_PROJECT = PROJECT_ID;
  process.env.FIREBASE_AUTH_EMULATOR_HOST =
    AUTH_EMULATOR;
  process.env.FIRESTORE_EMULATOR_HOST =
    FIRESTORE_EMULATOR;
  process.env.FIREBASE_STORAGE_EMULATOR_HOST =
    STORAGE_EMULATOR;
}

function assert(
  condition: unknown,
  message = "Assertion failed.",
): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

async function createEmulatorUser():
Promise<AuthResult> {
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
          `p804-${Date.now()}-` +
          `${randomUUID().slice(0, 8)}` +
          "@example.test",
        password: "P804-test-password-123!",
        returnSecureToken: true,
      }),
    },
  );

  const body =
    await response.json() as {
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
      "Auth emulator sign-up failed: " +
        JSON.stringify(body),
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

  return await response.json() as
    CallableEnvelope<unknown>;
}

async function callFunction<T>(
  functionName: string,
  idToken: string,
  data: Record<string, unknown>,
): Promise<T> {
  const body = await rawCallable(
    functionName,
    idToken,
    data,
  );

  if (body.error !== undefined) {
    throw new Error(
      `${functionName} failed: ` +
        JSON.stringify(body.error),
    );
  }

  const result = body.result ?? body.data;

  if (result === undefined) {
    throw new Error(
      `${functionName} returned no result.`,
    );
  }

  return result as T;
}

async function createLocationOnlyMachine(
  idToken: string,
  label: string,
): Promise<CreateMachineResult> {
  return await callFunction<CreateMachineResult>(
    "createVendingMachine",
    idToken,
    {
      requestId: randomUUID(),
      registrationMethod: "locationOnly",
      location: {
        latitude: 35.681236,
        longitude: 139.767125,
      },
      name: label,
      manufacturerId: null,
      confirmedProductIds: [],
      temporaryPhotoUploadId: null,
      placeDescription: null,
      installationType: "unknown",
    },
  );
}

async function prepareRecognizedPhoto(
  bucket: ReturnType<
    ReturnType<typeof getStorage>["bucket"]
  >,
  auth: AuthResult,
): Promise<{
  readonly uploadId: string;
  readonly temporaryPath: string;
  readonly sessionId: string;
}> {
  const uploadId = randomUUID();

  const temporaryPath =
    `machine_uploads/${auth.uid}/` +
    `${uploadId}/original.jpg`;

  await bucket.file(temporaryPath).save(
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
        recognitionRequestId: randomUUID(),
        uploadId,
      },
    );

  assert(
    recognition.recognitionStatus ===
      "completed",
    "Recognition must complete.",
  );

  const recognizedIds = new Set(
    recognition.productCandidates.map(
      (candidate) => candidate.productId,
    ),
  );

  assert(
    recognizedIds.has(
      PHOTO_RECOGNIZED_PRODUCT_ID,
    ),
    "Emulator recognition fixture must resolve asahi_calpis.",
  );

  return {
    uploadId,
    temporaryPath,
    sessionId:
      buildRecognitionSessionId(
        auth.uid,
        uploadId,
      ),
  };
}

async function deleteMachineBestEffort(
  firestore: ReturnType<
    typeof getFirestore
  >,
  machineId: string,
): Promise<void> {
  const machineRef = firestore
    .collection("vending_machines")
    .doc(machineId);

  for (const subcollection of [
    "products",
    "photos",
    "revisions",
  ]) {
    const snapshot = await machineRef
      .collection(subcollection)
      .get()
      .catch(() => null);

    if (snapshot !== null) {
      for (const document of snapshot.docs) {
        await document.ref
          .delete()
          .catch(() => undefined);
      }
    }
  }

  const indexes = await firestore
    .collection("machine_product_index")
    .where("machineId", "==", machineId)
    .get()
    .catch(() => null);

  if (indexes !== null) {
    for (const document of indexes.docs) {
      await document.ref
        .delete()
        .catch(() => undefined);
    }
  }

  await machineRef
    .delete()
    .catch(() => undefined);
}

async function deleteUserDocumentsBestEffort(
  firestore: ReturnType<
    typeof getFirestore
  >,
  uid: string,
): Promise<void> {
  for (const collectionName of [
    "request_deduplication",
    "photo_recognition_sessions",
    "photo_recognition_operations",
  ]) {
    const snapshot = await firestore
      .collection(collectionName)
      .where("uid", "==", uid)
      .get()
      .catch(() => null);

    if (snapshot !== null) {
      for (const document of snapshot.docs) {
        await document.ref
          .delete()
          .catch(() => undefined);
      }
    }
  }

  await firestore
    .collection("users")
    .doc(uid)
    .delete()
    .catch(() => undefined);
}

async function main(): Promise<void> {
  configureEnvironment();

  const app =
    getApps().find(
      (candidate) =>
        candidate.name === "p804a3-e2e",
    ) ??
    initializeApp(
      {
        projectId: PROJECT_ID,
        storageBucket: STORAGE_BUCKET,
      },
      "p804a3-e2e",
    );

  const firestore = getFirestore(app);
  const bucket =
    getStorage(app).bucket(STORAGE_BUCKET);

  const productMaster = await firestore
    .collection("products")
    .doc(PHOTO_RECOGNIZED_PRODUCT_ID)
    .get();

  assert(
    productMaster.exists &&
      productMaster.data()?.isActive === true,
    "Active asahi_calpis Product master is required. Run seed:master first.",
  );

  const auth = await createEmulatorUser();

  const machineIds: string[] = [];
  const storagePaths = new Set<string>();
  const temporaryPaths = new Set<string>();

  try {
    console.log(
      "=== P8-04A3 ADD PHOTO E2E ===",
    );
    console.log(`uid=${auth.uid}`);
    console.log("");

    // ======================================================
    // 1. Create active machine.
    // ======================================================

    const created =
      await createLocationOnlyMachine(
        auth.idToken,
        "P8-04A3 photo addition",
      );

    assert(created.created === true);
    machineIds.push(created.machineId);

    const machineRef = firestore
      .collection("vending_machines")
      .doc(created.machineId);

    const machineBefore =
      await machineRef.get();

    assert(machineBefore.exists);
    assert(
      machineBefore.data()?.primaryPhotoId ===
        null,
    );

    // ======================================================
    // 2. Real temporary upload + real recognition Callable.
    // ======================================================

    const recognized =
      await prepareRecognizedPhoto(
        bucket,
        auth,
      );

    temporaryPaths.add(
      recognized.temporaryPath,
    );

    // ======================================================
    // 3. P8-02 photo-sourced product update first.
    // ======================================================

    const productUpdateRequestId =
      randomUUID();

    const productUpdate =
      await callFunction<UpdateProductsResult>(
        "updateVendingMachineProducts",
        auth.idToken,
        {
          requestId:
            productUpdateRequestId,
          machineId:
            created.machineId,
          operations: [
            {
              type: "addConfirmed",
              productId:
                PHOTO_RECOGNIZED_PRODUCT_ID,
              source: "photo",
            },
          ],
          temporaryPhotoUploadId:
            recognized.uploadId,
        },
      );

    assert(productUpdate.updated === true);

    const product = await machineRef
      .collection("products")
      .doc(PHOTO_RECOGNIZED_PRODUCT_ID)
      .get();

    assert(product.exists);
    assert(
      product.data()?.evidenceType ===
        "photo_confirmed",
    );

    const sessionRef = firestore
      .collection(
        "photo_recognition_sessions",
      )
      .doc(recognized.sessionId);

    const sessionAfterProductUpdate =
      await sessionRef.get();

    assert(
      sessionAfterProductUpdate.exists,
    );

    const boundSession =
      sessionAfterProductUpdate.data() ?? {};

    assert(
      boundSession.finalizedMachineId ===
        created.machineId,
      "P8-02 must bind recognition to the target machine.",
    );

    assert(
      boundSession.finalizedRequestId ===
        productUpdateRequestId,
    );

    assert(
      boundSession.finalizedAt instanceof
        Timestamp,
    );

    assert(
      typeof boundSession.finalizedPhotoId !==
        "string" ||
        boundSession.finalizedPhotoId
          .trim()
          .length === 0,
      "Product update must not publish the photo.",
    );

    // ======================================================
    // 4. Add the SAME recognized upload as formal photo.
    // ======================================================

    const addPhotoRequestId = randomUUID();

    const expectedPhotoId =
      buildAddedPhotoId(
        auth.uid,
        created.machineId,
        recognized.uploadId,
      );

    const formalPhotoPath =
      buildFormalPhotoStoragePath(
        created.machineId,
        expectedPhotoId,
      );

    storagePaths.add(formalPhotoPath);

    const added =
      await callFunction<AddPhotoResult>(
        "addVendingMachinePhoto",
        auth.idToken,
        {
          requestId:
            addPhotoRequestId,
          machineId:
            created.machineId,
          temporaryPhotoUploadId:
            recognized.uploadId,
        },
      );

    assert(
      added.machineId ===
        created.machineId,
    );
    assert(
      added.photoId ===
        expectedPhotoId,
    );
    assert(added.added === true);
    assert(
      added.primaryPhotoChanged === true,
      "First photo must become primary.",
    );

    const machineAfter =
      await machineRef.get();

    assert(
      machineAfter.data()?.primaryPhotoId ===
        expectedPhotoId,
    );

    const photo = await machineRef
      .collection("photos")
      .doc(expectedPhotoId)
      .get();

    assert(
      photo.exists,
      "Formal photo document must exist.",
    );

    const photoData = photo.data() ?? {};

    assert(
      photoData.storagePath ===
        formalPhotoPath,
    );
    assert(photoData.thumbnailPath === null);
    assert(photoData.status === "active");
    assert(
      photoData.uploadedBy === auth.uid,
    );
    assert(
      photoData.uploadedAt instanceof
        Timestamp,
    );
    assert(
      photoData.recognitionStatus ===
        "completed",
    );
    assert(
      typeof photoData.recognitionProvider ===
        "string" &&
        photoData.recognitionProvider
          .trim()
          .length > 0,
    );
    assert(photoData.isPrimary === true);

    const photoRevisionSnapshot =
      await machineRef
        .collection("revisions")
        .where(
          "requestId",
          "==",
          addPhotoRequestId,
        )
        .get();

    assert(
      photoRevisionSnapshot.size === 1,
      "Photo add must create exactly one matching revision.",
    );

    const photoRevision =
      photoRevisionSnapshot.docs[0].data();

    assert(
      photoRevision.updateType ===
        "photoAdded",
    );
    assert(
      photoRevision.source ===
        "photoRecognition",
    );
    assert(
      photoRevision.updatedBy ===
        auth.uid,
    );

    assert(
      Array.isArray(
        photoRevision.changedFields,
      ) &&
        photoRevision.changedFields.includes(
          "photos",
        ) &&
        photoRevision.changedFields.includes(
          "primaryPhotoId",
        ),
    );

    const sessionAfterPhoto =
      await sessionRef.get();

    const finalizedSession =
      sessionAfterPhoto.data() ?? {};

    assert(
      finalizedSession.finalizedMachineId ===
        created.machineId,
    );
    assert(
      finalizedSession.finalizedPhotoId ===
        expectedPhotoId,
    );

    // Product update audit must remain intact.
    assert(
      finalizedSession.finalizedRequestId ===
        productUpdateRequestId,
    );

    assert(
      finalizedSession.photoFinalizedRequestId ===
        addPhotoRequestId,
    );

    assert(
      finalizedSession.photoFinalizedAt instanceof
        Timestamp,
    );

    const [formalExists] =
      await bucket
        .file(formalPhotoPath)
        .exists();

    assert(formalExists);

    const [formalBytes] =
      await bucket
        .file(formalPhotoPath)
        .download();

    assert(
      Buffer.compare(
        formalBytes,
        TEST_JPEG,
      ) === 0,
      "Formal bytes must exactly match the recognized upload.",
    );

    const [temporaryExists] =
      await bucket
        .file(recognized.temporaryPath)
        .exists();

    assert(
      !temporaryExists,
      "Temporary upload must be deleted after successful photo finalization.",
    );

    const dedupeId =
      buildAddVendingMachinePhotoDedupeId(
        auth.uid,
        addPhotoRequestId,
      );

    const dedupe =
      await firestore
        .collection(
          "request_deduplication",
        )
        .doc(dedupeId)
        .get();

    assert(dedupe.exists);
    assert(
      dedupe.data()?.operation ===
        "addVendingMachinePhoto",
    );
    assert(
      dedupe.data()?.result?.photoId ===
        expectedPhotoId,
    );

    console.log(
      "photoProductBinding=ok",
    );
    console.log(
      "formalPhoto=ok",
    );
    console.log(
      "primaryPhoto=ok",
    );
    console.log(
      "revision=ok",
    );
    console.log(
      "temporaryCleanup=ok",
    );

    // ======================================================
    // 5. Same request replay succeeds WITHOUT temp photo.
    // ======================================================

    const replay =
      await callFunction<AddPhotoResult>(
        "addVendingMachinePhoto",
        auth.idToken,
        {
          requestId:
            addPhotoRequestId,
          machineId:
            created.machineId,
          temporaryPhotoUploadId:
            recognized.uploadId,
        },
      );

    assert(
      replay.photoId ===
        expectedPhotoId,
    );

    const photosAfterReplay =
      await machineRef
        .collection("photos")
        .get();

    assert(
      photosAfterReplay.size === 1,
      "Replay must not duplicate photo documents.",
    );

    const revisionsAfterReplay =
      await machineRef
        .collection("revisions")
        .where(
          "requestId",
          "==",
          addPhotoRequestId,
        )
        .get();

    assert(
      revisionsAfterReplay.size === 1,
      "Replay must not duplicate revisions.",
    );

    console.log("idempotency=ok");

    // ======================================================
    // 6. Same recognized upload + another request is rejected.
    // ======================================================

    const duplicatePublish =
      await rawCallable(
        "addVendingMachinePhoto",
        auth.idToken,
        {
          requestId: randomUUID(),
          machineId:
            created.machineId,
          temporaryPhotoUploadId:
            recognized.uploadId,
        },
      );

    assert(
      duplicatePublish.error !== undefined,
      "Already-published recognition must be rejected.",
    );

    const photosAfterDuplicate =
      await machineRef
        .collection("photos")
        .get();

    assert(
      photosAfterDuplicate.size === 1,
    );

    console.log(
      "doublePublishRejected=ok",
    );

    // ======================================================
    // 7. Restricted account is rejected BEFORE formal save.
    // ======================================================

    const restrictedMachine =
      await createLocationOnlyMachine(
        auth.idToken,
        "P8-04A3 restricted",
      );

    machineIds.push(
      restrictedMachine.machineId,
    );

    const restrictedPhoto =
      await prepareRecognizedPhoto(
        bucket,
        auth,
      );

    temporaryPaths.add(
      restrictedPhoto.temporaryPath,
    );

    const restrictedPhotoId =
      buildAddedPhotoId(
        auth.uid,
        restrictedMachine.machineId,
        restrictedPhoto.uploadId,
      );

    const restrictedFormalPath =
      buildFormalPhotoStoragePath(
        restrictedMachine.machineId,
        restrictedPhotoId,
      );

    storagePaths.add(
      restrictedFormalPath,
    );

    await firestore
      .collection("users")
      .doc(auth.uid)
      .set(
        {
          accountStatus: "restricted",
          updatedAt:
            Timestamp.fromDate(
              new Date(),
            ),
        },
        {merge: true},
      );

    const restrictedResult =
      await rawCallable(
        "addVendingMachinePhoto",
        auth.idToken,
        {
          requestId: randomUUID(),
          machineId:
            restrictedMachine.machineId,
          temporaryPhotoUploadId:
            restrictedPhoto.uploadId,
        },
      );

    assert(
      restrictedResult.error !== undefined,
      "Restricted account must be rejected.",
    );

    const [restrictedFormalExists] =
      await bucket
        .file(restrictedFormalPath)
        .exists();

    assert(
      !restrictedFormalExists,
      "Restricted request must not reserve formal Storage.",
    );

    const restrictedPhotoDoc =
      await firestore
        .collection("vending_machines")
        .doc(restrictedMachine.machineId)
        .collection("photos")
        .doc(restrictedPhotoId)
        .get();

    assert(!restrictedPhotoDoc.exists);

    const [restrictedTempExists] =
      await bucket
        .file(
          restrictedPhoto.temporaryPath,
        )
        .exists();

    assert(
      restrictedTempExists,
      "Rejected request must leave temporary upload available.",
    );

    console.log(
      "restrictedAccount=ok",
    );

    // Restore before creating the inactive-machine fixture.
    await firestore
      .collection("users")
      .doc(auth.uid)
      .set(
        {
          accountStatus: "active",
          updatedAt:
            Timestamp.fromDate(
              new Date(),
            ),
        },
        {merge: true},
      );

    // ======================================================
    // 8. Non-active machine rejected BEFORE formal save.
    // ======================================================

    const inactiveMachine =
      await createLocationOnlyMachine(
        auth.idToken,
        "P8-04A3 inactive",
      );

    machineIds.push(
      inactiveMachine.machineId,
    );

    const inactivePhoto =
      await prepareRecognizedPhoto(
        bucket,
        auth,
      );

    temporaryPaths.add(
      inactivePhoto.temporaryPath,
    );

    const inactivePhotoId =
      buildAddedPhotoId(
        auth.uid,
        inactiveMachine.machineId,
        inactivePhoto.uploadId,
      );

    const inactiveFormalPath =
      buildFormalPhotoStoragePath(
        inactiveMachine.machineId,
        inactivePhotoId,
      );

    storagePaths.add(
      inactiveFormalPath,
    );

    const inactiveMachineRef =
      firestore
        .collection("vending_machines")
        .doc(inactiveMachine.machineId);

    await inactiveMachineRef.update({
      status: "removed",
      updatedAt:
        Timestamp.fromDate(new Date()),
    });

    const inactiveResult =
      await rawCallable(
        "addVendingMachinePhoto",
        auth.idToken,
        {
          requestId: randomUUID(),
          machineId:
            inactiveMachine.machineId,
          temporaryPhotoUploadId:
            inactivePhoto.uploadId,
        },
      );

    assert(
      inactiveResult.error !== undefined,
      "Non-active machine must be rejected.",
    );

    const [inactiveFormalExists] =
      await bucket
        .file(inactiveFormalPath)
        .exists();

    assert(
      !inactiveFormalExists,
      "Non-active machine request must not reserve formal Storage.",
    );

    const [inactiveTempExists] =
      await bucket
        .file(inactivePhoto.temporaryPath)
        .exists();

    assert(inactiveTempExists);

    console.log(
      "inactiveMachine=ok",
    );

    console.log("");
    console.log(
      "P8-04A3 VERIFIED " +
        "photoProductBinding=ok " +
        "formalPhoto=ok " +
        "primaryPhoto=ok " +
        "revision=ok " +
        "temporaryCleanup=ok " +
        "idempotency=ok " +
        "doublePublishRejected=ok " +
        "restrictedAccount=ok " +
        "inactiveMachine=ok",
    );
  } finally {
    for (const path of storagePaths) {
      await bucket
        .file(path)
        .delete({ignoreNotFound: true})
        .catch(() => undefined);
    }

    for (const path of temporaryPaths) {
      await bucket
        .file(path)
        .delete({ignoreNotFound: true})
        .catch(() => undefined);
    }

    for (const machineId of machineIds) {
      await deleteMachineBestEffort(
        firestore,
        machineId,
      );
    }

    await deleteUserDocumentsBestEffort(
      firestore,
      auth.uid,
    );

    await deleteEmulatorUserBestEffort(
      auth.idToken,
    );
  }
}

void main().catch((error: unknown) => {
  console.error(
    "P8-04A3 FAILED",
    error,
  );
  process.exitCode = 1;
});
