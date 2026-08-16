import {createHash} from "node:crypto";

export const CREATE_VENDING_MACHINE_OPERATION = "createVendingMachine";
export const MACHINE_GEOHASH_PRECISION = 6;
export const MAX_MACHINE_NAME_LENGTH = 60;
export const MAX_PLACE_DESCRIPTION_LENGTH = 120;
export const MAX_CONFIRMED_PRODUCT_IDS = 50;

const UUID_V4_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const MASTER_ID_PATTERN = /^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$/;
const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";

export type RegistrationMethod = "photo" | "manufacturer" | "locationOnly";
export type InstallationType = "outdoor" | "indoor" | "unknown";
export type ProductEvidenceType =
  | "manual_confirmed"
  | "photo_confirmed"
  | "manufacturer_inferred";

export interface CreateVendingMachineInput {
  readonly requestId: string;
  readonly registrationMethod: RegistrationMethod;
  readonly location: {
    readonly latitude: number;
    readonly longitude: number;
  };
  readonly name: string | null;
  readonly manufacturerId: string | null;
  readonly confirmedProductIds: readonly string[];
  readonly temporaryPhotoUploadId: string | null;
  readonly placeDescription: string | null;
  readonly installationType: InstallationType;
}

export interface ProductWritePlan {
  readonly productId: string;
  readonly evidenceType: ProductEvidenceType;
  readonly availability: "available" | "unknown";
  readonly isConfirmed: boolean;
}

export class CreateVendingMachineValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CreateVendingMachineValidationError";
  }
}

export function parseCreateVendingMachineInput(
  raw: unknown,
): CreateVendingMachineInput {
  const data = requirePlainObject(raw, "request");

  assertOnlyKeys(data, [
    "requestId",
    "registrationMethod",
    "location",
    "name",
    "manufacturerId",
    "confirmedProductIds",
    "temporaryPhotoUploadId",
    "placeDescription",
    "installationType",
  ]);

  const requestId = requireString(data.requestId, "requestId").trim();
  if (!UUID_V4_PATTERN.test(requestId)) {
    throw new CreateVendingMachineValidationError(
      "requestId must be an RFC 4122 UUID v4.",
    );
  }

  const registrationMethod = parseRegistrationMethod(data.registrationMethod);
  const location = parseLocation(data.location);
  const name = parseOptionalString(
    data.name,
    "name",
    MAX_MACHINE_NAME_LENGTH,
  );
  const manufacturerId = parseOptionalMasterId(
    data.manufacturerId,
    "manufacturerId",
  );
  const confirmedProductIds = parseProductIds(data.confirmedProductIds);
  const temporaryPhotoUploadId = parseOptionalString(
    data.temporaryPhotoUploadId,
    "temporaryPhotoUploadId",
    120,
  );
  const placeDescription = parseOptionalString(
    data.placeDescription,
    "placeDescription",
    MAX_PLACE_DESCRIPTION_LENGTH,
  );
  const installationType = parseInstallationType(data.installationType);

  if (registrationMethod === "manufacturer" && manufacturerId === null) {
    throw new CreateVendingMachineValidationError(
      "manufacturer registration requires manufacturerId.",
    );
  }

  if (registrationMethod === "locationOnly") {
    if (manufacturerId !== null) {
      throw new CreateVendingMachineValidationError(
        "locationOnly registration must not contain manufacturerId.",
      );
    }
    if (confirmedProductIds.length > 0) {
      throw new CreateVendingMachineValidationError(
        "locationOnly registration must not contain confirmedProductIds.",
      );
    }
    if (temporaryPhotoUploadId !== null) {
      throw new CreateVendingMachineValidationError(
        "locationOnly registration must not contain temporaryPhotoUploadId.",
      );
    }
  }

  if (registrationMethod === "manufacturer" &&
      temporaryPhotoUploadId !== null) {
    throw new CreateVendingMachineValidationError(
      "manufacturer registration must not contain temporaryPhotoUploadId.",
    );
  }

  if (registrationMethod === "photo") {
    if (temporaryPhotoUploadId === null) {
      throw new CreateVendingMachineValidationError(
        "photo registration requires temporaryPhotoUploadId.",
      );
    }
    if (!UUID_V4_PATTERN.test(temporaryPhotoUploadId)) {
      throw new CreateVendingMachineValidationError(
        "temporaryPhotoUploadId must be an RFC 4122 UUID v4.",
      );
    }
  }

  return {
    requestId,
    registrationMethod,
    location,
    name,
    manufacturerId,
    confirmedProductIds,
    temporaryPhotoUploadId,
    placeDescription,
    installationType,
  };
}

