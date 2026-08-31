import {encodeGeohash} from "../create_vending_machine_core";
import {normalizeMasterLabel} from "../photo_recognition/master_label_resolver";

export const LEGACY_MACHINE_MIGRATION_REVISION =
  "phase-b-legacy-machine-plan-v1";

export type CanonicalMachineStatus =
  | "active"
  | "underReview"
  | "hidden"
  | "merged"
  | "removed";

export interface LegacyMachineExportRecord {
  readonly id: string;
  readonly data: Readonly<Record<string, unknown>>;
}

export interface MigrationMasterManufacturer {
  readonly id: string;
  readonly name: string;
  readonly displayShortName?: string;
  readonly searchKeywords?: readonly string[];
  readonly isActive: boolean;
}

export interface MigrationMasterProduct {
  readonly id: string;
  readonly name: string;
  readonly manufacturerId: string;
  readonly searchKeywords?: readonly string[];
  readonly isActive: boolean;
}

export interface MigrationMasterCatalog {
  readonly manufacturers: readonly MigrationMasterManufacturer[];
  readonly products: readonly MigrationMasterProduct[];
}

export interface MigrationAliases {
  readonly manufacturers?: Readonly<Record<string, string>>;
  readonly products?: Readonly<Record<string, string>>;
}

export type ResolutionKind =
  | "product_id"
  | "unique_label"
  | "manufacturer_and_label"
  | "manual_alias";

export interface LegacyProductPlan {
  readonly rawName: string;
  readonly sourceField: "products" | "drinkSlots" | "slots" | "drinks";
  readonly explicitProductId: string | null;
  readonly isSoldOut: boolean;
  readonly productId: string | null;
  readonly resolutionKind: ResolutionKind | "unresolved";
}

export interface LegacyMachineMigrationPlan {
  readonly machineId: string;
  readonly legacyStatus: string | null;
  readonly targetStatus: CanonicalMachineStatus | null;
  readonly statusDecision: "canonical" | "manual_review";
  readonly latitude: number | null;
  readonly longitude: number | null;
  readonly geohash: string | null;
  readonly canGenerateGeohash: boolean;
  readonly manufacturerId: string | null;
  readonly manufacturerResolution:
    | "manufacturer_id"
    | "unique_label"
    | "manual_alias"
    | "unresolved";
  readonly legacyProducts: readonly LegacyProductPlan[];
  readonly resolvedProductIds: readonly string[];
  readonly unresolvedProducts: readonly string[];
  readonly sourceSchemaVersion: number | null;
  readonly targetSchemaVersion: 2 | null;
  readonly plannedIndexCount: number;
  readonly warnings: readonly string[];
}

export interface LegacyMigrationSummary {
  readonly revision: string;
  readonly total: number;
  readonly ready: number;
  readonly manualReview: number;
  readonly invalidCoordinates: number;
  readonly unresolvedProductCount: number;
  readonly plannedIndexCount: number;
}

export interface LegacyMigrationReport {
  readonly revision: string;
  readonly summary: LegacyMigrationSummary;
  readonly machines: readonly LegacyMachineMigrationPlan[];
}

interface LegacyProductCandidate {
  readonly rawName: string;
  readonly sourceField: LegacyProductPlan["sourceField"];
  readonly explicitProductId: string | null;
  readonly isSoldOut: boolean;
}

interface Resolution {
  readonly id: string | null;
  readonly kind: LegacyProductPlan["resolutionKind"];
}

/**
 * Produce a deterministic, read-only migration report.
 *
 * This function deliberately does not infer public visibility. Only already
 * canonical status values are carried forward; legacy `available`, missing,
 * and all unknown values require an explicit review decision.
 */
export function planLegacyMachineMigration(
  records: readonly LegacyMachineExportRecord[],
  catalog: MigrationMasterCatalog,
  aliases: MigrationAliases = {},
): LegacyMigrationReport {
  validateCatalog(catalog);

  const ids = new Set<string>();
  const machines = [...records]
    .map((record) => {
      const machineId = record.id.trim();
      if (machineId.length === 0) {
        throw new Error("Migration export contains an empty machine ID.");
      }
      if (ids.has(machineId)) {
        throw new Error(`Duplicate machine ID in export: ${machineId}`);
      }
      ids.add(machineId);
      return planOneMachine(machineId, record.data, catalog, aliases);
    })
    .sort((left, right) => left.machineId.localeCompare(right.machineId));

  const summary: LegacyMigrationSummary = {
    revision: LEGACY_MACHINE_MIGRATION_REVISION,
    total: machines.length,
    ready: machines.filter((machine) =>
      machine.targetSchemaVersion === 2
    ).length,
    manualReview: machines.filter((machine) =>
      machine.statusDecision === "manual_review"
    ).length,
    invalidCoordinates: machines.filter((machine) =>
      !machine.canGenerateGeohash
    ).length,
    unresolvedProductCount: machines.reduce(
      (sum, machine) => sum + machine.unresolvedProducts.length,
      0,
    ),
    plannedIndexCount: machines.reduce(
      (sum, machine) => sum + machine.plannedIndexCount,
      0,
    ),
  };

  return {
    revision: LEGACY_MACHINE_MIGRATION_REVISION,
    summary,
    machines,
  };
}

