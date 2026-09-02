import {randomUUID} from "node:crypto";

import {
  initializeApp,
} from "firebase-admin/app";
import {
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {
  getAuth,
} from "firebase-admin/auth";
import {
  getStorage,
} from "firebase-admin/storage";

import {
  deleteAccountForUser,
} from "../src/delete_account";

const PROJECT_ID = "vendingnavi";
const STORAGE_BUCKET =
  "vendingnavi.firebasestorage.app";

const AUTH_EMULATOR =
  "127.0.0.1:9099";
const FIRESTORE_EMULATOR =
  "127.0.0.1:8080";
const STORAGE_EMULATOR =
  "127.0.0.1:9199";
const FUNCTIONS_EMULATOR =
  "127.0.0.1:5001";

const FUNCTIONS_BASE =
  `http://${FUNCTIONS_EMULATOR}` +
  `/${PROJECT_ID}/us-central1`;

const TARGET_MACHINE =
  "phase_d_target_machine";
const FOREIGN_MACHINE =
  "phase_d_foreign_machine";

const TARGET_PRODUCT =
  "phase_d_product";

const TARGET_PHOTO =
  "p_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const FOREIGN_PHOTO =
  "p_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";

const TARGET_UPLOAD =
  "11111111-1111-4111-8111-111111111111";
const FOREIGN_UPLOAD =
  "22222222-2222-4222-8222-222222222222";

interface EmulatorUser {
  readonly uid: string;
  readonly email: string;
  readonly idToken: string;
}

interface AuthSignUpResponse {
  readonly localId?: string;
  readonly email?: string;
  readonly idToken?: string;
  readonly error?: unknown;
}

interface CallableEnvelope<T> {
  readonly result?: T;
  readonly data?: T;
  readonly error?: unknown;
}

interface DeleteAccountResult {
  readonly deleted: true;
  readonly summary: {
    readonly deletedDocuments: number;
    readonly anonymizedDocuments: number;
    readonly anonymizedFields: number;
    readonly temporaryStorageDeleted: true;
    readonly authenticationDeleted: true;
  };
}

function configureEnvironment(): void {
  process.env.GCLOUD_PROJECT =
    PROJECT_ID;
  process.env.GOOGLE_CLOUD_PROJECT =
    PROJECT_ID;

  process.env
    .FIREBASE_AUTH_EMULATOR_HOST =
      AUTH_EMULATOR;

  process.env
    .FIRESTORE_EMULATOR_HOST =
      FIRESTORE_EMULATOR;

  process.env
    .FIREBASE_STORAGE_EMULATOR_HOST =
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

async function createUser(
  label: string,
): Promise<EmulatorUser> {
  const email =
    `${label}-${Date.now()}-` +
    `${randomUUID().slice(0, 8)}` +
    "@example.test";

  const response = await fetch(
    `http://${AUTH_EMULATOR}` +
      "/identitytoolkit.googleapis.com/v1/" +
      "accounts:signUp?key=fake-api-key",
    {
      method: "POST",
      headers: {
        "content-type":
          "application/json",
      },
      body: JSON.stringify({
        email,
        password:
          "Phase-D-test-password-123!",
        returnSecureToken: true,
      }),
    },
  );

  const body =
    await response.json() as
      AuthSignUpResponse;

  if (
    !response.ok ||
    typeof body.localId !== "string" ||
    typeof body.idToken !== "string" ||
    typeof body.email !== "string"
  ) {
    throw new Error(
      "Auth emulator sign-up failed.",
    );
  }

  return {
    uid: body.localId,
    email: body.email,
    idToken: body.idToken,
  };
}

async function callDeleteAccount(
  token: string,
): Promise<DeleteAccountResult> {
  const response = await fetch(
    `${FUNCTIONS_BASE}/deleteAccount`,
    {
      method: "POST",
      headers: {
        authorization:
          `Bearer ${token}`,
        "content-type":
          "application/json",
      },
      body: JSON.stringify({
        data: {
          confirmation:
            "DELETE_ACCOUNT",
        },
      }),
    },
  );

  const body =
    await response.json() as
      CallableEnvelope<
        DeleteAccountResult
      >;

  if (
    !response.ok ||
    body.error !== undefined
  ) {
    throw new Error(
      `deleteAccount failed: ` +
      `${JSON.stringify(body.error)}`,
    );
  }

  const result =
    body.result ?? body.data;

  if (
    result === undefined ||
    result.deleted !== true
  ) {
    throw new Error(
      "deleteAccount result is invalid.",
    );
  }

  return result;
}

async function seedFixtures(
  target: EmulatorUser,
  foreign: EmulatorUser,
): Promise<void> {
  const db = getFirestore();
  const bucket =
    getStorage().bucket(
      STORAGE_BUCKET,
    );

  const now = Timestamp.now();

  // ------------------------------------------------------
  // users/{uid} recursive tree
  // ------------------------------------------------------

  const targetUser = db
    .collection("users")
    .doc(target.uid);

  await targetUser.set({
    accountStatus: "active",
    appDisplayName: "Target",
    createdAt: now,
    updatedAt: now,
  });

  await targetUser
    .collection("favorite_products")
    .doc("favorite-a")
    .set({
      productId: TARGET_PRODUCT,
      sortOrder: 0,
      createdAt: now,
    });

  await targetUser
    .collection("favorite_products")
    .doc("favorite-a")
    .collection("notes")
    .doc("nested-note")
    .set({
      marker: "delete-me",
    });

  await targetUser
    .collection("migration_state")
    .doc("favorite_products")
    .set({
      completedAt: now,
    });

  await db
    .collection("users")
    .doc(foreign.uid)
    .set({
      accountStatus: "active",
      appDisplayName: "Foreign",
      createdAt: now,
      updatedAt: now,
    });

  // ------------------------------------------------------
  // Operational private collections
  // ------------------------------------------------------

  await db
    .collection(
      "request_deduplication",
    )
    .doc("phase_d_target_dedupe")
    .set({
      uid: target.uid,
      requestId:
        randomUUID(),
      operation:
        "phaseDTest",
    });

  await db
    .collection(
      "request_deduplication",
    )
    .doc("phase_d_foreign_dedupe")
    .set({
      uid: foreign.uid,
      requestId:
        randomUUID(),
      operation:
        "phaseDTest",
    });

  await db
    .collection(
      "operation_rate_limits",
    )
    .doc("phase_d_target_rate")
    .set({
      uid: target.uid,
      operation:
        "createVendingMachine",
    });

  await db
    .collection(
      "operation_rate_limits",
    )
    .doc("phase_d_foreign_rate")
    .set({
      uid: foreign.uid,
      operation:
        "createVendingMachine",
    });

  await db
    .collection(
      "photo_recognition_sessions",
    )
    .doc("phase_d_target_session")
    .set({
      uid: target.uid,
      uploadId: TARGET_UPLOAD,
    });

  await db
    .collection(
      "photo_recognition_sessions",
    )
    .doc("phase_d_foreign_session")
    .set({
      uid: foreign.uid,
      uploadId: FOREIGN_UPLOAD,
    });

  // ------------------------------------------------------
  // Feedback
  // One UID match + one email-only legacy match.
  // ------------------------------------------------------

  await db
    .collection("feedback_items")
    .doc("phase_d_target_feedback_uid")
    .set({
      uid: target.uid,
      userEmail: target.email,
      message: "delete me",
    });

  await db
    .collection("feedback_items")
    .doc(
      "phase_d_target_feedback_email",
    )
    .set({
      userEmail: target.email,
      message: "legacy delete me",
    });

  await db
    .collection("feedback_items")
    .doc("phase_d_foreign_feedback")
    .set({
      uid: foreign.uid,
      userEmail: foreign.email,
      message: "preserve me",
    });

  // ------------------------------------------------------
  // Moderation records
  // Authored target records are deleted.
  // Reviewer-only target identity is anonymized.
  // ------------------------------------------------------

  await db
    .collection("machine_reports")
    .doc("phase_d_target_authored_report")
    .set({
      machineId: TARGET_MACHINE,
      reportedBy: target.uid,
      reviewedBy: foreign.uid,
      status: "new",
    });

  await db
    .collection("machine_reports")
    .doc("phase_d_target_reviewed_report")
    .set({
      machineId: TARGET_MACHINE,
      reportedBy: foreign.uid,
      reviewedBy: target.uid,
      status: "reviewed",
    });

  await db
    .collection("machine_reports")
    .doc("phase_d_foreign_report")
    .set({
      machineId: FOREIGN_MACHINE,
      reportedBy: foreign.uid,
      reviewedBy: foreign.uid,
      status: "new",
    });

  await db
    .collection("machine_corrections")
    .doc(
      "phase_d_target_authored_correction",
    )
    .set({
      machineId: TARGET_MACHINE,
      submittedBy: target.uid,
      reviewedBy: foreign.uid,
      status: "new",
    });

  await db
    .collection("machine_corrections")
    .doc(
      "phase_d_target_reviewed_correction",
    )
    .set({
      machineId: TARGET_MACHINE,
      submittedBy: foreign.uid,
      reviewedBy: target.uid,
      status: "reviewed",
    });

  await db
    .collection("machine_corrections")
    .doc("phase_d_foreign_correction")
    .set({
      machineId: FOREIGN_MACHINE,
      submittedBy: foreign.uid,
      reviewedBy: foreign.uid,
      status: "new",
    });

  // ------------------------------------------------------
  // Public vending-machine data.
  // Must remain unchanged.
  // ------------------------------------------------------

  const machine = db
    .collection("vending_machines")
    .doc(TARGET_MACHINE);

  await machine.set({
    schemaVersion: 2,
    name: "Phase D target machine",
    status: "active",
    manufacturerId: "test-maker",
    dataLevel: "productsConfirmed",
  });

  await machine
    .collection("products")
    .doc(TARGET_PRODUCT)
    .set({
      productId: TARGET_PRODUCT,
      evidenceType: "manualConfirmed",
      availability: "available",
      isActive: true,
    });

  await db
    .collection("machine_product_index")
    .doc(
      `${TARGET_MACHINE}_${TARGET_PRODUCT}`,
    )
    .set({
      machineId: TARGET_MACHINE,
      productId: TARGET_PRODUCT,
      isActive: true,
      machineStatus: "active",
    });

  await machine
    .collection("revisions")
    .doc("phase_d_target_revision")
    .set({
      updateType: "productsUpdated",
      updatedBy: target.uid,
      marker: "preserve revision",
    });

  await machine
    .collection("revisions")
    .doc("phase_d_foreign_revision")
    .set({
      updateType: "productsUpdated",
      updatedBy: foreign.uid,
      marker:
        "preserve foreign revision",
    });

  await machine
    .collection("photos")
    .doc(TARGET_PHOTO)
    .set({
      storagePath:
        `vending_machines/` +
        `${TARGET_MACHINE}/` +
        `${TARGET_PHOTO}/original.jpg`,
      status: "active",
      uploadedBy: target.uid,
      marker: "preserve photo",
    });

  await machine
    .collection("photos")
    .doc(FOREIGN_PHOTO)
    .set({
      storagePath:
        `vending_machines/` +
        `${TARGET_MACHINE}/` +
        `${FOREIGN_PHOTO}/original.jpg`,
      status: "active",
      uploadedBy: foreign.uid,
      marker: "preserve foreign photo",
    });

  // ------------------------------------------------------
  // Private machine attribution
  // ------------------------------------------------------

  const privateMachine = db
    .collection(
      "vending_machine_private",
    )
    .doc(TARGET_MACHINE);

  await privateMachine.set({
    machineId: TARGET_MACHINE,
    createdBy: target.uid,
    legacyPublicActorMetadata: {
      createdByName: "Target legacy",
      updatedBy: target.uid,
      updatedByName: "Target legacy",
      migrationRevision:
        "phase_c1_legacy_public_actor_v1",
    },
  });

  await privateMachine
    .collection("products")
    .doc(TARGET_PRODUCT)
    .set({
      productId: TARGET_PRODUCT,
      confirmedBy: target.uid,
    });

  await db
    .collection(
      "vending_machine_private",
    )
    .doc(FOREIGN_MACHINE)
    .set({
      machineId: FOREIGN_MACHINE,
      createdBy: foreign.uid,
      marker: "foreign-private",
    });

  await db
    .collection("vending_machines")
    .doc(FOREIGN_MACHINE)
    .set({
      schemaVersion: 2,
      name: "Foreign machine",
      status: "active",
    });

  // ------------------------------------------------------
  // Storage
  // ------------------------------------------------------

  await bucket
    .file(
      `machine_uploads/` +
      `${target.uid}/` +
      `${TARGET_UPLOAD}/original.jpg`,
    )
    .save(
      Buffer.from(
        "target temporary",
        "utf8",
      ),
    );

  await bucket
    .file(
      `machine_uploads/` +
      `${foreign.uid}/` +
      `${FOREIGN_UPLOAD}/original.jpg`,
    )
    .save(
      Buffer.from(
        "foreign temporary",
        "utf8",
      ),
    );

  await bucket
    .file(
      `vending_machines/` +
      `${TARGET_MACHINE}/` +
      `${TARGET_PHOTO}/original.jpg`,
    )
    .save(
      Buffer.from(
        "formal photo",
        "utf8",
      ),
    );
}

async function verifyDeletion(
  target: EmulatorUser,
  foreign: EmulatorUser,
  result: DeleteAccountResult,
  publicBefore: {
    readonly machine: string;
    readonly product: string;
    readonly index: string;
  },
): Promise<void> {
  const db = getFirestore();
  const auth = getAuth();
  const bucket =
    getStorage().bucket(
      STORAGE_BUCKET,
    );

  // Expected deletion count:
  // request_deduplication        1
  // operation_rate_limits       1
  // recognition session         1
  // feedback                    2
  // authored report             1
  // authored correction         1
  // users tree                  4
  // TOTAL                      11

  assert(
    result.summary
      .deletedDocuments === 11,
    `deletedDocuments expected 11, ` +
      `got ${result.summary.deletedDocuments}`,
  );

  // Expected anonymized documents:
  // reviewed report             1
  // reviewed correction         1
  // private machine root        1
  // private product             1
  // revision                    1
  // photo                       1
  // TOTAL                       6
  //
  // Expected anonymized fields:
  // reviewedBy                  1
  // reviewedBy                  1
  // private root                4
  // confirmedBy                 1
  // updatedBy                   1
  // uploadedBy                  1
  // TOTAL                       9

  assert(
    result.summary
      .anonymizedDocuments === 6,
    `anonymizedDocuments expected 6, ` +
      `got ${result.summary.anonymizedDocuments}`,
  );

  assert(
    result.summary
      .anonymizedFields === 9,
    `anonymizedFields expected 9, ` +
      `got ${result.summary.anonymizedFields}`,
  );

  assert(
    result.summary
      .temporaryStorageDeleted === true,
    "Temporary Storage deletion must succeed.",
  );

  assert(
    result.summary
      .authenticationDeleted === true,
    "Authentication deletion must succeed.",
  );

  // ------------------------------------------------------
  // Auth
  // ------------------------------------------------------

  let targetAuthMissing = false;

  try {
    await auth.getUser(target.uid);
  } catch (error: unknown) {
    const code =
      typeof error === "object" &&
      error !== null
        ? (
            error as {
              code?: unknown;
            }
          ).code
        : null;

    targetAuthMissing =
      code === "auth/user-not-found";
  }

  assert(
    targetAuthMissing,
    "Target Firebase Auth user must be deleted.",
  );

  const foreignAuth =
    await auth.getUser(foreign.uid);

  assert(
    foreignAuth.uid === foreign.uid,
    "Foreign Auth user must remain.",
  );

  // ------------------------------------------------------
  // users tree
  // ------------------------------------------------------

  assert(
    !(
      await db
        .collection("users")
        .doc(target.uid)
        .get()
    ).exists,
    "Target user root must be deleted.",
  );

  assert(
    !(
      await db
        .collection("users")
        .doc(target.uid)
        .collection("favorite_products")
        .doc("favorite-a")
        .get()
    ).exists,
    "Favorite product must be deleted.",
  );

  assert(
    !(
      await db
        .collection("users")
        .doc(target.uid)
        .collection("favorite_products")
        .doc("favorite-a")
        .collection("notes")
        .doc("nested-note")
        .get()
    ).exists,
    "Nested user data must be deleted recursively.",
  );

  assert(
    (
      await db
        .collection("users")
        .doc(foreign.uid)
        .get()
    ).exists,
    "Foreign user profile must remain.",
  );

  // ------------------------------------------------------
  // Operational private data
  // ------------------------------------------------------

  for (
    const [collection, id] of [
      [
        "request_deduplication",
        "phase_d_target_dedupe",
      ],
      [
        "operation_rate_limits",
        "phase_d_target_rate",
      ],
      [
        "photo_recognition_sessions",
        "phase_d_target_session",
      ],
      [
        "feedback_items",
        "phase_d_target_feedback_uid",
      ],
      [
        "feedback_items",
        "phase_d_target_feedback_email",
      ],
    ] as const
  ) {
    assert(
      !(
        await db
          .collection(collection)
          .doc(id)
          .get()
      ).exists,
      `${collection}/${id} must be deleted.`,
    );
  }

  for (
    const [collection, id] of [
      [
        "request_deduplication",
        "phase_d_foreign_dedupe",
      ],
      [
        "operation_rate_limits",
        "phase_d_foreign_rate",
      ],
      [
        "photo_recognition_sessions",
        "phase_d_foreign_session",
      ],
      [
        "feedback_items",
        "phase_d_foreign_feedback",
      ],
    ] as const
  ) {
    assert(
      (
        await db
          .collection(collection)
          .doc(id)
          .get()
      ).exists,
      `${collection}/${id} must remain.`,
    );
  }

  // ------------------------------------------------------
  // Reports / corrections
  // ------------------------------------------------------

  assert(
    !(
      await db
        .collection("machine_reports")
        .doc(
          "phase_d_target_authored_report",
        )
        .get()
    ).exists,
    "Target-authored report must be deleted.",
  );

  const reviewedReport =
    await db
      .collection("machine_reports")
      .doc(
        "phase_d_target_reviewed_report",
      )
      .get();

  assert(
    reviewedReport.exists,
    "Reviewer-only report must remain.",
  );

  assert(
    !Object.prototype.hasOwnProperty.call(
      reviewedReport.data() ?? {},
      "reviewedBy",
    ),
    "Target reviewer UID must be removed.",
  );

  assert(
    (
      await db
        .collection("machine_reports")
        .doc("phase_d_foreign_report")
        .get()
    ).data()?.reportedBy ===
      foreign.uid,
    "Foreign report must remain unchanged.",
  );

  assert(
    !(
      await db
        .collection("machine_corrections")
        .doc(
          "phase_d_target_authored_correction",
        )
        .get()
    ).exists,
    "Target-authored correction must be deleted.",
  );

  const reviewedCorrection =
    await db
      .collection("machine_corrections")
      .doc(
        "phase_d_target_reviewed_correction",
      )
      .get();

  assert(
    reviewedCorrection.exists,
    "Reviewer-only correction must remain.",
  );

  assert(
    !Object.prototype.hasOwnProperty.call(
      reviewedCorrection.data() ?? {},
      "reviewedBy",
    ),
    "Target correction reviewer UID must be removed.",
  );

  // ------------------------------------------------------
  // Public machine data unchanged
  // ------------------------------------------------------

  const machine =
    await db
      .collection("vending_machines")
      .doc(TARGET_MACHINE)
      .get();

  const product =
    await db
      .collection("vending_machines")
      .doc(TARGET_MACHINE)
      .collection("products")
      .doc(TARGET_PRODUCT)
      .get();

  const index =
    await db
      .collection("machine_product_index")
      .doc(
        `${TARGET_MACHINE}_${TARGET_PRODUCT}`,
      )
      .get();

  assert(
    JSON.stringify(
      machine.data() ?? {},
    ) === publicBefore.machine,
    "Public machine data must remain unchanged.",
  );

  assert(
    JSON.stringify(
      product.data() ?? {},
    ) === publicBefore.product,
    "Public product data must remain unchanged.",
  );

  assert(
    JSON.stringify(
      index.data() ?? {},
    ) === publicBefore.index,
    "Public index data must remain unchanged.",
  );

  // ------------------------------------------------------
  // Private attribution anonymized
  // ------------------------------------------------------

  const privateRoot =
    await db
      .collection(
        "vending_machine_private",
      )
      .doc(TARGET_MACHINE)
      .get();

  const privateData =
    privateRoot.data() ?? {};

  assert(
    privateRoot.exists,
    "Private machine root must remain.",
  );

  assert(
    !Object.prototype.hasOwnProperty.call(
      privateData,
      "createdBy",
    ),
    "Private creator UID must be removed.",
  );

  const legacy =
    privateData
      .legacyPublicActorMetadata as
        Record<string, unknown>;

  assert(
    !Object.prototype.hasOwnProperty.call(
      legacy,
      "createdByName",
    ),
    "Legacy creator name must be removed.",
  );

  assert(
    !Object.prototype.hasOwnProperty.call(
      legacy,
      "updatedBy",
    ),
    "Legacy updater UID must be removed.",
  );

  assert(
    !Object.prototype.hasOwnProperty.call(
      legacy,
      "updatedByName",
    ),
    "Legacy updater name must be removed.",
  );

  const privateProduct =
    await db
      .collection(
        "vending_machine_private",
      )
      .doc(TARGET_MACHINE)
      .collection("products")
      .doc(TARGET_PRODUCT)
      .get();

  assert(
    privateProduct.exists,
    "Private product metadata must remain.",
  );

  assert(
    !Object.prototype.hasOwnProperty.call(
      privateProduct.data() ?? {},
      "confirmedBy",
    ),
    "Product confirmer UID must be removed.",
  );

  // ------------------------------------------------------
  // Revision / photo metadata preserved but anonymized
  // ------------------------------------------------------

  const targetRevision =
    await db
      .collection("vending_machines")
      .doc(TARGET_MACHINE)
      .collection("revisions")
      .doc("phase_d_target_revision")
      .get();

  assert(
    targetRevision.exists,
    "Revision must remain.",
  );

  assert(
    !Object.prototype.hasOwnProperty.call(
      targetRevision.data() ?? {},
      "updatedBy",
    ),
    "Revision updater UID must be removed.",
  );

  const foreignRevision =
    await db
      .collection("vending_machines")
      .doc(TARGET_MACHINE)
      .collection("revisions")
      .doc("phase_d_foreign_revision")
      .get();

  assert(
    foreignRevision.data()?.updatedBy ===
      foreign.uid,
    "Foreign revision attribution must remain.",
  );

  const targetPhoto =
    await db
      .collection("vending_machines")
      .doc(TARGET_MACHINE)
      .collection("photos")
      .doc(TARGET_PHOTO)
      .get();

  assert(
    targetPhoto.exists,
    "Formal photo document must remain.",
  );

  assert(
    !Object.prototype.hasOwnProperty.call(
      targetPhoto.data() ?? {},
      "uploadedBy",
    ),
    "Photo uploader UID must be removed.",
  );

  const foreignPhoto =
    await db
      .collection("vending_machines")
      .doc(TARGET_MACHINE)
      .collection("photos")
      .doc(FOREIGN_PHOTO)
      .get();

  assert(
    foreignPhoto.data()?.uploadedBy ===
      foreign.uid,
    "Foreign photo attribution must remain.",
  );

  // ------------------------------------------------------
  // Storage
  // ------------------------------------------------------

  const [
    targetTempExists,
  ] = await bucket
    .file(
      `machine_uploads/` +
      `${target.uid}/` +
      `${TARGET_UPLOAD}/original.jpg`,
    )
    .exists();

  assert(
    !targetTempExists,
    "Target temporary upload must be deleted.",
  );

  const [
    foreignTempExists,
  ] = await bucket
    .file(
      `machine_uploads/` +
      `${foreign.uid}/` +
      `${FOREIGN_UPLOAD}/original.jpg`,
    )
    .exists();

  assert(
    foreignTempExists,
    "Foreign temporary upload must remain.",
  );

  const [
    formalPhotoExists,
  ] = await bucket
    .file(
      `vending_machines/` +
      `${TARGET_MACHINE}/` +
      `${TARGET_PHOTO}/original.jpg`,
    )
    .exists();

  assert(
    formalPhotoExists,
    "Formal public photo must remain.",
  );
}


async function verifyRetrySafety(): Promise<void> {
  const db = getFirestore();
  const auth = getAuth();

  const bucket =
    getStorage().bucket(
      STORAGE_BUCKET,
    );

  const retryUser =
    await createUser(
      "phase-d-retry",
    );

  const now = Timestamp.now();

  await db
    .collection("users")
    .doc(retryUser.uid)
    .set({
      accountStatus: "active",
      appDisplayName: "Retry User",
      createdAt: now,
      updatedAt: now,
    });

  await db
    .collection(
      "request_deduplication",
    )
    .doc("phase_d_retry_dedupe")
    .set({
      uid: retryUser.uid,
      requestId: randomUUID(),
      operation: "phaseDTest",
    });

  const retryStoragePath =
    `machine_uploads/${retryUser.uid}/` +
    `${TARGET_UPLOAD}/retry.jpg`;

  await bucket
    .file(retryStoragePath)
    .save(
      Buffer.from(
        "retry temporary",
        "utf8",
      ),
    );

  let storageDeleteAttempts = 0;

  const failingBucket = {
    async deleteFiles(
      _options: {
        readonly prefix: string;
      },
    ): Promise<void> {
      storageDeleteAttempts += 1;

      throw new Error(
        "Injected Storage deletion failure.",
      );
    },
  };

  let firstAttemptFailed = false;

  try {
    await deleteAccountForUser(
      db,
      auth,
      failingBucket,
      retryUser.uid,
    );
  } catch {
    firstAttemptFailed = true;
  }

  assert(
    firstAttemptFailed,
    "Injected pre-Auth failure must fail deletion.",
  );

  assert(
    storageDeleteAttempts === 1,
    "Injected Storage failure must be reached exactly once.",
  );

  const authAfterFailure =
    await auth.getUser(
      retryUser.uid,
    );

  assert(
    authAfterFailure.uid ===
      retryUser.uid,
    "Auth user must remain when cleanup fails before Auth deletion.",
  );

  assert(
    !(
      await db
        .collection("users")
        .doc(retryUser.uid)
        .get()
    ).exists,
    "Partial Firestore cleanup is allowed before retry.",
  );

  const [
    tempStillExists,
  ] = await bucket
    .file(retryStoragePath)
    .exists();

  assert(
    tempStillExists,
    "Failed Storage cleanup must leave the temporary object for retry.",
  );

  const retryResult =
    await deleteAccountForUser(
      db,
      auth,
      bucket,
      retryUser.uid,
    );

  assert(
    retryResult.deleted === true,
    "Retry after partial cleanup must succeed.",
  );

  let authMissingAfterRetry = false;

  try {
    await auth.getUser(
      retryUser.uid,
    );
  } catch (error: unknown) {
    const code =
      typeof error === "object" &&
      error !== null
        ? (
            error as {
              code?: unknown;
            }
          ).code
        : null;

    authMissingAfterRetry =
      code === "auth/user-not-found";
  }

  assert(
    authMissingAfterRetry,
    "Successful retry must finally delete Auth.",
  );

  const [
    tempExistsAfterRetry,
  ] = await bucket
    .file(retryStoragePath)
    .exists();

  assert(
    !tempExistsAfterRetry,
    "Successful retry must delete temporary Storage.",
  );

  console.log(
    [
      "PHASE_D2B_RETRY_VERIFIED",
      "preAuthFailureLeavesAuth=ok",
      "partialCleanupRetrySafe=ok",
      "retryDeletesStorage=ok",
      "retryDeletesAuthLast=ok",
    ].join(" "),
  );
}

async function main(): Promise<void> {
  configureEnvironment();

  const app = initializeApp({
    projectId: PROJECT_ID,
    storageBucket: STORAGE_BUCKET,
  });

  const db = getFirestore(app);

  const target =
    await createUser("phase-d-target");

  const foreign =
    await createUser("phase-d-foreign");

  await seedFixtures(
    target,
    foreign,
  );

  const machine =
    await db
      .collection("vending_machines")
      .doc(TARGET_MACHINE)
      .get();

  const product =
    await db
      .collection("vending_machines")
      .doc(TARGET_MACHINE)
      .collection("products")
      .doc(TARGET_PRODUCT)
      .get();

  const index =
    await db
      .collection("machine_product_index")
      .doc(
        `${TARGET_MACHINE}_${TARGET_PRODUCT}`,
      )
      .get();

  const publicBefore = {
    machine:
      JSON.stringify(
        machine.data() ?? {},
      ),
    product:
      JSON.stringify(
        product.data() ?? {},
      ),
    index:
      JSON.stringify(
        index.data() ?? {},
      ),
  };

  console.log(
    "=== PHASE D.2B ACCOUNT DELETION E2E ===",
  );

  const result =
    await callDeleteAccount(
      target.idToken,
    );

  await verifyDeletion(
    target,
    foreign,
    result,
    publicBefore,
  );

  await verifyRetrySafety();

  console.log(
    [
      "PHASE_D2B_VERIFIED",
      "userTreeDeleted=ok",
      "operationalDataDeleted=ok",
      "feedbackDeleted=ok",
      "authoredModerationDeleted=ok",
      "reviewerIdentityAnonymized=ok",
      "privateAttributionAnonymized=ok",
      "revisionAttributionAnonymized=ok",
      "photoAttributionAnonymized=ok",
      "publicMachinePreserved=ok",
      "publicProductPreserved=ok",
      "publicIndexPreserved=ok",
      "temporaryStorageDeleted=ok",
      "formalStoragePreserved=ok",
      "foreignDataPreserved=ok",
      "authenticationDeletedLast=ok",
      "failureKeepsAuthForRetry=ok",
      "retryAfterPartialCleanup=ok",
    ].join(" "),
  );
}

main().catch(
  (error: unknown) => {
    console.error(error);
    process.exitCode = 1;
  },
);
