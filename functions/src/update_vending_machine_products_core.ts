import {createHash} from "node:crypto";

import {
  isMasterId,
  type ProductEvidenceType,
} from "./create_vending_machine_core";

export const UPDATE_VENDING_MACHINE_PRODUCTS_OPERATION =
  "updateVendingMachineProducts";

const UUID_V4_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export type ProductUpdateSource = "manual" | "photo";

export type ProductUpdateOperation =
  | {
    readonly type: "addConfirmed";
    readonly productId: string;
    readonly source: ProductUpdateSource;
  }
  | {
    readonly type: "deactivate";
    readonly productId: string;
  }
  | {
    readonly type: "setSoldOut";
    readonly productId: string;
    readonly soldOut: boolean;
  }
  | {
    readonly type: "confirmInferred";
    readonly productId: string;
  };

export interface UpdateVendingMachineProductsInput {
  readonly requestId: string;
  readonly machineId: string;
  readonly operations: readonly ProductUpdateOperation[];
  readonly temporaryPhotoUploadId: string | null;
}

export class UpdateVendingMachineProductsValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "UpdateVendingMachineProductsValidationError";
  }
}

export function parseUpdateVendingMachineProductsInput(
  raw: unknown,
): UpdateVendingMachineProductsInput {
  const data = requirePlainObject(raw, "request");

  assertOnlyKeys(data, [
    "requestId",
    "machineId",
    "operations",
    "temporaryPhotoUploadId",
  ]);

  const requestId = requireString(data.requestId, "requestId").trim();
  if (!UUID_V4_PATTERN.test(requestId)) {
    throw new UpdateVendingMachineProductsValidationError(
      "requestId must be an RFC 4122 UUID v4.",
    );
  }

  const machineId = requireString(data.machineId, "machineId").trim();
  if (machineId.length === 0 || machineId.includes("/")) {
    throw new UpdateVendingMachineProductsValidationError(
      "machineId must be a valid Firestore document ID.",
    );
  }

  if (!Array.isArray(data.operations) || data.operations.length === 0) {
    throw new UpdateVendingMachineProductsValidationError(
      "operations must contain at least one update.",
    );
  }

  const operations = data.operations.map(
    (value: unknown, index: number) =>
      parseProductUpdateOperation(value, index),
  );

  const temporaryPhotoUploadId = parseOptionalUuid(
    data.temporaryPhotoUploadId,
    "temporaryPhotoUploadId",
  );

  return {
    requestId,
    machineId,
    operations,
    temporaryPhotoUploadId,
  };
}

export function buildProductUpdateDeduplicationId(
  uid: string,
  requestId: string,
): string {
  const normalizedUid = uid.trim();

  if (normalizedUid.length === 0) {
    throw new UpdateVendingMachineProductsValidationError(
      "uid must not be empty.",
    );
  }

  if (!UUID_V4_PATTERN.test(requestId)) {
    throw new UpdateVendingMachineProductsValidationError(
      "requestId must be an RFC 4122 UUID v4.",
    );
  }

  return createHash("sha256")
    .update(
      `${normalizedUid}|${UPDATE_VENDING_MACHINE_PRODUCTS_OPERATION}|${requestId}`,
      "utf8",
    )
    .digest("hex");
}

export function collectReferencedProductIds(
  operations: readonly ProductUpdateOperation[],
): readonly string[] {
  return [...new Set(operations.map((operation) => operation.productId))]
    .sort();
}

export function confirmedEvidenceForSource(
  source: ProductUpdateSource,
): ProductEvidenceType {
  return source === "photo" ?
    "photo_confirmed" :
    "manual_confirmed";
}

export function isConfirmedEvidence(
  evidenceType: ProductEvidenceType,
): boolean {
  return evidenceType === "manual_confirmed" ||
    evidenceType === "photo_confirmed";
}

