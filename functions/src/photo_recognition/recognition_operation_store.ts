import {createHash} from "node:crypto";

import type {
  DocumentData,
  Firestore,
} from "firebase-admin/firestore";
import {Timestamp} from "firebase-admin/firestore";

import type {
  RecognizeVendingMachinePhotoResponse,
  RecognitionStatus,
} from "./recognition_contract";
import type {
  TemporaryPhotoBinding,
} from "./temporary_photo_binding";

export const RECOGNITION_OPERATION =
  "recognizeVendingMachinePhoto";
const PROCESSING_STALE_MS = 2 * 60 * 1000;
const SESSION_TTL_MS = 24 * 60 * 60 * 1000;

export interface StoredRecognitionResult {
  readonly providerKey: string;
  readonly response: RecognizeVendingMachinePhotoResponse;
  readonly photoBinding?: TemporaryPhotoBinding | null;
}

export type RecognitionOperationClaim =
  | {readonly kind: "claimed"}
  | {
      readonly kind: "replay";
      readonly result: StoredRecognitionResult;
    };

export interface RecognitionOperationStore {
  claim(
    uid: string,
    recognitionRequestId: string,
    uploadId: string,
  ): Promise<RecognitionOperationClaim>;

  complete(
    uid: string,
    recognitionRequestId: string,
    uploadId: string,
    result: StoredRecognitionResult,
  ): Promise<void>;
}

export class RecognitionOperationInProgressError extends Error {
  constructor() {
    super("Photo recognition is already in progress.");
    this.name = "RecognitionOperationInProgressError";
  }
}

export class RecognitionOperationDataError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "RecognitionOperationDataError";
  }
}

export class FirestoreRecognitionOperationStore
implements RecognitionOperationStore {
  constructor(
    private readonly firestore: Firestore,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async claim(
    uid: string,
    recognitionRequestId: string,
    uploadId: string,
  ): Promise<RecognitionOperationClaim> {
    const operationId = buildRecognitionOperationId(
      uid,
      recognitionRequestId,
    );
    const operationRef = this.firestore
      .collection("request_deduplication")
      .doc(operationId);

    return this.firestore.runTransaction<RecognitionOperationClaim>(
      async (transaction) => {
        const snapshot = await transaction.get(operationRef);
        const currentNow = this.now();

        if (snapshot.exists) {
          const data = snapshot.data();
          validateOperationIdentity(
            data,
            uid,
            recognitionRequestId,
            uploadId,
          );

          const status = data?.status;
          if (status === "completed" || status === "failed") {
            return {
              kind: "replay",
              result: parseStoredRecognitionResult(data?.result),
            };
          }

          if (status !== "processing") {
            throw new RecognitionOperationDataError(
              "Recognition operation has an invalid status.",
            );
          }

          const updatedAt = parseTimestampDate(data?.updatedAt);
          if (
            currentNow.getTime() - updatedAt.getTime() <
            PROCESSING_STALE_MS
          ) {
            throw new RecognitionOperationInProgressError();
          }

          transaction.update(operationRef, {
            status: "processing",
            updatedAt: Timestamp.fromDate(currentNow),
          });
          return {kind: "claimed"};
        }

        transaction.create(operationRef, {
          operation: RECOGNITION_OPERATION,
          uid,
          recognitionRequestId,
          uploadId,
          sessionId: buildRecognitionSessionId(uid, uploadId),
          status: "processing",
          provider: null,
          result: null,
          createdAt: Timestamp.fromDate(currentNow),
          updatedAt: Timestamp.fromDate(currentNow),
        });

        return {kind: "claimed"};
      },
    );
  }

  async complete(
    uid: string,
    recognitionRequestId: string,
    uploadId: string,
    result: StoredRecognitionResult,
  ): Promise<void> {
    const operationId = buildRecognitionOperationId(
      uid,
      recognitionRequestId,
    );
    const sessionId = buildRecognitionSessionId(uid, uploadId);
    const operationRef = this.firestore
      .collection("request_deduplication")
      .doc(operationId);
    const sessionRef = this.firestore
      .collection("photo_recognition_sessions")
      .doc(sessionId);

    await this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(operationRef);
      if (!snapshot.exists) {
        throw new RecognitionOperationDataError(
          "Recognition operation reservation is missing.",
        );
      }

      validateOperationIdentity(
        snapshot.data(),
        uid,
        recognitionRequestId,
        uploadId,
      );

      const currentNow = this.now();
      const recognizedAt = Timestamp.fromDate(currentNow);
      const expiresAt = Timestamp.fromDate(
        new Date(currentNow.getTime() + SESSION_TTL_MS),
      );
      const binding = result.photoBinding ?? null;

      transaction.update(operationRef, {
        status: result.response.recognitionStatus,
        provider: result.providerKey,
        result,
        updatedAt: recognizedAt,
      });

      transaction.set(sessionRef, {
        uid,
        uploadId,
        status: result.response.recognitionStatus,
        provider: result.providerKey,
        manufacturerCandidateIds:
          result.response.manufacturerCandidates.map(
            (item) => item.manufacturerId,
          ),
        productCandidateIds:
          result.response.productCandidates.map(
            (item) => item.productId,
          ),
        photoObjectPath: binding?.objectPath ?? null,
        photoContentSha256: binding?.contentSha256 ?? null,
        photoSizeBytes: binding?.sizeBytes ?? null,
        recognizedAt,
        expiresAt,
      });
    });
  }
}

export function buildRecognitionOperationId(
  uid: string,
  recognitionRequestId: string,
): string {
  return sha256(
    `${RECOGNITION_OPERATION}:${uid}:${recognitionRequestId}`,
  );
}

