import {createHash} from "node:crypto";
import {execFileSync} from "node:child_process";
import {readFile} from "node:fs/promises";
import {resolve} from "node:path";

import {getApps, initializeApp} from "firebase-admin/app";
import type {
  DocumentData,
  DocumentReference,
  DocumentSnapshot,
  Firestore,
  QueryDocumentSnapshot,
  Transaction,
} from "firebase-admin/firestore";
import {GeoPoint, Timestamp, getFirestore} from "firebase-admin/firestore";

import {
  PHASE_B_EXPECTED_NON_PLAN_INDEXES,
  PHASE_B_EXPECTED_PLANNED_INDEXES,
  type ApprovedMigrationProductPair,
  type MigrationApplyStateEvaluation,
  buildApprovedProductPairs,
  evaluateMigrationApplyState,
  indexDocumentId,
  pairKey,
  parseApprovedMigrationReport,
  validateApprovedMigrationReport,
  validateLiveRecordsAgainstApprovedReport,
} from "../src/migration/legacy_machine_migration_apply";
import type {
  LegacyMachineExportRecord,
  LegacyMigrationReport,
  MigrationAliases,
  MigrationMasterCatalog,
} from "../src/migration/legacy_machine_migration_planner";

const PRODUCTION_PROJECT_ID = "vendingnavi";
const PRODUCTION_DATABASE_ID = "(default)";
const APPLY_CONFIRMATION = "APPLY_APPROVED_PHASE_B_42";
const EXPECTED_MASTER_SHA256 =
  "334601845df4078be983c93fd8b43aa1ec74226101e208018a3ab13a0dca939d";
const EXPECTED_ALIASES_SHA256 =
  "a8692e16146670d382a5ec514af9cb066e82ae18110d65c55146b26f2177dcdd";

interface Options {
  readonly apply: boolean;
  readonly projectId: string;
  readonly databaseId: string;
  readonly approvedReportPath: string;
  readonly masterPath: string;
  readonly aliasesPath: string;
  readonly expectedReportSha256: string;
  readonly confirmation: string | null;
}

interface MasterProductWithGenres {
  readonly id: string;
  readonly genreIds: readonly string[];
}

interface LoadedInputs {
  readonly approvedReport: LegacyMigrationReport;
  readonly catalog: MigrationMasterCatalog;
  readonly aliases: MigrationAliases;
  readonly genresByProductId: ReadonlyMap<string, readonly string[]>;
  readonly approvedReportSha256: string;
}

interface InspectedState {
  readonly evaluation: MigrationApplyStateEvaluation;
  readonly sourceCommit: string;
}

async function main(): Promise<void> {
  const options = parseOptions(process.argv.slice(2));
  validateRuntime(options);
  const inputs = await loadInputs(options);
  const sourceCommit = readSourceCommit();
  if (options.apply) {
    assertGitClean();
  }

  const app = getApps()[0] ?? initializeApp({projectId: options.projectId});
  const firestore = getFirestore(app, options.databaseId);
  const before = await inspectFirestoreState(
    firestore,
    inputs,
    options.expectedReportSha256,
    sourceCommit,
  );

  if (!options.apply) {
    writeResult("PHASE_B_PRODUCTION_DRY_RUN", before, inputs);
    return;
  }

  const transactionResult = await applyApprovedMigration(
    firestore,
    inputs,
    options.expectedReportSha256,
  );
  const after = await inspectFirestoreState(
    firestore,
    inputs,
    options.expectedReportSha256,
    sourceCommit,
  );
  if (
    after.evaluation.state !== "already_applied" ||
    after.evaluation.totalWrites !== 0
  ) {
    throw new Error("Post-apply verification did not reach a zero-diff state.");
  }

  writeResult("PHASE_B_PRODUCTION_APPLY", after, inputs, {
    transactionState: transactionResult.state,
    committedWrites: transactionResult.totalWrites,
    secondRunDiff: after.evaluation.totalWrites,
  });
}