export function encodeGeohash(
  latitude: number,
  longitude: number,
  precision = MACHINE_GEOHASH_PRECISION,
): string {
  if (
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    latitude < -90 ||
    latitude > 90 ||
    longitude < -180 ||
    longitude > 180 ||
    !Number.isInteger(precision) ||
    precision < 1 ||
    precision > 12
  ) {
    throw new CreateVendingMachineValidationError(
      "Invalid geohash coordinates or precision.",
    );
  }

  let latitudeMin = -90;
  let latitudeMax = 90;
  let longitudeMin = -180;
  let longitudeMax = 180;

  let result = "";
  let evenBit = true;
  let bit = 0;
  let character = 0;

  while (result.length < precision) {
    if (evenBit) {
      const midpoint = (longitudeMin + longitudeMax) / 2;
      if (longitude >= midpoint) {
        character |= 1 << (4 - bit);
        longitudeMin = midpoint;
      } else {
        longitudeMax = midpoint;
      }
    } else {
      const midpoint = (latitudeMin + latitudeMax) / 2;
      if (latitude >= midpoint) {
        character |= 1 << (4 - bit);
        latitudeMin = midpoint;
      } else {
        latitudeMax = midpoint;
      }
    }

    evenBit = !evenBit;

    if (bit < 4) {
      bit += 1;
      continue;
    }

    result += BASE32[character];
    bit = 0;
    character = 0;
  }

  return result;
}

export function buildRequestDeduplicationId(
  uid: string,
  requestId: string,
): string {
  const normalizedUid = uid.trim();
  if (normalizedUid.length === 0) {
    throw new CreateVendingMachineValidationError("uid must not be empty.");
  }
  if (!UUID_V4_PATTERN.test(requestId)) {
    throw new CreateVendingMachineValidationError(
      "requestId must be an RFC 4122 UUID v4.",
    );
  }

  return createHash("sha256")
    .update(
      `${normalizedUid}|${CREATE_VENDING_MACHINE_OPERATION}|${requestId}`,
      "utf8",
    )
    .digest("hex");
}

export function buildAutoMachineName(
  manufacturerDisplayShortName: string | null,
): string {
  const normalized = manufacturerDisplayShortName?.trim() ?? "";
  if (normalized.length === 0) {
    return "自販機";
  }

  const candidate = `${normalized}の自販機`;
  if (candidate.length <= MAX_MACHINE_NAME_LENGTH) {
    return candidate;
  }

  return `${normalized.slice(0, MAX_MACHINE_NAME_LENGTH - 4)}の自販機`;
}

export function mergeProductWritePlans(
  confirmedProductIds: readonly string[],
  activePresetProductIds: readonly string[],
): readonly ProductWritePlan[] {
  const confirmed = new Set(confirmedProductIds);
  const allIds = new Set<string>([
    ...activePresetProductIds,
    ...confirmedProductIds,
  ]);

  return [...allIds]
    .sort()
    .map((productId): ProductWritePlan => {
      if (confirmed.has(productId)) {
        return {
          productId,
          evidenceType: "manual_confirmed",
          availability: "available",
          isConfirmed: true,
        };
      }

      return {
        productId,
        evidenceType: "manufacturer_inferred",
        availability: "unknown",
        isConfirmed: false,
      };
    });
}

export function mergePhotoProductWritePlans(
  confirmedProductIds: readonly string[],
  recognizedProductIds: ReadonlySet<string>,
): readonly ProductWritePlan[] {
  return [...new Set(confirmedProductIds)]
    .sort()
    .map((productId): ProductWritePlan => ({
      productId,
      evidenceType: recognizedProductIds.has(productId) ?
        "photo_confirmed" :
        "manual_confirmed",
      availability: "available",
      isConfirmed: true,
    }));
}

export type ManufacturerStatus =
  | "confirmed"
  | "recognized_and_confirmed"
  | "unknown";

export function resolvePhotoManufacturerStatus(
  manufacturerId: string | null,
  recognizedManufacturerIds: ReadonlySet<string>,
): ManufacturerStatus {
  if (manufacturerId === null) {
    return "unknown";
  }
  return recognizedManufacturerIds.has(manufacturerId) ?
    "recognized_and_confirmed" :
    "confirmed";
}