export function buildRecognitionSessionId(
  uid: string,
  uploadId: string,
): string {
  return sha256(`photoRecognitionSession:${uid}:${uploadId}`);
}

export function parseStoredRecognitionResult(
  value: unknown,
): StoredRecognitionResult {
  if (
    typeof value !== "object" ||
    value === null ||
    Array.isArray(value)
  ) {
    throw new RecognitionOperationDataError(
      "Stored recognition result is invalid.",
    );
  }

  const record = value as Record<string, unknown>;
  const providerKey =
    typeof record.providerKey === "string" ?
      record.providerKey.trim() :
      "";
  if (providerKey.length === 0) {
    throw new RecognitionOperationDataError(
      "Stored recognition provider is invalid.",
    );
  }

  const response = parseStoredResponse(record.response);
  const base: StoredRecognitionResult = {
    providerKey,
    response,
  };

  if (!Object.prototype.hasOwnProperty.call(record, "photoBinding")) {
    return base;
  }

  return {
    ...base,
    photoBinding: parseStoredPhotoBinding(record.photoBinding),
  };
}

function parseStoredPhotoBinding(
  value: unknown,
): TemporaryPhotoBinding | null {
  if (value === null) {
    return null;
  }

  if (
    typeof value !== "object" ||
    Array.isArray(value)
  ) {
    throw new RecognitionOperationDataError(
      "Stored photo binding is invalid.",
    );
  }

  const record = value as Record<string, unknown>;
  const objectPath =
    typeof record.objectPath === "string" ?
      record.objectPath.trim() :
      "";
  const contentSha256 =
    typeof record.contentSha256 === "string" ?
      record.contentSha256.trim().toLowerCase() :
      "";
  const sizeBytes = record.sizeBytes;

  if (
    objectPath.length === 0 ||
    !/^[0-9a-f]{64}$/.test(contentSha256) ||
    !Number.isSafeInteger(sizeBytes) ||
    (sizeBytes as number) <= 0
  ) {
    throw new RecognitionOperationDataError(
      "Stored photo binding is invalid.",
    );
  }

  return {
    objectPath,
    contentSha256,
    sizeBytes: sizeBytes as number,
  };
}

function parseStoredResponse(
  value: unknown,
): RecognizeVendingMachinePhotoResponse {
  if (
    typeof value !== "object" ||
    value === null ||
    Array.isArray(value)
  ) {
    throw new RecognitionOperationDataError(
      "Stored recognition response is invalid.",
    );
  }

  const record = value as Record<string, unknown>;
  const recognitionStatus = parseRecognitionStatus(
    record.recognitionStatus,
  );

  return {
    manufacturerCandidates: parseCandidateArray(
      record.manufacturerCandidates,
      "manufacturerId",
    ).map((manufacturerId) => ({manufacturerId})),
    productCandidates: parseCandidateArray(
      record.productCandidates,
      "productId",
    ).map((productId) => ({productId})),
    unresolvedLabels: parseStringArray(record.unresolvedLabels),
    recognitionStatus,
  };
}

function parseRecognitionStatus(
  value: unknown,
): RecognitionStatus {
  if (value === "completed" || value === "failed") {
    return value;
  }
  throw new RecognitionOperationDataError(
    "Stored recognition status is invalid.",
  );
}

function parseCandidateArray(
  value: unknown,
  idField: "manufacturerId" | "productId",
): readonly string[] {
  if (!Array.isArray(value)) {
    throw new RecognitionOperationDataError(
      "Stored recognition candidates are invalid.",
    );
  }

  return value.map((item) => {
    if (
      typeof item !== "object" ||
      item === null ||
      Array.isArray(item)
    ) {
      throw new RecognitionOperationDataError(
        "Stored recognition candidate is invalid.",
      );
    }

    const rawId = (item as Record<string, unknown>)[idField];
    if (typeof rawId !== "string" || rawId.trim().length === 0) {
      throw new RecognitionOperationDataError(
        "Stored recognition candidate ID is invalid.",
      );
    }
    return rawId.trim();
  });
}

function parseStringArray(value: unknown): readonly string[] {
  if (!Array.isArray(value)) {
    throw new RecognitionOperationDataError(
      "Stored unresolved labels are invalid.",
    );
  }

  return value.map((item) => {
    if (typeof item !== "string") {
      throw new RecognitionOperationDataError(
        "Stored unresolved label is invalid.",
      );
    }
    return item;
  });
}

function validateOperationIdentity(
  data: DocumentData | undefined,
  uid: string,
  recognitionRequestId: string,
  uploadId: string,
): void {
  if (
    data?.operation !== RECOGNITION_OPERATION ||
    data?.uid !== uid ||
    data?.recognitionRequestId !== recognitionRequestId ||
    data?.uploadId !== uploadId
  ) {
    throw new RecognitionOperationDataError(
      "Recognition operation identity does not match.",
    );
  }
}

function parseTimestampDate(value: unknown): Date {
  if (
    typeof value === "object" &&
    value !== null &&
    "toDate" in value &&
    typeof (value as {toDate?: unknown}).toDate === "function"
  ) {
    const date = (
      value as {toDate: () => Date}
    ).toDate();
    if (Number.isFinite(date.getTime())) {
      return date;
    }
  }

  throw new RecognitionOperationDataError(
    "Recognition operation timestamp is invalid.",
  );
}

function sha256(value: string): string {
  return createHash("sha256").update(value, "utf8").digest("hex");
}