function planOneMachine(
  machineId: string,
  data: Readonly<Record<string, unknown>>,
  catalog: MigrationMasterCatalog,
  aliases: MigrationAliases,
): LegacyMachineMigrationPlan {
  const legacyStatus = readString(data.status);
  const status = resolveStatus(legacyStatus);
  const coordinates = readCoordinates(data);
  const geohash = coordinates === null ? null : encodeGeohash(
    coordinates.latitude,
    coordinates.longitude,
  );
  const manufacturer = resolveManufacturer(
    readString(data.manufacturerId) ?? readString(data.manufacturer),
    catalog,
    aliases,
  );
  const legacyProducts = readLegacyProducts(data).map((candidate) => {
    const resolution = resolveProduct(
      candidate,
      manufacturer.id,
      catalog,
      aliases,
    );
    return {
      ...candidate,
      productId: resolution.id,
      resolutionKind: resolution.kind,
    };
  });
  const resolvedProductIds = [...new Set(
    legacyProducts
      .map((product) => product.productId)
      .filter((id): id is string => id !== null),
  )].sort();
  const unresolvedProducts = [...new Set(
    legacyProducts
      .filter((product) => product.productId === null)
      .map((product) => product.rawName),
  )].sort();
  const warnings: string[] = [];

  if (status.decision === "manual_review") {
    warnings.push("status_requires_manual_review");
  }
  if (coordinates === null) {
    warnings.push("invalid_or_missing_coordinates");
  }
  if (manufacturer.id === null) {
    warnings.push("manufacturer_unresolved");
  }
  if (unresolvedProducts.length > 0) {
    warnings.push("products_unresolved");
  }

  const canBuildRoot = status.target !== null && coordinates !== null;
  const isPublic = status.target === "active";

  return {
    machineId,
    legacyStatus,
    targetStatus: status.target,
    statusDecision: status.decision,
    latitude: coordinates?.latitude ?? null,
    longitude: coordinates?.longitude ?? null,
    geohash,
    canGenerateGeohash: geohash !== null,
    manufacturerId: manufacturer.id,
    manufacturerResolution: manufacturer.kind,
    legacyProducts,
    resolvedProductIds,
    unresolvedProducts,
    sourceSchemaVersion: readSchemaVersion(data.schemaVersion),
    targetSchemaVersion: canBuildRoot ? 2 : null,
    plannedIndexCount: canBuildRoot && isPublic ? resolvedProductIds.length : 0,
    warnings,
  };
}

function resolveStatus(value: string | null): {
  readonly target: CanonicalMachineStatus | null;
  readonly decision: LegacyMachineMigrationPlan["statusDecision"];
} {
  if (
    value === "active" ||
    value === "underReview" ||
    value === "hidden" ||
    value === "merged" ||
    value === "removed"
  ) {
    return {target: value, decision: "canonical"};
  }
  return {target: null, decision: "manual_review"};
}

function readCoordinates(data: Readonly<Record<string, unknown>>): {
  readonly latitude: number;
  readonly longitude: number;
} | null {
  const pairs: readonly [unknown, unknown][] = [
    [data.lat, data.lng],
    [data.latitude, data.longitude],
  ];
  const location = asRecord(data.location);
  const candidates: readonly [unknown, unknown][] = location === null ?
    pairs :
    [...pairs, [location.latitude, location.longitude]];

  for (const [rawLatitude, rawLongitude] of candidates) {
    const latitude = readFiniteNumber(rawLatitude);
    const longitude = readFiniteNumber(rawLongitude);
    if (
      latitude !== null &&
      longitude !== null &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180
    ) {
      return {latitude, longitude};
    }
  }
  return null;
}

