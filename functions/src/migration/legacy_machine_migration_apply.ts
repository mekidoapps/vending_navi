import {createHash} from "node:crypto";

import {
  LEGACY_MACHINE_MIGRATION_REVISION,
  type LegacyMachineExportRecord,
  type LegacyMachineMigrationPlan,
  type LegacyMigrationReport,
  type MigrationAliases,
  type MigrationMasterCatalog,
  type MigrationStatusDecisions,
  planLegacyMachineMigration,
} from "./legacy_machine_migration_planner";

export const PHASE_B_EXPECTED_TOTAL = 42;
export const PHASE_B_EXPECTED_READY = 42;
export const PHASE_B_EXPECTED_STATUS_WRITES = 41;
export const PHASE_B_EXPECTED_UNRESOLVED_PRODUCTS = 8;
export const PHASE_B_EXPECTED_PLANNED_INDEXES = 25;
export const PHASE_B_EXPECTED_NON_PLAN_INDEXES = 7;

export type MigrationApplyState = "pre_apply" | "already_applied";
export type MigratedProductAvailability = "available" | "soldOut";

export interface ApprovedMigrationProductPair {
  readonly machineId: string;
  readonly productId: string;
  readonly availability: MigratedProductAvailability;
  readonly latitude: number;
  readonly longitude: number;
  readonly geohash: string;
}

export interface MigrationApplyStateEvaluation {
  readonly state: MigrationApplyState;
  readonly rootStatusWrites: number;
  readonly existingProductDocuments: number;
  readonly existingIndexDocuments: number;
  readonly nonPlanIndexDocuments: number;
  readonly plannedProductDocuments: number;
  readonly plannedIndexDocuments: number;
  readonly totalWrites: number;
}

/**
 * Validate the exact owner-approved Phase B report before it can drive writes.
 */
export function validateApprovedMigrationReport(
  report: LegacyMigrationReport,
): void {
  if (report.revision !== LEGACY_MACHINE_MIGRATION_REVISION) {
    throw new Error("Approved report uses an unexpected migration revision.");
  }
  const summary = report.summary;
  if (
    summary.total !== PHASE_B_EXPECTED_TOTAL ||
    summary.ready !== PHASE_B_EXPECTED_READY ||
    summary.manualReview !== 0 ||
    summary.invalidCoordinates !== 0 ||
    summary.unresolvedProductCount !==
      PHASE_B_EXPECTED_UNRESOLVED_PRODUCTS ||
    summary.plannedIndexCount !== PHASE_B_EXPECTED_PLANNED_INDEXES ||
    report.machines.length !== PHASE_B_EXPECTED_TOTAL
  ) {
    throw new Error("Approved report does not match the Phase B apply gate.");
  }

  const machineIds = new Set<string>();
  let expectedStatusWrites = 0;
  for (const machine of report.machines) {
    if (
      machine.machineId.trim().length === 0 ||
      machineIds.has(machine.machineId)
    ) {
      throw new Error("Approved report contains an invalid machine ID set.");
    }
    machineIds.add(machine.machineId);
    if (
      machine.targetStatus === null ||
      machine.targetSchemaVersion !== 2 ||
      machine.latitude === null ||
      machine.longitude === null ||
      machine.geohash === null
    ) {
      throw new Error("Approved report contains a non-ready machine.");
    }
    if (machine.legacyStatus !== machine.targetStatus) {
      expectedStatusWrites += 1;
    }
  }
  if (expectedStatusWrites !== PHASE_B_EXPECTED_STATUS_WRITES) {
    throw new Error("Approved report has an unexpected status-write count.");
  }

  const pairs = buildApprovedProductPairs(report);
  if (pairs.length !== PHASE_B_EXPECTED_PLANNED_INDEXES) {
    throw new Error("Approved report has an unexpected product-pair count.");
  }
}

/**
 * Re-plan the live root documents after normalizing only the already-applied
 * status field back to its approved pre-migration value. This makes a second
 * run verifiable without accepting drift in coordinates, products, master
 * resolution, or any other planner input.
 */
export function validateLiveRecordsAgainstApprovedReport(
  records: readonly LegacyMachineExportRecord[],
  approvedReport: LegacyMigrationReport,
  catalog: MigrationMasterCatalog,
  aliases: MigrationAliases,
  expectedReportSha256: string,
): void {
  validateApprovedMigrationReport(approvedReport);
  const approvedById = new Map(
    approvedReport.machines.map((machine) => [machine.machineId, machine]),
  );
  if (records.length !== approvedById.size) {
    throw new Error("Live vending-machine count differs from the approved report.");
  }

  const normalizedRecords = records.map((record) => {
    const approved = approvedById.get(record.id);
    if (approved === undefined) {
      throw new Error("Live vending-machine IDs differ from the approved report.");
    }
    const currentStatus = readOptionalString(record.data.status);
    if (
      currentStatus !== approved.legacyStatus &&
      currentStatus !== approved.targetStatus
    ) {
      throw new Error("A live vending-machine status changed outside the approved plan.");
    }

    const data: Record<string, unknown> = {...record.data};
    if (approved.legacyStatus === null) {
      delete data.status;
    } else {
      data.status = approved.legacyStatus;
    }
    return {id: record.id, data};
  });

  const replanned = planLegacyMachineMigration(
    normalizedRecords,
    catalog,
    aliases,
    buildStatusDecisions(approvedReport),
  );
  const actualHash = hashMigrationReport(replanned);
  if (actualHash !== normalizeSha256(expectedReportSha256)) {
    throw new Error(
      "Live production data no longer matches the approved migration report.",
    );
  }
}