async function inspectFirestoreState(
  firestore: Firestore,
  inputs: LoadedInputs,
  expectedReportSha256: string,
  sourceCommit: string,
): Promise<InspectedState> {
  const pairs = buildApprovedProductPairs(inputs.approvedReport);
  const machineSnapshot = await firestore.collection("vending_machines").get();
  const records = machineSnapshot.docs.map(toExportRecord);
  validateLiveRecordsAgainstApprovedReport(
    records,
    inputs.approvedReport,
    inputs.catalog,
    inputs.aliases,
    expectedReportSha256,
  );

  const productRefs = pairs.map((pair) => machineProductRef(firestore, pair));
  const [productSnapshots, indexSnapshot, masterSnapshots] = await Promise.all([
    firestore.getAll(...productRefs),
    firestore.collection("machine_product_index").get(),
    firestore.getAll(...masterRefs(firestore, pairs)),
  ]);
  validateMasterSnapshots(masterSnapshots, inputs.genresByProductId);
  const existingProducts = validateProductSnapshots(productSnapshots, pairs);
  const indexState = validateIndexSnapshot(
    indexSnapshot.docs,
    pairs,
    inputs.genresByProductId,
  );

  return {
    evaluation: evaluateMigrationApplyState(
      inputs.approvedReport,
      statusMap(records),
      existingProducts,
      indexState.existingPairKeys,
      indexState.nonPlanCount,
    ),
    sourceCommit,
  };
}

async function applyApprovedMigration(
  firestore: Firestore,
  inputs: LoadedInputs,
  expectedReportSha256: string,
): Promise<MigrationApplyStateEvaluation> {
  const pairs = buildApprovedProductPairs(inputs.approvedReport);
  const approvedById = new Map(
    inputs.approvedReport.machines.map((machine) => [machine.machineId, machine]),
  );
  return firestore.runTransaction(async (transaction) => {
    const machineSnapshot = await transaction.get(
      firestore.collection("vending_machines"),
    );
    const records = machineSnapshot.docs.map(toExportRecord);
    validateLiveRecordsAgainstApprovedReport(
      records,
      inputs.approvedReport,
      inputs.catalog,
      inputs.aliases,
      expectedReportSha256,
    );

    const productRefs = pairs.map((pair) => machineProductRef(firestore, pair));
    const productSnapshots = await transaction.getAll(...productRefs);
    const indexSnapshot = await transaction.get(
      firestore.collection("machine_product_index"),
    );
    const masters = await transaction.getAll(...masterRefs(firestore, pairs));
    validateMasterSnapshots(masters, inputs.genresByProductId);
    const existingProducts = validateProductSnapshots(productSnapshots, pairs);
    const indexState = validateIndexSnapshot(
      indexSnapshot.docs,
      pairs,
      inputs.genresByProductId,
    );
    const evaluation = evaluateMigrationApplyState(
      inputs.approvedReport,
      statusMap(records),
      existingProducts,
      indexState.existingPairKeys,
      indexState.nonPlanCount,
    );
    if (evaluation.state === "already_applied") {
      return evaluation;
    }

    const now = Timestamp.now();
    for (const record of records) {
      const approved = approvedById.get(record.id);
      if (approved === undefined || approved.targetStatus === null) {
        throw new Error("Approved machine disappeared during apply.");
      }
      const currentStatus = readOptionalString(record.data.status);
      if (currentStatus !== approved.targetStatus) {
        transaction.update(
          firestore.collection("vending_machines").doc(record.id),
          {status: approved.targetStatus},
        );
      }
    }

    for (const pair of pairs) {
      transaction.create(machineProductRef(firestore, pair), {
        productId: pair.productId,
        evidenceType: "manual_confirmed",
        availability: pair.availability,
        isActive: true,
        confirmedBy: null,
        confirmedAt: null,
        createdAt: now,
        updatedAt: now,
      });
      transaction.create(
        firestore.collection("machine_product_index").doc(indexDocumentId(pair)),
        {
          machineId: pair.machineId,
          productId: pair.productId,
          genreIds: inputs.genresByProductId.get(pair.productId) ?? [],
          location: new GeoPoint(pair.latitude, pair.longitude),
          geohash: pair.geohash,
          evidenceType: "manual_confirmed",
          availability: pair.availability,
          isActive: true,
          machineStatus: "active",
          machineUpdatedAt: now,
          updatedAt: now,
        },
      );
    }
    return evaluation;
  });
}