function resolveManufacturer(
  raw: string | null,
  catalog: MigrationMasterCatalog,
  aliases: MigrationAliases,
): {
  readonly id: string | null;
  readonly kind: LegacyMachineMigrationPlan["manufacturerResolution"];
} {
  if (raw === null) {
    return {id: null, kind: "unresolved"};
  }
  const active = catalog.manufacturers.filter((record) => record.isActive);
  const exactId = active.find((record) => record.id === raw);
  if (exactId !== undefined) {
    return {id: exactId.id, kind: "manufacturer_id"};
  }
  const normalized = normalizeMasterLabel(raw);
  const aliasedId = aliases.manufacturers?.[normalized];
  if (aliasedId !== undefined && active.some((record) => record.id === aliasedId)) {
    return {id: aliasedId, kind: "manual_alias"};
  }
  const matches = active.filter((record) =>
    [record.name, record.displayShortName, ...(record.searchKeywords ?? [])]
      .filter((label): label is string => label !== undefined)
      .some((label) => normalizeMasterLabel(label) === normalized)
  );
  return matches.length === 1 ?
    {id: matches[0].id, kind: "unique_label"} :
    {id: null, kind: "unresolved"};
}

function resolveProduct(
  candidate: LegacyProductCandidate,
  manufacturerId: string | null,
  catalog: MigrationMasterCatalog,
  aliases: MigrationAliases,
): Resolution {
  const active = catalog.products.filter((record) => record.isActive);
  if (candidate.explicitProductId !== null) {
    const exact = active.find((record) =>
      record.id === candidate.explicitProductId
    );
    if (exact !== undefined) {
      return {id: exact.id, kind: "product_id"};
    }
  }

  const normalized = normalizeMasterLabel(candidate.rawName);
  const aliasedId = aliases.products?.[normalized];
  if (aliasedId !== undefined && active.some((record) => record.id === aliasedId)) {
    return {id: aliasedId, kind: "manual_alias"};
  }

  const labelMatches = active.filter((record) =>
    [record.name, ...(record.searchKeywords ?? [])]
      .some((label) => normalizeMasterLabel(label) === normalized)
  );
  if (labelMatches.length === 1) {
    return {id: labelMatches[0].id, kind: "unique_label"};
  }
  if (manufacturerId !== null) {
    const manufacturerMatches = labelMatches.filter((record) =>
      record.manufacturerId === manufacturerId
    );
    if (manufacturerMatches.length === 1) {
      return {
        id: manufacturerMatches[0].id,
        kind: "manufacturer_and_label",
      };
    }
  }
  return {id: null, kind: "unresolved"};
}

function readLegacyProducts(
  data: Readonly<Record<string, unknown>>,
): readonly LegacyProductCandidate[] {
  const sources = ["products", "drinkSlots", "slots", "drinks"] as const;
  for (const sourceField of sources) {
    const raw = data[sourceField];
    if (!Array.isArray(raw)) {
      continue;
    }
    const result = raw
      .map((value) => readProductCandidate(value, sourceField))
      .filter((value): value is LegacyProductCandidate => value !== null);
    if (result.length > 0) {
      return result;
    }
  }
  return [];
}

function readProductCandidate(
  value: unknown,
  sourceField: LegacyProductCandidate["sourceField"],
): LegacyProductCandidate | null {
  const record = asRecord(value);
  if (record !== null) {
    const explicitProductId = readString(record.productId) ??
      readString(record.id);
    const rawName = readString(record.name) ??
      readString(record.drinkName) ??
      readString(record.productName) ??
      explicitProductId;
    if (rawName === null) {
      return null;
    }
    return {
      rawName,
      sourceField,
      explicitProductId,
      isSoldOut: record.isSoldOut === true || record.soldOut === true,
    };
  }
  const rawName = readString(value);
  return rawName === null ? null : {
    rawName,
    sourceField,
    explicitProductId: null,
    isSoldOut: false,
  };
}

function validateCatalog(catalog: MigrationMasterCatalog): void {
  const manufacturerIds = new Set(catalog.manufacturers.map((item) => item.id));
  const productIds = new Set(catalog.products.map((item) => item.id));
  if (manufacturerIds.size !== catalog.manufacturers.length) {
    throw new Error("Manufacturer master contains duplicate IDs.");
  }
  if (productIds.size !== catalog.products.length) {
    throw new Error("Product master contains duplicate IDs.");
  }
}

function readSchemaVersion(value: unknown): number | null {
  const number = readFiniteNumber(value);
  return number === null || !Number.isInteger(number) ? null : number;
}

function readFiniteNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function readString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const normalized = value.trim();
  return normalized.length === 0 ? null : normalized;
}

function asRecord(value: unknown): Readonly<Record<string, unknown>> | null {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Readonly<Record<string, unknown>>;
}
