import assert from "node:assert/strict";
import test from "node:test";

import {
  SubmitMachineCorrectionValidationError,
  buildMachineCorrectionDeduplicationId,
  buildMachineCorrectionId,
  parseSubmitMachineCorrectionInput,
  removeUnchangedCorrectionFields,
} from "../src/submit_machine_correction_core";

const REQUEST_ID =
  "11111111-1111-4111-8111-111111111111";

test("valid structured correction is parsed", () => {
  const value = parseSubmitMachineCorrectionInput({
    requestId: REQUEST_ID,
    machineId: "machine_v2_station_east",
    changes: {
      name: " 新しい自販機 ",
      manufacturerId: "suntory",
      location: {
        latitude: 35.1,
        longitude: 139.2,
      },
      placeDescription: " 駅前 ",
      installationType: "outdoor",
    },
    message: " 確認しました ",
  });

  assert.equal(value.changes.name, "新しい自販機");
  assert.equal(
    value.changes.placeDescription,
    "駅前",
  );
  assert.equal(value.message, "確認しました");
});

test("manufacturer and place description can be cleared", () => {
  const value = parseSubmitMachineCorrectionInput({
    requestId: REQUEST_ID,
    machineId: "machine_v2_station_east",
    changes: {
      manufacturerId: null,
      placeDescription: null,
    },
    message: null,
  });

  assert.equal(value.changes.manufacturerId, null);
  assert.equal(value.changes.placeDescription, null);
});

test("empty changes are rejected", () => {
  assert.throws(
    () => parseSubmitMachineCorrectionInput({
      requestId: REQUEST_ID,
      machineId: "machine_v2_station_east",
      changes: {},
      message: null,
    }),
    SubmitMachineCorrectionValidationError,
  );
});

test("unknown request fields are rejected", () => {
  assert.throws(
    () => parseSubmitMachineCorrectionInput({
      requestId: REQUEST_ID,
      machineId: "machine_v2_station_east",
      changes: {name: "test"},
      message: null,
      unexpected: true,
    }),
    SubmitMachineCorrectionValidationError,
  );
});

test("requestId must be UUID v4", () => {
  assert.throws(
    () => parseSubmitMachineCorrectionInput({
      requestId:
        "11111111-1111-1111-8111-111111111111",
      machineId: "machine_v2_station_east",
      changes: {name: "test"},
      message: null,
    }),
    SubmitMachineCorrectionValidationError,
  );
});

test("invalid coordinates are rejected", () => {
  assert.throws(
    () => parseSubmitMachineCorrectionInput({
      requestId: REQUEST_ID,
      machineId: "machine_v2_station_east",
      changes: {
        location: {
          latitude: 91,
          longitude: 139,
        },
      },
      message: null,
    }),
    SubmitMachineCorrectionValidationError,
  );
});

test("invalid installation type is rejected", () => {
  assert.throws(
    () => parseSubmitMachineCorrectionInput({
      requestId: REQUEST_ID,
      machineId: "machine_v2_station_east",
      changes: {
        installationType: "underground",
      },
      message: null,
    }),
    SubmitMachineCorrectionValidationError,
  );
});

test("unchanged values are removed but clearing remains meaningful", () => {
  const changes = removeUnchangedCorrectionFields(
    {
      name: "駅東口の自販機",
      manufacturerId: null,
      location: {
        latitude: 35.681236,
        longitude: 139.767125,
      },
      placeDescription: null,
      installationType: "indoor",
    },
    {
      name: "駅東口の自販機",
      manufacturerId: "suntory",
      location: {
        latitude: 35.681236,
        longitude: 139.767125,
      },
      placeDescription: "駅東口の壁沿い",
      installationType: "outdoor",
    },
  );

  assert.deepEqual(changes, {
    manufacturerId: null,
    placeDescription: null,
    installationType: "indoor",
  });
});

test("dedupe ID is deterministic and scoped by uid", () => {
  const first =
    buildMachineCorrectionDeduplicationId(
      "uid-a",
      REQUEST_ID,
    );

  assert.equal(
    first,
    buildMachineCorrectionDeduplicationId(
      "uid-a",
      REQUEST_ID,
    ),
  );

  assert.notEqual(
    first,
    buildMachineCorrectionDeduplicationId(
      "uid-b",
      REQUEST_ID,
    ),
  );
});

test("correction ID is deterministic and request scoped", () => {
  const first =
    buildMachineCorrectionId(
      "uid-a",
      REQUEST_ID,
    );

  assert.match(first, /^c_[0-9a-f]{30}$/);

  assert.equal(
    first,
    buildMachineCorrectionId(
      "uid-a",
      REQUEST_ID,
    ),
  );

  assert.notEqual(
    first,
    buildMachineCorrectionId(
      "uid-a",
      "22222222-2222-4222-8222-222222222222",
    ),
  );
});
