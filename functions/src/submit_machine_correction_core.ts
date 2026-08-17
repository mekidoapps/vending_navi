import {createHash} from "node:crypto";

import {
  isMasterId,
} from "./create_vending_machine_core";

export const SUBMIT_MACHINE_CORRECTION_OPERATION =
  "submitMachineCorrection";

const UUID_V4_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const INSTALLATION_TYPES =
  new Set(["outdoor", "indoor", "unknown"]);

const MAX_NAME_LENGTH = 100;
const MAX_PLACE_DESCRIPTION_LENGTH = 300;
const MAX_MESSAGE_LENGTH = 500;

export interface CorrectionLocation {
  readonly latitude: number;
  readonly longitude: number;
}

export interface MachineCorrectionChanges {
  readonly name?: string;
  readonly manufacturerId?: string | null;
  readonly location?: CorrectionLocation;
  readonly placeDescription?: string | null;
  readonly installationType?: "outdoor" | "indoor" | "unknown";
}

export interface SubmitMachineCorrectionInput {
  readonly requestId: string;
  readonly machineId: string;
  readonly changes: MachineCorrectionChanges;
  readonly message: string | null;
}

export interface CurrentMachineCorrectionState {
  readonly name: string;
  readonly manufacturerId: string | null;
  readonly location: CorrectionLocation;
  readonly placeDescription: string | null;
  readonly installationType: string;
}

export class SubmitMachineCorrectionValidationError
  extends Error {
  constructor(message: string) {
    super(message);
    this.name =
      "SubmitMachineCorrectionValidationError";
  }
}

export function parseSubmitMachineCorrectionInput(
  rawInput: unknown,
): SubmitMachineCorrectionInput {
  const input = requirePlainObject(
    rawInput,
    "The correction request must be an object.",
  );

  assertOnlyKeys(
    input,
    new Set([
      "requestId",
      "machineId",
      "changes",
      "message",
    ]),
    "Unknown correction request field.",
  );

  const requestId = requireString(
    input.requestId,
    "requestId is required.",
  );

  if (!UUID_V4_PATTERN.test(requestId)) {
    throw new SubmitMachineCorrectionValidationError(
      "requestId must be UUID v4.",
    );
  }

  const machineId = requireString(
    input.machineId,
    "machineId is required.",
  );

  if (!isMasterId(machineId)) {
    throw new SubmitMachineCorrectionValidationError(
      "machineId is invalid.",
    );
  }

  const rawChanges = requirePlainObject(
    input.changes,
    "changes must be an object.",
  );

  assertOnlyKeys(
    rawChanges,
    new Set([
      "name",
      "manufacturerId",
      "location",
      "placeDescription",
      "installationType",
    ]),
    "Unknown correction change field.",
  );

  const changes: {
    name?: string;
    manufacturerId?: string | null;
    location?: CorrectionLocation;
    placeDescription?: string | null;
    installationType?: "outdoor" | "indoor" | "unknown";
  } = {};

  if (Object.hasOwn(rawChanges, "name")) {
    if (
      typeof rawChanges.name !== "string" ||
      rawChanges.name.trim().length === 0 ||
      rawChanges.name.trim().length > MAX_NAME_LENGTH
    ) {
      throw new SubmitMachineCorrectionValidationError(
        "name is invalid.",
      );
    }

    changes.name = rawChanges.name.trim();
  }

  if (Object.hasOwn(rawChanges, "manufacturerId")) {
    if (rawChanges.manufacturerId === null) {
      changes.manufacturerId = null;
    } else {
      const manufacturerId = requireString(
        rawChanges.manufacturerId,
        "manufacturerId is invalid.",
      );

      if (!isMasterId(manufacturerId)) {
        throw new SubmitMachineCorrectionValidationError(
          "manufacturerId is invalid.",
        );
      }

      changes.manufacturerId = manufacturerId;
    }
  }

  if (Object.hasOwn(rawChanges, "location")) {
    const location = requirePlainObject(
      rawChanges.location,
      "location is invalid.",
    );

    assertOnlyKeys(
      location,
      new Set(["latitude", "longitude"]),
      "Unknown location field.",
    );

    const latitude = location.latitude;
    const longitude = location.longitude;

    if (
      typeof latitude !== "number" ||
      !Number.isFinite(latitude) ||
      latitude < -90 ||
      latitude > 90 ||
      typeof longitude !== "number" ||
      !Number.isFinite(longitude) ||
      longitude < -180 ||
      longitude > 180
    ) {
      throw new SubmitMachineCorrectionValidationError(
        "location is invalid.",
      );
    }

    changes.location = {
      latitude,
      longitude,
    };
  }

  if (Object.hasOwn(rawChanges, "placeDescription")) {
    if (rawChanges.placeDescription === null) {
      changes.placeDescription = null;
    } else if (
      typeof rawChanges.placeDescription === "string"
    ) {
      const normalized =
        rawChanges.placeDescription.trim();

      if (
        normalized.length >
        MAX_PLACE_DESCRIPTION_LENGTH
      ) {
        throw new SubmitMachineCorrectionValidationError(
          "placeDescription is too long.",
        );
      }

      changes.placeDescription =
        normalized.length === 0 ? null : normalized;
    } else {
      throw new SubmitMachineCorrectionValidationError(
        "placeDescription is invalid.",
      );
    }
  }

  if (Object.hasOwn(rawChanges, "installationType")) {
    const installationType = requireString(
      rawChanges.installationType,
      "installationType is invalid.",
    );

    if (!INSTALLATION_TYPES.has(installationType)) {
      throw new SubmitMachineCorrectionValidationError(
        "installationType is invalid.",
      );
    }

    changes.installationType =
      installationType as
        | "outdoor"
        | "indoor"
        | "unknown";
  }

  if (Object.keys(changes).length === 0) {
    throw new SubmitMachineCorrectionValidationError(
      "At least one correction change is required.",
    );
  }

  let message: string | null = null;

  if (
    input.message !== undefined &&
    input.message !== null
  ) {
    if (typeof input.message !== "string") {
      throw new SubmitMachineCorrectionValidationError(
        "message is invalid.",
      );
    }

    const normalized = input.message.trim();

    if (normalized.length > MAX_MESSAGE_LENGTH) {
      throw new SubmitMachineCorrectionValidationError(
        "message is too long.",
      );
    }

    message =
      normalized.length === 0 ? null : normalized;
  }

  return {
    requestId,
    machineId,
    changes,
    message,
  };
}

