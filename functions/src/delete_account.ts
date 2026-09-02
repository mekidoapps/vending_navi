import type {Auth} from "firebase-admin/auth";
import {
  FieldValue,
  type DocumentData,
  type DocumentReference,
  type Firestore,
} from "firebase-admin/firestore";

interface AccountDeletionBucket {
  deleteFiles(
    options: {readonly prefix: string},
  ): Promise<unknown>;
}

export interface DeleteAccountResult {
  readonly deleted: true;
  readonly summary: {
    readonly deletedDocuments: number;
    readonly anonymizedDocuments: number;
    readonly anonymizedFields: number;
    readonly temporaryStorageDeleted: true;
    readonly authenticationDeleted: true;
  };
}

interface MutableSummary {
  deletedDocuments: number;
  anonymizedDocuments: number;
  anonymizedFields: number;
}

export async function deleteAccountForUser(
  firestore: Firestore,
  auth: Pick<Auth, "getUser" | "deleteUser">,
  bucket: AccountDeletionBucket,
  uid: string,
): Promise<DeleteAccountResult> {
  const normalizedUid = uid.trim();

  if (normalizedUid.length === 0) {
    throw new TypeError(
      "Authenticated UID is required.",
    );
  }

  const summary: MutableSummary = {
    deletedDocuments: 0,
    anonymizedDocuments: 0,
    anonymizedFields: 0,
  };

  const email =
    await readAccountEmail(
      auth,
      normalizedUid,
    );

  // ------------------------------------------------------
  // 1. Delete private user-owned operational data.
  //
  // All operations before Auth deletion are intentionally
  // retry-safe. A partial failure leaves the Auth account
  // available so the user can retry deletion.
  // ------------------------------------------------------

  summary.deletedDocuments +=
    await deleteRootDocumentsByField(
      firestore,
      "request_deduplication",
      "uid",
      normalizedUid,
    );

  summary.deletedDocuments +=
    await deleteRootDocumentsByField(
      firestore,
      "operation_rate_limits",
      "uid",
      normalizedUid,
    );

  summary.deletedDocuments +=
    await deleteRootDocumentsByField(
      firestore,
      "photo_recognition_sessions",
      "uid",
      normalizedUid,
    );

  summary.deletedDocuments +=
    await deleteFeedbackDocuments(
      firestore,
      normalizedUid,
      email,
    );

  summary.deletedDocuments +=
    await deleteAuthoredModerationDocuments(
      firestore,
      "machine_reports",
      "reportedBy",
      normalizedUid,
    );

  summary.deletedDocuments +=
    await deleteAuthoredModerationDocuments(
      firestore,
      "machine_corrections",
      "submittedBy",
      normalizedUid,
    );

  // A deleted account may theoretically have acted as a
  // reviewer. Keep the moderation record, but remove the
  // reviewer identity.
  await anonymizeRootDocumentsByField(
    firestore,
    "machine_reports",
    "reviewedBy",
    normalizedUid,
    ["reviewedBy"],
    summary,
  );

  await anonymizeRootDocumentsByField(
    firestore,
    "machine_corrections",
    "reviewedBy",
    normalizedUid,
    ["reviewedBy"],
    summary,
  );

  // ------------------------------------------------------
  // 2. Remove attribution from server-only machine data.
  // ------------------------------------------------------

  await anonymizePrivateMachineData(
    firestore,
    normalizedUid,
    summary,
  );

  // ------------------------------------------------------
  // 3. Preserve public machine/photo/history content while
  // removing the deleted user's internal actor identity.
  // ------------------------------------------------------

  await anonymizeMachineAuditData(
    firestore,
    normalizedUid,
    summary,
  );

  // ------------------------------------------------------
  // 4. Delete users/{uid} and every nested subcollection.
  // This includes favorite_products and migration_state,
  // without hard-coding only today's subcollections.
  // ------------------------------------------------------

  summary.deletedDocuments +=
    await deleteDocumentTree(
      firestore
        .collection("users")
        .doc(normalizedUid),
    );

  // ------------------------------------------------------
  // 5. Delete temporary private uploads immediately.
  // Formal/public vending-machine photos are retained and
  // have already had uploadedBy anonymized above.
  // ------------------------------------------------------

  await bucket.deleteFiles({
    prefix:
      `machine_uploads/${normalizedUid}/`,
  });

  // ------------------------------------------------------
  // 6. Firebase Authentication MUST be last.
  //
  // If anything above fails, Auth remains and deletion can
  // be retried. user-not-found is accepted for a retry
  // whose prior Auth deletion succeeded but response was
  // lost.
  // ------------------------------------------------------

  try {
    await auth.deleteUser(normalizedUid);
  } catch (error: unknown) {
    if (!isAuthUserNotFound(error)) {
      throw error;
    }
  }

  return {
    deleted: true,
    summary: {
      ...summary,
      temporaryStorageDeleted: true,
      authenticationDeleted: true,
    },
  };
}

async function readAccountEmail(
  auth: Pick<Auth, "getUser">,
  uid: string,
): Promise<string | null> {
  try {
    const user = await auth.getUser(uid);
    const normalized =
      user.email?.trim() ?? "";

    return normalized.length > 0
      ? normalized
      : null;
  } catch (error: unknown) {
    if (isAuthUserNotFound(error)) {
      return null;
    }

    throw error;
  }
}