function validateProductSnapshots(
  snapshots: readonly DocumentSnapshot[],
  pairs: readonly ApprovedMigrationProductPair[],
): ReadonlySet<string> {
  if (snapshots.length !== pairs.length) {
    throw new Error("Product preflight returned an unexpected result count.");
  }
  const existing = new Set<string>();
  for (let index = 0; index < snapshots.length; index += 1) {
    const snapshot = snapshots[index];
    const pair = pairs[index];
    if (!snapshot.exists) {
      continue;
    }
    if (!matchesProductDocument(snapshot.data(), pair)) {
      throw new Error("A planned machine product path contains different data.");
    }
    existing.add(pairKey(pair));
  }
  return existing;
}

function validateIndexSnapshot(
  snapshots: readonly QueryDocumentSnapshot[],
  pairs: readonly ApprovedMigrationProductPair[],
  genresByProductId: ReadonlyMap<string, readonly string[]>,
): {
  readonly existingPairKeys: ReadonlySet<string>;
  readonly nonPlanCount: number;
} {
  const pairByIndexId = new Map(
    pairs.map((pair) => [indexDocumentId(pair), pair]),
  );
  const existing = new Set<string>();
  let nonPlanCount = 0;
  for (const snapshot of snapshots) {
    const pair = pairByIndexId.get(snapshot.id);
    if (pair === undefined) {
      nonPlanCount += 1;
      continue;
    }
    const genreIds = genresByProductId.get(pair.productId);
    if (
      genreIds === undefined ||
      !matchesIndexDocument(snapshot.data(), pair, genreIds)
    ) {
      throw new Error("A planned search-index path contains different data.");
    }
    existing.add(pairKey(pair));
  }
  return {existingPairKeys: existing, nonPlanCount};
}

function matchesProductDocument(
  data: DocumentData | undefined,
  pair: ApprovedMigrationProductPair,
): boolean {
  return data !== undefined &&
    data.productId === pair.productId &&
    data.evidenceType === "manual_confirmed" &&
    data.availability === pair.availability &&
    data.isActive === true &&
    (data.confirmedBy === null || data.confirmedBy === undefined) &&
    (data.confirmedAt === null || data.confirmedAt === undefined) &&
    data.createdAt instanceof Timestamp &&
    data.updatedAt instanceof Timestamp;
}

function matchesIndexDocument(
  data: DocumentData | undefined,
  pair: ApprovedMigrationProductPair,
  expectedGenreIds: readonly string[],
): boolean {
  if (data === undefined || !(data.location instanceof GeoPoint)) {
    return false;
  }
  return data.machineId === pair.machineId &&
    data.productId === pair.productId &&
    stringArraysEqual(data.genreIds, expectedGenreIds) &&
    data.location.latitude === pair.latitude &&
    data.location.longitude === pair.longitude &&
    data.geohash === pair.geohash &&
    data.evidenceType === "manual_confirmed" &&
    data.availability === pair.availability &&
    data.isActive === true &&
    data.machineStatus === "active" &&
    data.machineUpdatedAt instanceof Timestamp &&
    data.updatedAt instanceof Timestamp;
}

function validateMasterSnapshots(
  snapshots: readonly DocumentSnapshot[],
  genresByProductId: ReadonlyMap<string, readonly string[]>,
): void {
  if (snapshots.length !== genresByProductId.size) {
    throw new Error("Product master preflight returned an unexpected count.");
  }
  for (const snapshot of snapshots) {
    const expectedGenres = genresByProductId.get(snapshot.id);
    const data = snapshot.data();
    if (
      expectedGenres === undefined ||
      !snapshot.exists ||
      data?.isActive !== true ||
      !stringArraysEqual(data.genreIds, expectedGenres)
    ) {
      throw new Error("Live product master differs from the approved fixture.");
    }
  }
}

function masterRefs(
  firestore: Firestore,
  pairs: readonly ApprovedMigrationProductPair[],
): readonly DocumentReference[] {
  return [...new Set(pairs.map((pair) => pair.productId))]
    .sort()
    .map((productId) => firestore.collection("products").doc(productId));
}

function machineProductRef(
  firestore: Firestore,
  pair: ApprovedMigrationProductPair,
): DocumentReference {
  return firestore
    .collection("vending_machines")
    .doc(pair.machineId)
    .collection("products")
    .doc(pair.productId);
}

