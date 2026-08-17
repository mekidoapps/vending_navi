import assert from "node:assert/strict";
import test from "node:test";

import {
  ADD_VENDING_MACHINE_PHOTO_OPERATION,
  buildAddedPhotoId,
  buildAddVendingMachinePhotoDedupeId,
  parseAddVendingMachinePhotoInput,
  parseStoredAddVendingMachinePhotoResult,
} from "../src/add_vending_machine_photo_core";

const REQUEST_ID = "123e4567-e89b-42d3-a456-426614174000";

const UPLOAD_ID = "f47ac10b-58cc-4372-a567-0e02b2c3d479";

test("valid add-photo request is parsed", () => {
  const parsed = parseAddVendingMachinePhotoInput({
    requestId: REQUEST_ID,
    machineId: "machine-001",
    temporaryPhotoUploadId: UPLOAD_ID,
  });

  assert.deepEqual(parsed, {
    requestId: REQUEST_ID,
    machineId: "machine-001",
    temporaryPhotoUploadId: UPLOAD_ID,
  });
});

test("unknown request fields are rejected", () => {
  assert.throws(
    () =>
      parseAddVendingMachinePhotoInput({
        requestId: REQUEST_ID,
        machineId: "machine-001",
        temporaryPhotoUploadId: UPLOAD_ID,
        storagePath: "forged/path.jpg",
      }),
    TypeError,
  );
});

test("missing fields are rejected", () => {
  assert.throws(
    () =>
      parseAddVendingMachinePhotoInput({
        requestId: REQUEST_ID,
        machineId: "machine-001",
      }),
    TypeError,
  );
});

test("request and upload IDs require UUID v4", () => {
  assert.throws(
    () =>
      parseAddVendingMachinePhotoInput({
        requestId: "123e4567-e89b-12d3-a456-426614174000",
        machineId: "machine-001",
        temporaryPhotoUploadId: UPLOAD_ID,
      }),
    TypeError,
  );

  assert.throws(
    () =>
      parseAddVendingMachinePhotoInput({
        requestId: REQUEST_ID,
        machineId: "machine-001",
        temporaryPhotoUploadId: "../other-user",
      }),
    TypeError,
  );
});

test("machine ID rejects paths and empty values", () => {
  for (const machineId of ["", " vending/machine ", "../machine"]) {
    assert.throws(
      () =>
        parseAddVendingMachinePhotoInput({
          requestId: REQUEST_ID,
          machineId,
          temporaryPhotoUploadId: UPLOAD_ID,
        }),
      TypeError,
    );
  }
});

test("dedupe ID is deterministic and operation scoped", () => {
  const first = buildAddVendingMachinePhotoDedupeId("user-1", REQUEST_ID);

  const replay = buildAddVendingMachinePhotoDedupeId("user-1", REQUEST_ID);

  const otherUser = buildAddVendingMachinePhotoDedupeId("user-2", REQUEST_ID);

  assert.equal(first, replay);
  assert.notEqual(first, otherUser);

  assert.equal(ADD_VENDING_MACHINE_PHOTO_OPERATION, "addVendingMachinePhoto");
});

test("photo ID is deterministic for the recognized upload", () => {
  const first = buildAddedPhotoId("user-1", "machine-001", UPLOAD_ID);

  const replay = buildAddedPhotoId("user-1", "machine-001", UPLOAD_ID);

  const otherUpload = buildAddedPhotoId(
    "user-1",
    "machine-001",
    "223e4567-e89b-42d3-a456-426614174000",
  );

  const otherMachine = buildAddedPhotoId("user-1", "machine-002", UPLOAD_ID);

  assert.match(first, /^p_[0-9a-f]{30}$/);
  assert.equal(first, replay);
  assert.notEqual(first, otherUpload);
  assert.notEqual(first, otherMachine);
});

test("stored result is strictly parsed", () => {
  const result = parseStoredAddVendingMachinePhotoResult({
    machineId: "machine-001",
    photoId: "p_0123456789abcdef0123456789abcd",
    added: true,
    primaryPhotoChanged: false,
  });

  assert.deepEqual(result, {
    machineId: "machine-001",
    photoId: "p_0123456789abcdef0123456789abcd",
    added: true,
    primaryPhotoChanged: false,
  });

  assert.throws(
    () =>
      parseStoredAddVendingMachinePhotoResult({
        machineId: "machine-001",
        photoId: "invalid",
        added: true,
        primaryPhotoChanged: false,
      }),
    TypeError,
  );
});
