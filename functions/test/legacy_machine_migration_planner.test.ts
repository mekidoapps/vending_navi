import assert from "node:assert/strict";
import test from "node:test";

import {
  LEGACY_MACHINE_MIGRATION_REVISION,
  type MigrationMasterCatalog,
  planLegacyMachineMigration,
} from "../src/migration/legacy_machine_migration_planner";
import approvedAliases from "../fixtures/legacy_machine_migration_aliases.json";
import fullMasterCatalog from "../fixtures/master_fixture.json";

const catalog: MigrationMasterCatalog = {
  manufacturers: [
    {
      id: "suntory",
      name: "サントリー",
      displayShortName: "サントリー",
      searchKeywords: ["suntory"],
      isActive: true,
    },
    {
      id: "asahi",
      name: "アサヒ",
      displayShortName: "アサヒ",
      searchKeywords: ["アサヒ飲料"],
      isActive: true,
    },
  ],
  products: [
    {
      id: "suntory_boss_black",
      name: "ボス ブラック",
      manufacturerId: "suntory",
      searchKeywords: ["BOSS BLACK", "ボスブラック"],
      isActive: true,
    },
    {
      id: "suntory_tennensui",
      name: "サントリー天然水",
      manufacturerId: "suntory",
      searchKeywords: ["天然水"],
      isActive: true,
    },
    {
      id: "asahi_oishii_mizu",
      name: "おいしい水",
      manufacturerId: "asahi",
      searchKeywords: ["天然水"],
      isActive: true,
    },
  ],
};

test("canonical active machine becomes a deterministic v2 plan", () => {
  const report = planLegacyMachineMigration([
    {
      id: "machine-b",
      data: {
        status: "active",
        manufacturer: "サントリー",
        lat: 35.681236,
        lng: 139.767125,
        products: [
          {name: "BOSS BLACK", isSoldOut: false},
          {productId: "suntory_boss_black", name: "重複"},
        ],
      },
    },
  ], catalog);

  assert.equal(report.revision, LEGACY_MACHINE_MIGRATION_REVISION);
  assert.equal(report.summary.ready, 1);
  assert.equal(report.summary.plannedIndexCount, 1);
  assert.deepEqual(report.machines[0], {
    machineId: "machine-b",
    legacyStatus: "active",
    targetStatus: "active",
    statusDecision: "canonical",
    latitude: 35.681236,
    longitude: 139.767125,
    geohash: "xn76ur",
    canGenerateGeohash: true,
    manufacturerId: "suntory",
    manufacturerResolution: "unique_label",
    legacyProducts: [
      {
        rawName: "BOSS BLACK",
        sourceField: "products",
        explicitProductId: null,
        isSoldOut: false,
        productId: "suntory_boss_black",
        resolutionKind: "unique_label",
      },
      {
        rawName: "重複",
        sourceField: "products",
        explicitProductId: "suntory_boss_black",
        isSoldOut: false,
        productId: "suntory_boss_black",
        resolutionKind: "product_id",
      },
    ],
    resolvedProductIds: ["suntory_boss_black"],
    unresolvedProducts: [],
    sourceSchemaVersion: null,
    targetSchemaVersion: 2,
    plannedIndexCount: 1,
    warnings: [],
  });
});

test("available and missing status remain manual review without guessing", () => {
  const report = planLegacyMachineMigration([
    {
      id: "available",
      data: {
        status: "available",
        latitude: 35.68,
        longitude: 139.76,
      },
    },
    {
      id: "missing",
      data: {
        lat: 35.68,
        lng: 139.76,
      },
    },
  ], catalog);

  assert.equal(report.summary.manualReview, 2);
  for (const machine of report.machines) {
    assert.equal(machine.targetStatus, null);
    assert.equal(machine.targetSchemaVersion, null);
    assert.equal(machine.plannedIndexCount, 0);
    assert.ok(machine.warnings.includes("status_requires_manual_review"));
  }
});

test("owner-approved per-machine decisions preserve legacy public visibility", () => {
  const report = planLegacyMachineMigration([
    {
      id: "available",
      data: {status: "available", latitude: 35.68, longitude: 139.76},
    },
    {
      id: "missing",
      data: {lat: 35.68, lng: 139.76},
    },
  ], catalog, {}, {
    machineStatuses: {available: "active", missing: "active"},
  });

  assert.equal(report.summary.ready, 2);
  assert.equal(report.summary.manualReview, 0);
  for (const machine of report.machines) {
    assert.equal(machine.targetStatus, "active");
    assert.equal(machine.statusDecision, "owner_approved");
    assert.equal(machine.targetSchemaVersion, 2);
    assert.ok(!machine.warnings.includes("status_requires_manual_review"));
  }
});