function statusMap(
  records: readonly LegacyMachineExportRecord[],
): ReadonlyMap<string, string | null> {
  return new Map(records.map((record) => [
    record.id,
    readOptionalString(record.data.status),
  ]));
}

function toExportRecord(
  snapshot: QueryDocumentSnapshot,
): LegacyMachineExportRecord {
  return {id: snapshot.id, data: snapshot.data()};
}

async function loadInputs(options: Options): Promise<LoadedInputs> {
  const [approvedBytes, masterBytes, aliasesBytes] = await Promise.all([
    readFile(options.approvedReportPath),
    readFile(options.masterPath),
    readFile(options.aliasesPath),
  ]);
  const approvedReportSha256 = sha256(approvedBytes);
  if (approvedReportSha256 !== options.expectedReportSha256) {
    throw new Error("Approved report SHA-256 does not match the required value.");
  }
  if (sha256(masterBytes) !== EXPECTED_MASTER_SHA256) {
    throw new Error("Master fixture SHA-256 does not match the approved value.");
  }
  if (sha256(aliasesBytes) !== EXPECTED_ALIASES_SHA256) {
    throw new Error("Alias fixture SHA-256 does not match the approved value.");
  }

  const approvedReport = parseApprovedMigrationReport(
    JSON.parse(approvedBytes.toString("utf8")) as unknown,
  );
  const masterValue = JSON.parse(masterBytes.toString("utf8")) as unknown;
  const aliasesValue = JSON.parse(aliasesBytes.toString("utf8")) as unknown;
  const catalog = parseCatalog(masterValue);
  const aliases = parseAliases(aliasesValue);
  validateApprovedMigrationReport(approvedReport);
  const pairs = buildApprovedProductPairs(approvedReport);
  const genresByProductId = parseGenres(masterValue, pairs);
  return {
    approvedReport,
    catalog,
    aliases,
    genresByProductId,
    approvedReportSha256,
  };
}

function parseOptions(args: readonly string[]): Options {
  const value = (name: string): string | null => {
    const prefix = `--${name}=`;
    return args.find((item) => item.startsWith(prefix))?.slice(prefix.length)
      .trim() ?? null;
  };
  const approvedReport = value("approved-report");
  const expectedHash = value("expected-report-sha256")?.toLowerCase() ?? null;
  if (approvedReport === null || approvedReport.length === 0) {
    throw new Error("Required argument: --approved-report=<private-report.json>");
  }
  if (expectedHash === null || !/^[0-9a-f]{64}$/.test(expectedHash)) {
    throw new Error("Required argument: --expected-report-sha256=<64 hex>");
  }
  const master = value("master") ?? "fixtures/master_fixture.json";
  const aliases = value("aliases") ??
    "fixtures/legacy_machine_migration_aliases.json";
  return {
    apply: args.includes("--apply"),
    projectId: value("project") ?? "",
    databaseId: value("database") ?? "",
    approvedReportPath: resolve(approvedReport),
    masterPath: resolve(master),
    aliasesPath: resolve(aliases),
    expectedReportSha256: expectedHash,
    confirmation: value("confirm"),
  };
}

function validateRuntime(options: Options): void {
  if (
    options.projectId !== PRODUCTION_PROJECT_ID ||
    options.databaseId !== PRODUCTION_DATABASE_ID
  ) {
    throw new Error("Phase B apply is locked to the approved project/database.");
  }
  if (process.env.FIRESTORE_EMULATOR_HOST !== undefined) {
    throw new Error("Phase B production verification refuses Firestore Emulator.");
  }
  const ambientProject = process.env.GOOGLE_CLOUD_PROJECT?.trim();
  if (
    ambientProject !== undefined &&
    ambientProject.length > 0 &&
    ambientProject !== PRODUCTION_PROJECT_ID
  ) {
    throw new Error("Ambient Google Cloud project differs from vendingnavi.");
  }
  if (
    options.apply &&
    options.confirmation !== APPLY_CONFIRMATION
  ) {
    throw new Error(
      `Production apply requires --confirm=${APPLY_CONFIRMATION}.`,
    );
  }
}