function parseProductUpdateOperation(
  raw: unknown,
  index: number,
): ProductUpdateOperation {
  const field = `operations[${index}]`;
  const data = requirePlainObject(raw, field);
  const type = requireString(data.type, `${field}.type`).trim();

  switch (type) {
  case "addConfirmed": {
    assertOnlyKeys(data, ["type", "productId", "source"]);

    const productId = parseProductId(
      data.productId,
      `${field}.productId`,
    );

    const source = requireString(
      data.source,
      `${field}.source`,
    ).trim();

    if (source !== "manual" && source !== "photo") {
      throw new UpdateVendingMachineProductsValidationError(
        `${field}.source must be manual or photo.`,
      );
    }

    return {
      type: "addConfirmed",
      productId,
      source,
    };
  }

  case "deactivate":
    assertOnlyKeys(data, ["type", "productId"]);
    return {
      type: "deactivate",
      productId: parseProductId(
        data.productId,
        `${field}.productId`,
      ),
    };

  case "setSoldOut":
    assertOnlyKeys(data, ["type", "productId", "soldOut"]);

    if (typeof data.soldOut !== "boolean") {
      throw new UpdateVendingMachineProductsValidationError(
        `${field}.soldOut must be a boolean.`,
      );
    }

    return {
      type: "setSoldOut",
      productId: parseProductId(
        data.productId,
        `${field}.productId`,
      ),
      soldOut: data.soldOut,
    };

  case "confirmInferred":
    assertOnlyKeys(data, ["type", "productId"]);
    return {
      type: "confirmInferred",
      productId: parseProductId(
        data.productId,
        `${field}.productId`,
      ),
    };

  default:
    throw new UpdateVendingMachineProductsValidationError(
      `${field}.type is not supported.`,
    );
  }
}

function parseProductId(
  raw: unknown,
  field: string,
): string {
  const productId = requireString(raw, field).trim();

  if (!isMasterId(productId)) {
    throw new UpdateVendingMachineProductsValidationError(
      `${field} must be a valid Product ID.`,
    );
  }

  return productId;
}

function parseOptionalUuid(
  raw: unknown,
  field: string,
): string | null {
  if (raw === null || raw === undefined) {
    return null;
  }

  if (typeof raw !== "string") {
    throw new UpdateVendingMachineProductsValidationError(
      `${field} must be a string or null.`,
    );
  }

  const value = raw.trim();

  if (!UUID_V4_PATTERN.test(value)) {
    throw new UpdateVendingMachineProductsValidationError(
      `${field} must be an RFC 4122 UUID v4.`,
    );
  }

  return value;
}

function requirePlainObject(
  raw: unknown,
  field: string,
): Record<string, unknown> {
  if (
    typeof raw !== "object" ||
    raw === null ||
    Array.isArray(raw)
  ) {
    throw new UpdateVendingMachineProductsValidationError(
      `${field} must be an object.`,
    );
  }

  return raw as Record<string, unknown>;
}

function requireString(
  raw: unknown,
  field: string,
): string {
  if (typeof raw !== "string") {
    throw new UpdateVendingMachineProductsValidationError(
      `${field} must be a string.`,
    );
  }

  return raw;
}

function assertOnlyKeys(
  data: Record<string, unknown>,
  allowedKeys: readonly string[],
): void {
  const allowed = new Set(allowedKeys);

  for (const key of Object.keys(data)) {
    if (!allowed.has(key)) {
      throw new UpdateVendingMachineProductsValidationError(
        `Unexpected field: ${key}.`,
      );
    }
  }
}

export type ProductAvailability =
  | "available"
  | "soldOut"
  | "unknown";

export interface ExistingProductState {
  readonly productId: string;
  readonly evidenceType: ProductEvidenceType;
  readonly availability: ProductAvailability;
  readonly isActive: boolean;
}

export interface ProductUpdatePlan {
  readonly productId: string;
  readonly before: ExistingProductState | null;
  readonly after: ExistingProductState;
  readonly createsDocument: boolean;
  readonly changed: boolean;
}

export function collectPhotoSourcedProductIds(
  operations: readonly ProductUpdateOperation[],
): readonly string[] {
  return [
    ...new Set(
      operations
        .filter(
          (
            operation,
          ): operation is Extract<
            ProductUpdateOperation,
            {readonly type: "addConfirmed"}
          > =>
            operation.type === "addConfirmed" &&
            operation.source === "photo",
        )
        .map((operation) => operation.productId),
    ),
  ].sort();
}

