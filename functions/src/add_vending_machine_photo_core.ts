import { createHash } from "node:crypto";

export const ADD_VENDING_MACHINE_PHOTO_OPERATION = "addVendingMachinePhoto";

const UUID_V4_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const MACHINE_ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

export interface AddVendingMachinePhotoInput {
  readonly requestId: string;
  readonly machineId: string;
  readonly temporaryPhotoUploadId: string;
}

export interface AddVendingMachinePhotoResult {
  readonly machineId: string;
  readonly photoId: string;
  readonly added: boolean;
  readonly primaryPhotoChanged: boolean;
}

export function parseAddVendingMachinePhotoInput(
  raw: unknown,
): AddVendingMachinePhotoInput {
  if (!isPlainObject(raw)) {
    throw new TypeError("Request must be an object.");
  }

  expectOnlyKeys(
    raw,
    new Set(["requestId", "machineId", "temporaryPhotoUploadId"]),
  );

  const requestId = parseUuidV4(raw.requestId, "requestId");

  const machineId = parseMachineId(raw.machineId);

  const temporaryPhotoUploadId = parseUuidV4(
    raw.temporaryPhotoUploadId,
    "temporaryPhotoUploadId",
  );

  return {
    requestId,
    machineId,
    temporaryPhotoUploadId,
  };
}

export function buildAddVendingMachinePhotoDedupeId(
  uid: string,
  requestId: string,
): string {
  const normalizedUid = uid.trim();
  const normalizedRequestId = requestId.trim();

  if (
    normalizedUid.length === 0 ||
    !UUID_V4_PATTERN.test(normalizedRequestId)
  ) {
    throw new TypeError("uid and RFC 4122 UUID v4 requestId are required.");
  }

  return sha256(
    `${normalizedUid}|${ADD_VENDING_MACHINE_PHOTO_OPERATION}|${normalizedRequestId}`,
  );
}

export function buildAddedPhotoId(
  uid: string,
  machineId: string,
  uploadId: string,
): string {
  const normalizedUid = uid.trim();
  const normalizedMachineId = parseMachineId(machineId);
  const normalizedUploadId = parseUuidV4(uploadId, "temporaryPhotoUploadId");

  if (normalizedUid.length === 0) {
    throw new TypeError("uid must not be empty.");
  }

  // One recognized upload can become at most one formal photo
  // for a given machine. Keeping requestId out of this identity
  // prevents concurrent retries from reserving different Storage
  // objects for the same recognized image.
  const seed = `${normalizedUid}|${normalizedMachineId}|${normalizedUploadId}`;

  return `p_${sha256(`photo-add|${seed}`).slice(0, 30)}`;
}

export function parseStoredAddVendingMachinePhotoResult(
  raw: unknown,
): AddVendingMachinePhotoResult {
  if (!isPlainObject(raw)) {
    throw new TypeError("Stored result must be an object.");
  }

  expectOnlyKeys(
    raw,
    new Set(["machineId", "photoId", "added", "primaryPhotoChanged"]),
  );

  const machineId = parseMachineId(raw.machineId);

  if (
    typeof raw.photoId !== "string" ||
    !/^p_[0-9a-f]{30}$/.test(raw.photoId.trim())
  ) {
    throw new TypeError("Stored photoId is invalid.");
  }

  if (
    typeof raw.added !== "boolean" ||
    typeof raw.primaryPhotoChanged !== "boolean"
  ) {
    throw new TypeError("Stored result flags are invalid.");
  }

  return {
    machineId,
    photoId: raw.photoId.trim(),
    added: raw.added,
    primaryPhotoChanged: raw.primaryPhotoChanged,
  };
}

function parseUuidV4(raw: unknown, fieldName: string): string {
  if (typeof raw !== "string") {
    throw new TypeError(`${fieldName} must be a string.`);
  }

  const normalized = raw.trim();

  if (!UUID_V4_PATTERN.test(normalized)) {
    throw new TypeError(`${fieldName} must be an RFC 4122 UUID v4.`);
  }

  return normalized;
}

function parseMachineId(raw: unknown): string {
  if (typeof raw !== "string") {
    throw new TypeError("machineId must be a string.");
  }

  const normalized = raw.trim();

  if (!MACHINE_ID_PATTERN.test(normalized)) {
    throw new TypeError("machineId is invalid.");
  }

  return normalized;
}

function expectOnlyKeys(
  value: Record<string, unknown>,
  expected: ReadonlySet<string>,
): void {
  for (const key of Object.keys(value)) {
    if (!expected.has(key)) {
      throw new TypeError(`Unexpected request field: ${key}.`);
    }
  }

  for (const key of expected) {
    if (!(key in value)) {
      throw new TypeError(`Missing request field: ${key}.`);
    }
  }
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function sha256(value: string): string {
  return createHash("sha256").update(value, "utf8").digest("hex");
}
