import assert from "node:assert/strict";
import test from "node:test";

import {
  SubmitMachineReportValidationError,
  buildMachineReportDeduplicationId,
  buildMachineReportId,
  parseStoredMachineReportResult,
  parseSubmitMachineReportInput,
} from "../src/submit_machine_report_core";

const REQUEST_ID =
  "11111111-1111-4111-8111-111111111111";

test("valid machine report is parsed", () => {
  const value = parseSubmitMachineReportInput({
    requestId: REQUEST_ID,
    machineId: "machine_v2_station_east",
    photoId: null,
    category: "machineRemoved",
    message: " 撤去されていました ",
  });

  assert.deepEqual(value, {
    requestId: REQUEST_ID,
    machineId: "machine_v2_station_east",
    photoId: null,
    category: "machineRemoved",
    message: "撤去されていました",
  });
});

test("formal photo ID can be attached", () => {
  const photoId =
    "p_0123456789abcdef0123456789abcd";

  const value = parseSubmitMachineReportInput({
    requestId: REQUEST_ID,
    machineId: "machine_v2_station_east",
    photoId,
    category: "inappropriatePhoto",
    message: null,
  });

  assert.equal(value.photoId, photoId);
});

test("empty message is normalized to null", () => {
  const value = parseSubmitMachineReportInput({
    requestId: REQUEST_ID,
    machineId: "machine_v2_station_east",
    photoId: null,
    category: "other",
    message: "   ",
  });

  assert.equal(value.message, null);
});

test("all MVP report categories are accepted", () => {
  const categories = [
    "machineRemoved",
    "duplicate",
    "inaccessible",
    "inappropriatePhoto",
    "inappropriateText",
    "other",
  ];

  for (const category of categories) {
    const value = parseSubmitMachineReportInput({
      requestId: REQUEST_ID,
      machineId: "machine_v2_station_east",
      photoId: null,
      category,
      message: null,
    });

    assert.equal(value.category, category);
  }
});

test("old correction-style categories are rejected", () => {
  for (
    const category of [
      "wrongLocation",
      "wrongManufacturer",
      "wrongProducts",
    ]
  ) {
    assert.throws(
      () => parseSubmitMachineReportInput({
        requestId: REQUEST_ID,
        machineId: "machine_v2_station_east",
        photoId: null,
        category,
        message: null,
      }),
      SubmitMachineReportValidationError,
    );
  }
});

test("invalid photo ID is rejected", () => {
  assert.throws(
    () => parseSubmitMachineReportInput({
      requestId: REQUEST_ID,
      machineId: "machine_v2_station_east",
      photoId: "photo-123",
      category: "inappropriatePhoto",
      message: null,
    }),
    SubmitMachineReportValidationError,
  );
});

test("unknown fields are rejected", () => {
  assert.throws(
    () => parseSubmitMachineReportInput({
      requestId: REQUEST_ID,
      machineId: "machine_v2_station_east",
      photoId: null,
      category: "other",
      message: null,
      unexpected: true,
    }),
    SubmitMachineReportValidationError,
  );
});

test("requestId must be UUID v4", () => {
  assert.throws(
    () => parseSubmitMachineReportInput({
      requestId:
        "11111111-1111-1111-8111-111111111111",
      machineId: "machine_v2_station_east",
      photoId: null,
      category: "other",
      message: null,
    }),
    SubmitMachineReportValidationError,
  );
});

test("dedupe ID is deterministic and uid scoped", () => {
  const first =
    buildMachineReportDeduplicationId(
      "uid-a",
      REQUEST_ID,
    );

  assert.equal(
    first,
    buildMachineReportDeduplicationId(
      "uid-a",
      REQUEST_ID,
    ),
  );

  assert.notEqual(
    first,
    buildMachineReportDeduplicationId(
      "uid-b",
      REQUEST_ID,
    ),
  );
});

test("report ID is deterministic and request scoped", () => {
  const first =
    buildMachineReportId(
      "uid-a",
      REQUEST_ID,
    );

  assert.match(first, /^r_[0-9a-f]{30}$/);

  assert.equal(
    first,
    buildMachineReportId(
      "uid-a",
      REQUEST_ID,
    ),
  );

  assert.notEqual(
    first,
    buildMachineReportId(
      "uid-a",
      "22222222-2222-4222-8222-222222222222",
    ),
  );
});

test("stored result is parsed strictly", () => {
  assert.deepEqual(
    parseStoredMachineReportResult({
      machineId: "machine_v2_station_east",
      reportId:
        "r_0123456789abcdef0123456789abcd",
      submitted: true,
    }),
    {
      machineId: "machine_v2_station_east",
      reportId:
        "r_0123456789abcdef0123456789abcd",
      submitted: true,
    },
  );

  assert.throws(
    () => parseStoredMachineReportResult({
      machineId: "machine_v2_station_east",
      reportId: "bad",
      submitted: true,
    }),
    SubmitMachineReportValidationError,
  );
});
