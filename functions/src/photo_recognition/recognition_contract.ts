export interface RecognizeVendingMachinePhotoInput {
  readonly recognitionRequestId: string;
  readonly uploadId: string;
}

export interface ManufacturerCandidateResponse {
  readonly manufacturerId: string;
}

export interface ProductCandidateResponse {
  readonly productId: string;
}

export type RecognitionStatus = "completed" | "failed";

export interface RecognizeVendingMachinePhotoResponse {
  readonly manufacturerCandidates: readonly ManufacturerCandidateResponse[];
  readonly productCandidates: readonly ProductCandidateResponse[];
  readonly unresolvedLabels: readonly string[];
  readonly recognitionStatus: RecognitionStatus;
}

export class RecognitionRequestValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "RecognitionRequestValidationError";
  }
}

const UUID_V4_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const UPLOAD_ID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function parseRecognitionRequest(
  rawInput: unknown,
): RecognizeVendingMachinePhotoInput {
  if (
    typeof rawInput !== "object" ||
    rawInput === null ||
    Array.isArray(rawInput)
  ) {
    throw new RecognitionRequestValidationError(
      "Recognition request must be an object.",
    );
  }

  const data = rawInput as Record<string, unknown>;
  const allowedKeys = new Set(["recognitionRequestId", "uploadId"]);

  for (const key of Object.keys(data)) {
    if (!allowedKeys.has(key)) {
      throw new RecognitionRequestValidationError(
        `Unknown recognition request field: ${key}.`,
      );
    }
  }

  const recognitionRequestId = parseUuidV4(
    data.recognitionRequestId,
    "recognitionRequestId",
  );
  const uploadId = parseUploadId(data.uploadId);

  return {
    recognitionRequestId,
    uploadId,
  };
}

function parseUuidV4(value: unknown, fieldName: string): string {
  if (typeof value !== "string") {
    throw new RecognitionRequestValidationError(
      `${fieldName} must be a UUID v4 string.`,
    );
  }

  const normalized = value.trim().toLowerCase();
  if (!UUID_V4_PATTERN.test(normalized)) {
    throw new RecognitionRequestValidationError(
      `${fieldName} must be a UUID v4 string.`,
    );
  }

  return normalized;
}

function parseUploadId(value: unknown): string {
  if (typeof value !== "string") {
    throw new RecognitionRequestValidationError(
      "uploadId must be a UUID v4 string.",
    );
  }

  const normalized = value.trim().toLowerCase();
  if (!UPLOAD_ID_PATTERN.test(normalized)) {
    throw new RecognitionRequestValidationError(
      "uploadId must be a UUID v4 string.",
    );
  }

  return normalized;
}