export function resolveProductUpdatePlan(
  current: ExistingProductState | null,
  operations: readonly ProductUpdateOperation[],
): ProductUpdatePlan {
  if (operations.length === 0) {
    throw new UpdateVendingMachineProductsValidationError(
      "At least one operation is required for a Product ID.",
    );
  }

  const productId = operations[0].productId;

  if (operations.some((operation) => operation.productId !== productId)) {
    throw new UpdateVendingMachineProductsValidationError(
      "A product update plan must contain only one Product ID.",
    );
  }

  if (current !== null && current.productId !== productId) {
    throw new UpdateVendingMachineProductsValidationError(
      "Current product state does not match the operation Product ID.",
    );
  }

  const addOperations = operations.filter(
    (
      operation,
    ): operation is Extract<
      ProductUpdateOperation,
      {readonly type: "addConfirmed"}
    > => operation.type === "addConfirmed",
  );

  const deactivateOperations = operations.filter(
    (
      operation,
    ): operation is Extract<
      ProductUpdateOperation,
      {readonly type: "deactivate"}
    > => operation.type === "deactivate",
  );

  const soldOutOperations = operations.filter(
    (
      operation,
    ): operation is Extract<
      ProductUpdateOperation,
      {readonly type: "setSoldOut"}
    > => operation.type === "setSoldOut",
  );

  const confirmOperations = operations.filter(
    (
      operation,
    ): operation is Extract<
      ProductUpdateOperation,
      {readonly type: "confirmInferred"}
    > => operation.type === "confirmInferred",
  );

  if (
    addOperations.length > 1 ||
    deactivateOperations.length > 1 ||
    soldOutOperations.length > 1 ||
    confirmOperations.length > 1
  ) {
    throw new UpdateVendingMachineProductsValidationError(
      "Duplicate operation types for the same Product ID are not allowed.",
    );
  }

  if (
    deactivateOperations.length === 1 &&
    operations.length > 1
  ) {
    throw new UpdateVendingMachineProductsValidationError(
      "deactivate cannot be combined with another operation.",
    );
  }

  if (
    addOperations.length === 1 &&
    confirmOperations.length === 1
  ) {
    throw new UpdateVendingMachineProductsValidationError(
      "addConfirmed and confirmInferred cannot be combined.",
    );
  }

  if (deactivateOperations.length === 1) {
    if (current === null) {
      throw new UpdateVendingMachineProductsValidationError(
        "Cannot deactivate a product that does not exist.",
      );
    }

    const after: ExistingProductState = {
      ...current,
      isActive: false,
    };

    return {
      productId,
      before: current,
      after,
      createsDocument: false,
      changed: !sameProductState(current, after),
    };
  }

  let after: ExistingProductState | null =
    current === null ? null : {...current};

  const addOperation = addOperations[0];
  if (addOperation !== undefined) {
    const requestedEvidence =
      confirmedEvidenceForSource(addOperation.source);

    if (after === null) {
      after = {
        productId,
        evidenceType: requestedEvidence,
        availability: "available",
        isActive: true,
      };
    } else if (!after.isActive) {
      after = {
        productId,
        evidenceType: requestedEvidence,
        availability: "available",
        isActive: true,
      };
    } else if (!isConfirmedEvidence(after.evidenceType)) {
      after = {
        ...after,
        evidenceType: requestedEvidence,
        availability: "available",
        isActive: true,
      };
    }
  }

  if (confirmOperations.length === 1) {
    if (after === null || !after.isActive) {
      throw new UpdateVendingMachineProductsValidationError(
        "Cannot confirm a missing or inactive inferred product.",
      );
    }

    if (after.evidenceType === "manufacturer_inferred") {
      after = {
        ...after,
        evidenceType: "manual_confirmed",
        availability: "available",
      };
    }
  }

  const soldOutOperation = soldOutOperations[0];
  if (soldOutOperation !== undefined) {
    if (after === null || !after.isActive) {
      throw new UpdateVendingMachineProductsValidationError(
        "Cannot change sold-out state for a missing or inactive product.",
      );
    }

    if (!isConfirmedEvidence(after.evidenceType)) {
      throw new UpdateVendingMachineProductsValidationError(
        "An inferred product must be confirmed before changing sold-out state.",
      );
    }

    after = {
      ...after,
      availability:
        soldOutOperation.soldOut ? "soldOut" : "available",
    };
  }

  if (after === null) {
    throw new UpdateVendingMachineProductsValidationError(
      "The requested operations cannot create or update this product.",
    );
  }

  return {
    productId,
    before: current,
    after,
    createsDocument: current === null,
    changed:
      current === null ||
      !sameProductState(current, after),
  };
}

export function groupProductUpdateOperations(
  operations: readonly ProductUpdateOperation[],
): ReadonlyMap<string, readonly ProductUpdateOperation[]> {
  const grouped = new Map<string, ProductUpdateOperation[]>();

  for (const operation of operations) {
    const existing = grouped.get(operation.productId) ?? [];
    existing.push(operation);
    grouped.set(operation.productId, existing);
  }

  return new Map(
    [...grouped.entries()]
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([productId, values]) => [
        productId,
        [...values],
      ]),
  );
}

function sameProductState(
  left: ExistingProductState,
  right: ExistingProductState,
): boolean {
  return left.productId === right.productId &&
    left.evidenceType === right.evidenceType &&
    left.availability === right.availability &&
    left.isActive === right.isActive;
}
