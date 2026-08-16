import assert from "node:assert/strict";
import test from "node:test";

import {
  CreateVendingMachineValidationError,
  buildAutoMachineName,
  buildRequestDeduplicationId,
  encodeGeohash,
  mergePhotoProductWritePlans,
  mergeProductWritePlans,
  parseCreateVendingMachineInput,
  resolvePhotoManufacturerStatus,
} from "../src/create_vending_machine_core";

const REQUEST_ID = "123e4567-e89b-42d3-a456-426614174000";

test("geohash matches the existing v2 fixture", () => {
  assert.equal(
    encodeGeohash(35.681236, 139.767125, 6),
    "xn76ur",
  );
});

test("manufacturer request is normalized and duplicate products are removed", () => {
  const parsed = parseCreateVendingMachineInput({
    requestId: REQUEST_ID,
    registrationMethod: "manufacturer",
    location: {
      latitude: 35.68,
      longitude: 139.76,
    },
    name: "  駅前の自販機  ",
    manufacturerId: "suntory",
    confirmedProductIds: [
      "suntory_boss_black",
      "suntory_boss_black",
    ],
    temporaryPhotoUploadId: null,
    placeDescription: "  改札横  ",
    installationType: "outdoor",
  });

  assert.equal(parsed.name, "駅前の自販機");
  assert.equal(parsed.placeDescription, "改札横");
  assert.deepEqual(
    parsed.confirmedProductIds,
    ["suntory_boss_black"],
  );
});

test("locationOnly cannot contain manufacturer or confirmed products", () => {
  assert.throws(
    () => parseCreateVendingMachineInput({
      requestId: REQUEST_ID,
      registrationMethod: "locationOnly",
      location: {
        latitude: 35.68,
        longitude: 139.76,
      },
      name: null,
      manufacturerId: "suntory",
      confirmedProductIds: [],
      temporaryPhotoUploadId: null,
      placeDescription: null,
      installationType: "unknown",
    }),
    CreateVendingMachineValidationError,
  );

  assert.throws(
    () => parseCreateVendingMachineInput({
      requestId: REQUEST_ID,
      registrationMethod: "locationOnly",
      location: {
        latitude: 35.68,
        longitude: 139.76,
      },
      name: null,
      manufacturerId: null,
      confirmedProductIds: ["suntory_boss_black"],
      temporaryPhotoUploadId: null,
      placeDescription: null,
      installationType: "unknown",
    }),
    CreateVendingMachineValidationError,
  );
});

test("manual confirmation wins over manufacturer inference", () => {
  const plans = mergeProductWritePlans(
    ["suntory_tennensui"],
    ["suntory_boss_black", "suntory_tennensui"],
  );

  assert.deepEqual(plans, [
    {
      productId: "suntory_boss_black",
      evidenceType: "manufacturer_inferred",
      availability: "unknown",
      isConfirmed: false,
    },
    {
      productId: "suntory_tennensui",
      evidenceType: "manual_confirmed",
      availability: "available",
      isConfirmed: true,
    },
  ]);
});

test("auto name uses manufacturer display name or generic fallback", () => {
  assert.equal(
    buildAutoMachineName("サントリー"),
    "サントリーの自販機",
  );
  assert.equal(buildAutoMachineName(null), "自販機");
});

test("dedupe ID is deterministic and scoped by uid", () => {
  const first = buildRequestDeduplicationId("uid-a", REQUEST_ID);
  const second = buildRequestDeduplicationId("uid-a", REQUEST_ID);
  const otherUser = buildRequestDeduplicationId("uid-b", REQUEST_ID);

  assert.equal(first, second);
  assert.notEqual(first, otherUser);
  assert.match(first, /^[0-9a-f]{64}$/);
});

test("photo registration requires UUID v4 upload ID", () => {
  assert.throws(
    () => parseCreateVendingMachineInput({
      requestId: REQUEST_ID,
      registrationMethod: "photo",
      location: {latitude: 35.68, longitude: 139.76},
      name: null,
      manufacturerId: null,
      confirmedProductIds: [],
      temporaryPhotoUploadId: null,
      placeDescription: null,
      installationType: "unknown",
    }),
    CreateVendingMachineValidationError,
  );
});

test("photo confirmation uses photo evidence only for recognized IDs", () => {
  const plans = mergePhotoProductWritePlans(
    ["asahi_wonda_black", "otsuka_pocari_sweat"],
    new Set(["asahi_wonda_black"]),
  );

  assert.deepEqual(plans, [
    {
      productId: "asahi_wonda_black",
      evidenceType: "photo_confirmed",
      availability: "available",
      isConfirmed: true,
    },
    {
      productId: "otsuka_pocari_sweat",
      evidenceType: "manual_confirmed",
      availability: "available",
      isConfirmed: true,
    },
  ]);
});

test("photo machine brand status distinguishes recognized and manual", () => {
  const recognized = new Set(["asahi"]);
  assert.equal(
    resolvePhotoManufacturerStatus("asahi", recognized),
    "recognized_and_confirmed",
  );
  assert.equal(
    resolvePhotoManufacturerStatus("suntory", recognized),
    "confirmed",
  );
  assert.equal(
    resolvePhotoManufacturerStatus(null, recognized),
    "unknown",
  );
});