export function removeUnchangedCorrectionFields(
  changes: MachineCorrectionChanges,
  current: CurrentMachineCorrectionState,
): MachineCorrectionChanges {
  const result: {
    name?: string;
    manufacturerId?: string | null;
    location?: CorrectionLocation;
    placeDescription?: string | null;
    installationType?: "outdoor" | "indoor" | "unknown";
  } = {};

  if (
    changes.name !== undefined &&
    changes.name !== current.name
  ) {
    result.name = changes.name;
  }

  if (
    Object.hasOwn(changes, "manufacturerId") &&
    changes.manufacturerId !== current.manufacturerId
  ) {
    result.manufacturerId =
      changes.manufacturerId ?? null;
  }

  if (
    changes.location !== undefined &&
    (
      changes.location.latitude !==
        current.location.latitude ||
      changes.location.longitude !==
        current.location.longitude
    )
  ) {
    result.location = changes.location;
  }

  if (
    Object.hasOwn(changes, "placeDescription") &&
    changes.placeDescription !==
      current.placeDescription
  ) {
    result.placeDescription =
      changes.placeDescription ?? null;
  }

  if (
    changes.installationType !== undefined &&
    changes.installationType !==
      current.installationType
  ) {
    result.installationType =
      changes.installationType;
  }

  return result;
}

export function buildMachineCorrectionDeduplicationId(
  uid: string,
  requestId: string,
): string {
  return sha256(
    `${SUBMIT_MACHINE_CORRECTION_OPERATION}:${uid}:${requestId}`,
  );
}

export function buildMachineCorrectionId(
  uid: string,
  requestId: string,
): string {
  return `c_${sha256(
    `machineCorrection:${uid}:${requestId}`,
  ).slice(0, 30)}`;
}

function requirePlainObject(
  value: unknown,
  message: string,
): Record<string, unknown> {
  if (
    typeof value !== "object" ||
    value === null ||
    Array.isArray(value)
  ) {
    throw new SubmitMachineCorrectionValidationError(
      message,
    );
  }

  return value as Record<string, unknown>;
}

function requireString(
  value: unknown,
  message: string,
): string {
  if (
    typeof value !== "string" ||
    value.trim().length === 0
  ) {
    throw new SubmitMachineCorrectionValidationError(
      message,
    );
  }

  return value.trim();
}

function assertOnlyKeys(
  value: Record<string, unknown>,
  allowed: ReadonlySet<string>,
  message: string,
): void {
  for (const key of Object.keys(value)) {
    if (!allowed.has(key)) {
      throw new SubmitMachineCorrectionValidationError(
        message,
      );
    }
  }
}

function sha256(value: string): string {
  return createHash("sha256")
    .update(value)
    .digest("hex");
}
