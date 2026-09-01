import assert from "node:assert/strict";
import test from "node:test";

import {
  buildApprovedProductPairs,
  evaluateMigrationApplyState,
  hashMigrationReport,
  pairKey,
  validateApprovedMigrationReport,
  validateLiveRecordsAgainstApprovedReport,
} from "../src/migration/legacy_machine_migration_apply";
import {
  type LegacyMachineExportRecord,
  type MigrationMasterCatalog,
  planLegacyMachineMigration,
} from "../src/migration/legacy_machine_migration_planner";

const catalog: MigrationMasterCatalog = {
  manufacturers: [],
  products: [
    {
      id: "test_product",
      name: "Test Product",
      manufacturerId: "test_manufacturer",
      isActive: true,
    },
  ],
};

function approvedFixture(): {
  readonly records: readonly LegacyMachineExportRecord[];
  readonly report: ReturnType<typeof planLegacyMachineMigration>;
} {
  const records: LegacyMachineExportRecord[] = [];
  const statuses: Record<string, "active"> = {};
  for (let index = 0; index < 42; index += 1) {
    const id = `machine-${index.toString().padStart(2, "0")}`;
    const products: string[] = [];
    if (index < 25) {
      products.push("Test Product");
    }
    if (index < 8) {
      products.push(`Unknown ${index}`);
    }
    const status = index === 41 ? "active" : "available";
    if (index < 41) {
      statuses[id] = "active";
    }
    records.push({
      id,
      data: {
        status,
        lat: 35 + index / 1000,
        lng: 139 + index / 1000,
        products,
      },
    });
  }
  return {
    records,
    report: planLegacyMachineMigration(
      records,
      catalog,
      {},
      {machineStatuses: statuses},
    ),
  };
}

test("approved Phase B report and live pre/post roots pass exact validation", () => {
  const fixture = approvedFixture();
  const hash = hashMigrationReport(fixture.report);
  validateApprovedMigrationReport(fixture.report);
  validateLiveRecordsAgainstApprovedReport(
    fixture.records,
    fixture.report,
    catalog,
    {},
    hash,
  );

  const postApplyRecords = fixture.records.map((record) => ({
    id: record.id,
    data: {...record.data, status: "active"},
  }));
  validateLiveRecordsAgainstApprovedReport(
    postApplyRecords,
    fixture.report,
    catalog,
    {},
    hash,
  );

  const drifted = postApplyRecords.map((record, index) => index === 0 ? {
    id: record.id,
    data: {...record.data, lat: 36},
  } : record);
  assert.throws(
    () => validateLiveRecordsAgainstApprovedReport(
      drifted,
      fixture.report,
      catalog,
      {},
      hash,
    ),
    /no longer matches/,
  );
});

test("apply state accepts only the complete approved pre or post state", () => {
  const fixture = approvedFixture();
  const pairs = buildApprovedProductPairs(fixture.report);
  assert.equal(pairs.length, 25);
  const preStatuses = new Map(fixture.report.machines.map((machine) => [
    machine.machineId,
    machine.legacyStatus,
  ]));
  const pre = evaluateMigrationApplyState(
    fixture.report,
    preStatuses,
    new Set(),
    new Set(),
    7,
  );
  assert.deepEqual(pre, {
    state: "pre_apply",
    rootStatusWrites: 41,
    existingProductDocuments: 0,
    existingIndexDocuments: 0,
    nonPlanIndexDocuments: 7,
    plannedProductDocuments: 25,
    plannedIndexDocuments: 25,
    totalWrites: 91,
  });

  const postStatuses = new Map(fixture.report.machines.map((machine) => [
    machine.machineId,
    machine.targetStatus,
  ]));
  const pairKeys = new Set(pairs.map(pairKey));
  const post = evaluateMigrationApplyState(
    fixture.report,
    postStatuses,
    pairKeys,
    pairKeys,
    7,
  );
  assert.equal(post.state, "already_applied");
  assert.equal(post.totalWrites, 0);

  const partialStatuses = new Map(preStatuses);
  partialStatuses.set(fixture.report.machines[0].machineId, "active");
  assert.throws(
    () => evaluateMigrationApplyState(
      fixture.report,
      partialStatuses,
      new Set(),
      new Set(),
      7,
    ),
    /neither the approved pre-apply nor post-apply state/,
  );
  assert.throws(
    () => evaluateMigrationApplyState(
      fixture.report,
      preStatuses,
      new Set(),
      new Set(),
      8,
    ),
    /differs from the approved baseline/,
  );
});

test("product-pair availability preserves sold-out evidence", () => {
  const fixture = approvedFixture();
  const mutable = JSON.parse(JSON.stringify(fixture.report)) as unknown as {
    machines: Array<{
      legacyProducts: Array<{isSoldOut: boolean; productId: string | null}>;
    }>;
  };
  const first = mutable.machines[0] as {
    legacyProducts: Array<{isSoldOut: boolean; productId: string | null}>;
  };
  const resolved = first.legacyProducts.find((item) =>
    item.productId === "test_product"
  );
  assert.ok(resolved);
  resolved.isSoldOut = true;
  const pairs = buildApprovedProductPairs(
    mutable as unknown as ReturnType<typeof planLegacyMachineMigration>,
  );
  assert.equal(pairs[0].availability, "soldOut");
});
