import {createHash} from "node:crypto";

import {isMasterId} from "./create_vending_machine_core";

export const SUBMIT_MACHINE_REPORT_OPERATION =
  "submitMachineReport";

const UUID_V4_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const PHOTO_ID_PATTERN = /^p_[0-9a-f]{30}$/;

const REPORT_CATEGORIES = new Set([
  "machineRemoved",
  "duplicate",
  "inaccessible",
  "inappropriatePhoto",
  "inappropriateText",
  "other",
]);

const MAX_MESSAGE_LENGTH = 500;

export type MachineReportCategory =
  | "machineRemoved"
  | "duplicate"
  | "inaccessible"
  | "inappropriatePhoto"
  | "inappropriateText"
  | "other";

export interface SubmitMachineReportInput {
  readonly requestId: string;
  readonly machineId: string;
  readonly photoId: string | null;
  readonly category: MachineReportCategory;
  readonly message: string | null;
}

export interface SubmitMachineReportResult {
  readonly machineId: string;
  readonly reportId: string;
  readonly submitted: true;
}

export class SubmitMachineReportValidationError
  extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SubmitMachineReportValidationError";
  }
}

export function parseSubmitMachineReportInput(
  rawInput: unknown,
): SubmitMachineReportInput {
  const input = requirePlainObject(
    rawInput,
    "The machine report must be an object.",
  );

  assertOnlyKeys(
    input,
    new Set([
      "requestId",
      "machineId",
      "photoId",
      "category",
      "message",
    ]),
    "Unknown machine report field.",
  );

  const requestId = requireString(
    input.requestId,
    "requestId is required.",
  );

  if (!UUID_V4_PATTERN.test(requestId)) {
    throw new SubmitMachineReportValidationError(
      "requestId must be UUID v4.",
    );
  }

  const machineId = requireString(
    input.machineId,
    "machineId is required.",
  );

  if (!isMasterId(machineId)) {
    throw new SubmitMachineReportValidationError(
      "machineId is invalid.",
    );
  }

  let photoId: string | null = null;

  if (
    input.photoId !== undefined &&
    input.photoId !== null
  ) {
    photoId = requireString(
      input.photoId,
      "photoId is invalid.",
    );

    if (!PHOTO_ID_PATTERN.test(photoId)) {
      throw new SubmitMachineReportValidationError(
        "photoId is invalid.",
      );
    }
  }

  const category = requireString(
    input.category,
    "category is required.",
  );

  if (!REPORT_CATEGORIES.has(category)) {
    throw new SubmitMachineReportValidationError(
      "category is invalid.",
    );
  }

  let message: string | null = null;

  if (
    input.message !== undefined &&
    input.message !== null
  ) {
    if (typeof input.message !== "string") {
      throw new SubmitMachineReportValidationError(
        "message is invalid.",
      );
    }

    const normalized = input.message.trim();

    if (normalized.length > MAX_MESSAGE_LENGTH) {
      throw new SubmitMachineReportValidationError(
        "message is too long.",
      );
    }

    message =
      normalized.length === 0 ? null : normalized;
  }

  return {
    requestId,
    machineId,
    photoId,
    category: category as MachineReportCategory,
    message,
  };
}

export function buildMachineReportDeduplicationId(
  uid: string,
  requestId: string,
): string {
  return sha256(
    `${SUBMIT_MACHINE_REPORT_OPERATION}:${uid}:${requestId}`,
  );
}

export function buildMachineReportId(
  uid: string,
  requestId: string,
): string {
  return `r_${sha256(
    `machineReport:${uid}:${requestId}`,
  ).slice(0, 30)}`;
}

export function parseStoredMachineReportResult(
  value: unknown,
): SubmitMachineReportResult {
  const data = requirePlainObject(
    value,
    "Stored machine report result is invalid.",
  );

  assertOnlyKeys(
    data,
    new Set(["machineId", "reportId", "submitted"]),
    "Stored machine report result is invalid.",
  );

  const machineId = requireString(
    data.machineId,
    "Stored machineId is invalid.",
  );

  const reportId = requireString(
    data.reportId,
    "Stored reportId is invalid.",
  );

  if (
    !isMasterId(machineId) ||
    !/^r_[0-9a-f]{30}$/.test(reportId) ||
    data.submitted !== true
  ) {
    throw new SubmitMachineReportValidationError(
      "Stored machine report result is invalid.",
    );
  }

  return {
    machineId,
    reportId,
    submitted: true,
  };
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
    throw new SubmitMachineReportValidationError(
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
    throw new SubmitMachineReportValidationError(
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
      throw new SubmitMachineReportValidationError(
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