test("status decisions reject stale IDs and canonical-status overrides", () => {
  assert.throws(
    () => planLegacyMachineMigration([
      {id: "present", data: {status: "available", lat: 1, lng: 1}},
    ], catalog, {}, {machineStatuses: {missing: "active"}}),
    /does not match an exported machine ID/,
  );
  assert.throws(
    () => planLegacyMachineMigration([
      {id: "canonical", data: {status: "hidden", lat: 1, lng: 1}},
    ], catalog, {}, {machineStatuses: {canonical: "active"}}),
    /cannot override canonical status/,
  );
});

test("approved legacy product aliases resolve only the four exact labels", () => {
  const report = planLegacyMachineMigration([
    {
      id: "approved-aliases",
      data: {
        status: "active",
        lat: 35.68,
        lng: 139.76,
        products: [
          "タリーズ　バリスタブラック",
          "ポカリスエット　缶",
          "ミネラル麦茶",
          "BOSS レインボーマウンテン",
          "クラフトボス ブラック",
        ],
      },
    },
  ], fullMasterCatalog as MigrationMasterCatalog, approvedAliases);

  assert.deepEqual(report.machines[0].resolvedProductIds, [
    "ito_en_kenko_mineral_mugicha",
    "ito_en_tullys_coffee_black",
    "otsuka_pocari_sweat",
    "suntory_boss_rainbow_mountain_blend",
  ]);
  assert.deepEqual(
    report.machines[0].unresolvedProducts,
    ["クラフトボス ブラック"],
  );
});

test("invalid coordinates are failures and are never corrected", () => {
  const report = planLegacyMachineMigration([
    {
      id: "invalid-coordinate",
      data: {
        status: "active",
        lat: 91,
        lng: 139.76,
      },
    },
  ], catalog);

  const machine = report.machines[0];
  assert.equal(machine.latitude, null);
  assert.equal(machine.longitude, null);
  assert.equal(machine.geohash, null);
  assert.equal(machine.targetSchemaVersion, null);
  assert.ok(machine.warnings.includes("invalid_or_missing_coordinates"));
});

test("manufacturer disambiguates an otherwise ambiguous exact label", () => {
  const report = planLegacyMachineMigration([
    {
      id: "ambiguous",
      data: {
        status: "active",
        manufacturer: "SUNTORY",
        location: {latitude: 35.68, longitude: 139.76},
        drinks: ["天然水", "マスタ外商品"],
      },
    },
  ], catalog);

  const machine = report.machines[0];
  assert.deepEqual(machine.resolvedProductIds, ["suntory_tennensui"]);
  assert.deepEqual(machine.unresolvedProducts, ["マスタ外商品"]);
  assert.equal(
    machine.legacyProducts[0].resolutionKind,
    "manufacturer_and_label",
  );
  assert.ok(machine.warnings.includes("products_unresolved"));
});

test("manual aliases must point to active canonical IDs", () => {
  const report = planLegacyMachineMigration([
    {
      id: "alias",
      data: {
        status: "active",
        manufacturer: "サントリー社",
        lat: "35.68",
        lng: "139.76",
        products: [{name: "ボス黒"}],
      },
    },
  ], catalog, {
    manufacturers: {"サントリー社": "suntory"},
    products: {"ボス黒": "suntory_boss_black"},
  });

  const machine = report.machines[0];
  assert.equal(machine.manufacturerResolution, "manual_alias");
  assert.equal(machine.legacyProducts[0].resolutionKind, "manual_alias");

  assert.throws(
    () => planLegacyMachineMigration([], catalog, {
      products: {"not normalized  ": "suntory_boss_black"},
    }),
    /must already be normalized/,
  );
  assert.throws(
    () => planLegacyMachineMigration([], catalog, {
      products: {"不存在": "unknown_product"},
    }),
    /inactive or unknown ID/,
  );
});

test("planning is stable across input order and rejects duplicate IDs", () => {
  const first = planLegacyMachineMigration([
    {id: "z", data: {status: "active", lat: 1, lng: 1}},
    {id: "a", data: {status: "active", lat: 2, lng: 2}},
  ], catalog);
  const second = planLegacyMachineMigration([
    {id: "a", data: {status: "active", lat: 2, lng: 2}},
    {id: "z", data: {status: "active", lat: 1, lng: 1}},
  ], catalog);

  assert.deepEqual(first, second);
  assert.throws(
    () => planLegacyMachineMigration([
      {id: "same", data: {}},
      {id: "same", data: {}},
    ], catalog),
    /Duplicate machine ID/,
  );
});