async function deleteFeedbackDocuments(
  firestore: Firestore,
  uid: string,
  email: string | null,
): Promise<number> {
  const refs =
    new Map<string, DocumentReference>();

  const byUid = await firestore
    .collection("feedback_items")
    .where("uid", "==", uid)
    .get();

  for (const doc of byUid.docs) {
    refs.set(doc.ref.path, doc.ref);
  }

  if (email !== null) {
    const byEmail = await firestore
      .collection("feedback_items")
      .where("userEmail", "==", email)
      .get();

    for (const doc of byEmail.docs) {
      refs.set(doc.ref.path, doc.ref);
    }
  }

  for (const ref of refs.values()) {
    await ref.delete();
  }

  return refs.size;
}

async function deleteRootDocumentsByField(
  firestore: Firestore,
  collectionName: string,
  field: string,
  value: string,
): Promise<number> {
  const snapshot = await firestore
    .collection(collectionName)
    .where(field, "==", value)
    .get();

  for (const doc of snapshot.docs) {
    await doc.ref.delete();
  }

  return snapshot.size;
}

async function deleteAuthoredModerationDocuments(
  firestore: Firestore,
  collectionName: string,
  actorField: string,
  uid: string,
): Promise<number> {
  return deleteRootDocumentsByField(
    firestore,
    collectionName,
    actorField,
    uid,
  );
}

async function anonymizeRootDocumentsByField(
  firestore: Firestore,
  collectionName: string,
  queryField: string,
  uid: string,
  deleteFields: readonly string[],
  summary: MutableSummary,
): Promise<void> {
  const snapshot = await firestore
    .collection(collectionName)
    .where(queryField, "==", uid)
    .get();

  for (const doc of snapshot.docs) {
    await deleteFieldsFromDocument(
      doc.ref,
      deleteFields,
      summary,
    );
  }
}

async function anonymizePrivateMachineData(
  firestore: Firestore,
  uid: string,
  summary: MutableSummary,
): Promise<void> {
  const roots = await firestore
    .collection("vending_machine_private")
    .get();

  for (const root of roots.docs) {
    const data = root.data();
    const fields = new Set<string>();

    const legacy =
      readObject(
        data.legacyPublicActorMetadata,
      );

    if (data.createdBy === uid) {
      fields.add("createdBy");

      if (
        legacy !== null &&
        Object.prototype.hasOwnProperty.call(
          legacy,
          "createdByName",
        )
      ) {
        fields.add(
          "legacyPublicActorMetadata.createdByName",
        );
      }
    }

    if (
      legacy !== null &&
      legacy.updatedBy === uid
    ) {
      fields.add(
        "legacyPublicActorMetadata.updatedBy",
      );

      if (
        Object.prototype.hasOwnProperty.call(
          legacy,
          "updatedByName",
        )
      ) {
        fields.add(
          "legacyPublicActorMetadata.updatedByName",
        );
      }
    }

    if (fields.size > 0) {
      await deleteFieldsFromDocument(
        root.ref,
        [...fields],
        summary,
      );
    }

    const products =
      await root.ref
        .collection("products")
        .get();

    for (const product of products.docs) {
      if (
        product.data().confirmedBy === uid
      ) {
        await deleteFieldsFromDocument(
          product.ref,
          ["confirmedBy"],
          summary,
        );
      }
    }
  }
}

async function anonymizeMachineAuditData(
  firestore: Firestore,
  uid: string,
  summary: MutableSummary,
): Promise<void> {
  const machines = await firestore
    .collection("vending_machines")
    .get();

  for (const machine of machines.docs) {
    const revisions =
      await machine.ref
        .collection("revisions")
        .get();

    for (const revision of revisions.docs) {
      if (
        revision.data().updatedBy === uid
      ) {
        await deleteFieldsFromDocument(
          revision.ref,
          ["updatedBy"],
          summary,
        );
      }
    }

    const photos =
      await machine.ref
        .collection("photos")
        .get();

    for (const photo of photos.docs) {
      if (
        photo.data().uploadedBy === uid
      ) {
        await deleteFieldsFromDocument(
          photo.ref,
          ["uploadedBy"],
          summary,
        );
      }
    }
  }
}

async function deleteFieldsFromDocument(
  ref: DocumentReference,
  fields: readonly string[],
  summary: MutableSummary,
): Promise<void> {
  const uniqueFields =
    [...new Set(fields)];

  if (uniqueFields.length === 0) {
    return;
  }

  const patch:
    Record<string, unknown> = {};

  for (const field of uniqueFields) {
    patch[field] =
      FieldValue.delete();
  }

  await ref.update(patch);

  summary.anonymizedDocuments += 1;
  summary.anonymizedFields +=
    uniqueFields.length;
}

async function deleteDocumentTree(
  ref: DocumentReference,
): Promise<number> {
  let deleted = 0;

  const childCollections =
    await ref.listCollections();

  for (
    const collection of
      childCollections
  ) {
    const snapshot =
      await collection.get();

    for (const child of snapshot.docs) {
      deleted +=
        await deleteDocumentTree(
          child.ref,
        );
    }
  }

  const snapshot = await ref.get();

  if (snapshot.exists) {
    await ref.delete();
    deleted += 1;
  }

  return deleted;
}

function readObject(
  value: unknown,
): DocumentData | null {
  if (
    typeof value !== "object" ||
    value === null ||
    Array.isArray(value)
  ) {
    return null;
  }

  return value as DocumentData;
}

function isAuthUserNotFound(
  error: unknown,
): boolean {
  if (
    typeof error !== "object" ||
    error === null
  ) {
    return false;
  }

  const code =
    (error as {code?: unknown}).code;

  return code ===
    "auth/user-not-found";
}