export function buildApprovedProductPairs(
  report: LegacyMigrationReport,
): readonly ApprovedMigrationProductPair[] {
  const pairs: ApprovedMigrationProductPair[] = [];
  for (const machine of report.machines) {
    if (
      machine.targetStatus !== "active" ||
      machine.latitude === null ||
      machine.longitude === null ||
      machine.geohash === null
    ) {
      continue;
    }
    for (const productId of machine.resolvedProductIds) {
      const sourceProducts = machine.legacyProducts.filter(
        (product) => product.productId === productId,
      );
      if (sourceProducts.length === 0) {
        throw new Error("Approved product ID has no legacy evidence.");
      }
      pairs.push({
        machineId: machine.machineId,
        productId,
        availability: sourceProducts.some((product) => !product.isSoldOut) ?
          "available" : "soldOut",
        latitude: machine.latitude,
        longitude: machine.longitude,
        geohash: machine.geohash,
      });
    }
  }
  return pairs.sort((left, right) =>
    pairKey(left).localeCompare(pairKey(right))
  );
}

export function evaluateMigrationApplyState(
  report: LegacyMigrationReport,
  currentStatusByMachineId: ReadonlyMap<string, string | null>,
  existingProductPairKeys: ReadonlySet<string>,
  existingIndexPairKeys: ReadonlySet<string>,
  nonPlanIndexDocuments: number,
): MigrationApplyStateEvaluation {
  validateApprovedMigrationReport(report);
  const pairs = buildApprovedProductPairs(report);
  const approvedPairKeys = new Set(pairs.map(pairKey));
  const expectedMachineIds = new Set(
    report.machines.map((machine) => machine.machineId),
  );
  if (
    currentStatusByMachineId.size !== expectedMachineIds.size ||
    [...currentStatusByMachineId.keys()].some((id) => !expectedMachineIds.has(id))
  ) {
    throw new Error("Current machine status set differs from the approved report.");
  }
  if (
    [...existingProductPairKeys].some((key) => !approvedPairKeys.has(key)) ||
    [...existingIndexPairKeys].some((key) => !approvedPairKeys.has(key))
  ) {
    throw new Error("Unexpected planned-path documents were supplied.");
  }
  if (nonPlanIndexDocuments !== PHASE_B_EXPECTED_NON_PLAN_INDEXES) {
    throw new Error("Non-migration index count differs from the approved baseline.");
  }

  let rootStatusWrites = 0;
  let preApplyStatuses = true;
  let postApplyStatuses = true;
  for (const machine of report.machines) {
    const current = currentStatusByMachineId.get(machine.machineId) ?? null;
    if (current !== machine.legacyStatus) {
      preApplyStatuses = false;
    }
    if (current !== machine.targetStatus) {
      postApplyStatuses = false;
      rootStatusWrites += 1;
    }
  }

  const existingProducts = existingProductPairKeys.size;
  const existingIndexes = existingIndexPairKeys.size;
  const isPreApply =
    preApplyStatuses && existingProducts === 0 && existingIndexes === 0;
  const isPostApply =
    postApplyStatuses &&
    existingProducts === pairs.length &&
    existingIndexes === pairs.length;
  if (!isPreApply && !isPostApply) {
    throw new Error(
      "Production is neither the approved pre-apply nor post-apply state.",
    );
  }

  const state: MigrationApplyState = isPreApply ?
    "pre_apply" : "already_applied";
  const productCreates = pairs.length - existingProducts;
  const indexCreates = pairs.length - existingIndexes;
  return {
    state,
    rootStatusWrites,
    existingProductDocuments: existingProducts,
    existingIndexDocuments: existingIndexes,
    nonPlanIndexDocuments,
    plannedProductDocuments: pairs.length,
    plannedIndexDocuments: pairs.length,
    totalWrites: rootStatusWrites + productCreates + indexCreates,
  };
}

export function pairKey(pair: {
  readonly machineId: string;
  readonly productId: string;
}): string {
  return `${pair.machineId}\u0000${pair.productId}`;
}

export function indexDocumentId(pair: {
  readonly machineId: string;
  readonly productId: string;
}): string {
  return `${pair.machineId}_${pair.productId}`;
}

export function hashMigrationReport(report: LegacyMigrationReport): string {
  return createHash("sha256")
    .update(`${JSON.stringify(report, null, 2)}\n`, "utf8")
    .digest("hex");
}

export function parseApprovedMigrationReport(value: unknown): LegacyMigrationReport {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Approved migration report is not a JSON object.");
  }
  return value as LegacyMigrationReport;
}

function buildStatusDecisions(
  report: LegacyMigrationReport,
): MigrationStatusDecisions {
  const machineStatuses: Record<string, NonNullable<
    LegacyMachineMigrationPlan["targetStatus"]
  >> = {};
  for (const machine of report.machines) {
    if (
      machine.statusDecision === "owner_approved" &&
      machine.targetStatus !== null
    ) {
      machineStatuses[machine.machineId] = machine.targetStatus;
    }
  }
  return {machineStatuses};
}

function normalizeSha256(value: string): string {
  const normalized = value.trim().toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(normalized)) {
    throw new Error("Expected report SHA-256 is invalid.");
  }
  return normalized;
}

function readOptionalString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const normalized = value.trim();
  return normalized.length === 0 ? null : normalized;
}