export function isMasterId(value: string): boolean {
  return (
    value.length >= 2 &&
    value.length <= 80 &&
    MASTER_ID_PATTERN.test(value)
  );
}

function parseRegistrationMethod(value: unknown): RegistrationMethod {
  if (
    value === "photo" ||
    value === "manufacturer" ||
    value === "locationOnly"
  ) {
    return value;
  }

  throw new CreateVendingMachineValidationError(
    "registrationMethod is invalid.",
  );
}

function parseInstallationType(value: unknown): InstallationType {
  if (value === "outdoor" || value === "indoor" || value === "unknown") {
    return value;
  }

  throw new CreateVendingMachineValidationError(
    "installationType is invalid.",
  );
}

function parseLocation(
  value: unknown,
): CreateVendingMachineInput["location"] {
  const location = requirePlainObject(value, "location");
  assertOnlyKeys(location, ["latitude", "longitude"]);

  const latitude = requireFiniteNumber(location.latitude, "location.latitude");
  const longitude = requireFiniteNumber(
    location.longitude,
    "location.longitude",
  );

  if (latitude < -90 || latitude > 90) {
    throw new CreateVendingMachineValidationError(
      "location.latitude is out of range.",
    );
  }
  if (longitude < -180 || longitude > 180) {
    throw new CreateVendingMachineValidationError(
      "location.longitude is out of range.",
    );
  }

  return {latitude, longitude};
}

function parseProductIds(value: unknown): readonly string[] {
  if (!Array.isArray(value)) {
    throw new CreateVendingMachineValidationError(
      "confirmedProductIds must be an array.",
    );
  }
  if (value.length > MAX_CONFIRMED_PRODUCT_IDS) {
    throw new CreateVendingMachineValidationError(
      `confirmedProductIds must contain at most ${MAX_CONFIRMED_PRODUCT_IDS} items.`,
    );
  }

  const ids = new Set<string>();
  for (const item of value) {
    if (typeof item !== "string") {
      throw new CreateVendingMachineValidationError(
        "confirmedProductIds must contain only strings.",
      );
    }
    const normalized = item.trim();
    if (!isMasterId(normalized)) {
      throw new CreateVendingMachineValidationError(
        "confirmedProductIds contains an invalid Product ID.",
      );
    }
    ids.add(normalized);
  }

  return [...ids];
}

function parseOptionalMasterId(
  value: unknown,
  fieldName: string,
): string | null {
  const normalized = parseOptionalString(value, fieldName, 80);
  if (normalized === null) {
    return null;
  }
  if (!isMasterId(normalized)) {
    throw new CreateVendingMachineValidationError(
      `${fieldName} is not a valid master ID.`,
    );
  }
  return normalized;
}

function parseOptionalString(
  value: unknown,
  fieldName: string,
  maxLength: number,
): string | null {
  if (value === undefined || value === null) {
    return null;
  }
  if (typeof value !== "string") {
    throw new CreateVendingMachineValidationError(
      `${fieldName} must be a string or null.`,
    );
  }

  const normalized = value.trim();
  if (normalized.length === 0) {
    return null;
  }
  if (normalized.length > maxLength) {
    throw new CreateVendingMachineValidationError(
      `${fieldName} exceeds its maximum length.`,
    );
  }

  return normalized;
}

function requireString(value: unknown, fieldName: string): string {
  if (typeof value !== "string") {
    throw new CreateVendingMachineValidationError(
      `${fieldName} must be a string.`,
    );
  }
  return value;
}

function requireFiniteNumber(value: unknown, fieldName: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new CreateVendingMachineValidationError(
      `${fieldName} must be a finite number.`,
    );
  }
  return value;
}

function requirePlainObject(
  value: unknown,
  fieldName: string,
): Record<string, unknown> {
  if (
    typeof value !== "object" ||
    value === null ||
    Array.isArray(value)
  ) {
    throw new CreateVendingMachineValidationError(
      `${fieldName} must be an object.`,
    );
  }
  return value as Record<string, unknown>;
}

function assertOnlyKeys(
  value: Record<string, unknown>,
  allowedKeys: readonly string[],
): void {
  const allowed = new Set(allowedKeys);
  for (const key of Object.keys(value)) {
    if (!allowed.has(key)) {
      throw new CreateVendingMachineValidationError(
        `Unexpected field: ${key}.`,
      );
    }
  }
}
