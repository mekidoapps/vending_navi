import assert from "node:assert/strict";
import test from "node:test";

import {
  buildFormalPhotoStoragePath,
  buildPhotoRegistrationIds,
} from "../src/photo_recognition/photo_registration_finalization";

const REQUEST_ID = "123e4567-e89b-42d3-a456-426614174000";
const UPLOAD_ID = "123e4567-e89b-42d3-a456-426614174001";

test("photo registration IDs are deterministic and scoped by uid", () => {
  const first = buildPhotoRegistrationIds("uid-a", REQUEST_ID, UPLOAD_ID);
  const replay = buildPhotoRegistrationIds("uid-a", REQUEST_ID, UPLOAD_ID);
  const otherUser = buildPhotoRegistrationIds(
    "uid-b",
    REQUEST_ID,
    UPLOAD_ID,
  );

  assert.deepEqual(first, replay);
  assert.notDeepEqual(first, otherUser);
  assert.match(first.machineId, /^p_[0-9a-f]{30}$/);
  assert.match(first.photoId, /^p_[0-9a-f]{30}$/);
});

test("formal photo path follows the fixed v2 storage contract", () => {
  assert.equal(
    buildFormalPhotoStoragePath("machine-a", "photo-a"),
    "vending_machines/machine-a/photo-a/original.jpg",
  );
});

test("different upload IDs keep the same request machine ID but reserve a different photo", () => {
  const first = buildPhotoRegistrationIds("uid-a", REQUEST_ID, UPLOAD_ID);
  const otherPhoto = buildPhotoRegistrationIds(
    "uid-a",
    REQUEST_ID,
    "123e4567-e89b-42d3-a456-426614174002",
  );

  assert.equal(first.machineId, otherPhoto.machineId);
  assert.notEqual(first.photoId, otherPhoto.photoId);
});