function parseCatalog(value: unknown): MigrationMasterCatalog {
  const root = asRecord(value);
  if (
    root === null ||
    !Array.isArray(root.manufacturers) ||
    !Array.isArray(root.products)
  ) {
    throw new Error("Invalid master fixture.");
  }
  return {
    manufacturers: root.manufacturers as MigrationMasterCatalog["manufacturers"],
    products: root.products as MigrationMasterCatalog["products"],
  };
}

function parseAliases(value: unknown): MigrationAliases {
  const root = asRecord(value);
  if (root === null) {
    throw new Error("Invalid aliases fixture.");
  }
  return root as MigrationAliases;
}

function parseGenres(
  value: unknown,
  pairs: readonly ApprovedMigrationProductPair[],
): ReadonlyMap<string, readonly string[]> {
  const root = asRecord(value);
  if (root === null || !Array.isArray(root.products)) {
    throw new Error("Master fixture has no products array.");
  }
  const products = root.products.map((raw) => {
    const record = asRecord(raw);
    if (record === null || typeof record.id !== "string") {
      throw new Error("Master fixture contains an invalid product.");
    }
    return {
      id: record.id,
      genreIds: readStringArray(record.genreIds),
    } satisfies MasterProductWithGenres;
  });
  const byId = new Map(products.map((product) => [product.id, product.genreIds]));
  const requiredIds = [...new Set(pairs.map((pair) => pair.productId))].sort();
  const result = new Map<string, readonly string[]>();
  for (const productId of requiredIds) {
    const genres = byId.get(productId);
    if (genres === undefined) {
      throw new Error("Approved pair references a missing master product.");
    }
    result.set(productId, genres);
  }
  return result;
}

function writeResult(
  operation: string,
  inspected: InspectedState,
  inputs: LoadedInputs,
  extra: Readonly<Record<string, unknown>> = {},
): void {
  const evaluation = inspected.evaluation;
  process.stdout.write(`${JSON.stringify({
    operation,
    project: PRODUCTION_PROJECT_ID,
    database: PRODUCTION_DATABASE_ID,
    migrationRevision: inputs.approvedReport.revision,
    sourceCommit: inspected.sourceCommit,
    approvedReportSha256: inputs.approvedReportSha256,
    state: evaluation.state,
    rootStatusWrites: evaluation.rootStatusWrites,
    plannedProductDocuments: evaluation.plannedProductDocuments,
    existingProductDocuments: evaluation.existingProductDocuments,
    plannedIndexDocuments: evaluation.plannedIndexDocuments,
    existingIndexDocuments: evaluation.existingIndexDocuments,
    nonPlanIndexDocuments: evaluation.nonPlanIndexDocuments,
    totalWrites: evaluation.totalWrites,
    expectedNonPlanIndexes: PHASE_B_EXPECTED_NON_PLAN_INDEXES,
    expectedPlannedIndexes: PHASE_B_EXPECTED_PLANNED_INDEXES,
    ...extra,
  }, null, 2)}\n`);
}

function readSourceCommit(): string {
  return execFileSync("git", ["rev-parse", "HEAD"], {
    encoding: "utf8",
  }).trim();
}

function assertGitClean(): void {
  const status = execFileSync("git", ["status", "--porcelain"], {
    encoding: "utf8",
  }).trim();
  if (status.length > 0) {
    throw new Error("Production apply requires a clean Git worktree.");
  }
}

function sha256(value: Uint8Array): string {
  return createHash("sha256").update(value).digest("hex");
}

function readOptionalString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const normalized = value.trim();
  return normalized.length === 0 ? null : normalized;
}

function readStringArray(value: unknown): readonly string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const result = value.map((item) => {
    if (typeof item !== "string" || item.trim().length === 0) {
      throw new Error("Master genreIds contains an invalid value.");
    }
    return item.trim();
  });
  return [...new Set(result)];
}

function stringArraysEqual(
  value: unknown,
  expected: readonly string[],
): boolean {
  if (!Array.isArray(value) || value.length !== expected.length) {
    return false;
  }
  return value.every((item, index) => item === expected[index]);
}

function asRecord(value: unknown): Readonly<Record<string, unknown>> | null {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Readonly<Record<string, unknown>>;
}

void main().catch((error: unknown) => {
  console.error(
    "Approved legacy vending-machine migration failed.",
    error instanceof Error ? error.message : "UnknownError",
  );
  process.exitCode = 1;
});
