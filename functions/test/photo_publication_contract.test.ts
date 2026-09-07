import assert from "node:assert/strict";
import test from "node:test";
import {buildAddedPhotoId} from "../src/add_vending_machine_photo_core";
import {
  buildPhotoPublicationMetadata,
  writePhotoPublicationMetadata,
} from "../src/photo_publication_contract";
import {
  buildFormalPhotoStoragePath,
  buildPhotoRegistrationIds,
  saveFormalPhoto,
} from "../src/photo_recognition/photo_registration_finalization";

const uid = "actor-secret-user";
const machineId = "machine_v2_station_east";
const photoId = "p_0123456789abcdef0123456789abcd";
const uploadId = "123e4567-e89b-42d3-a456-426614174001";
const requestId = "123e4567-e89b-42d3-a456-426614174000";

function metadata(isPrimary = true) {
  return buildPhotoPublicationMetadata({
    machineId,
    photoId,
    uploadedBy: uid,
    uploadedAt: "time",
    recognitionProvider: "vertex",
    storagePath: buildFormalPhotoStoragePath(machineId, photoId),
    isPrimary,
  });
}

test("create-machine and add-photo share the exact public/private photo contract", () => {
  const create = metadata(true);
  const add = metadata(false);
  assert.deepEqual(Object.keys(create.publicData).sort(), ["createdAt", "status"]);
  assert.deepEqual(Object.keys(add.publicData).sort(), ["createdAt", "status"]);
  for (const forbidden of ["uploadedBy", "uploadedAt", "recognitionStatus", "recognitionProvider", "storagePath", "thumbnailPath", "primary", "actorUid", "uid"]) {
    assert.equal(forbidden in create.publicData, false);
    assert.equal(forbidden in add.publicData, false);
  }
  assert.equal(create.privateData.uploadedBy, uid);
  assert.equal(create.privateData.recognitionProvider, "vertex");
  assert.equal(create.privateData.isPrimary, true);
  assert.equal(add.privateData.isPrimary, false);
});

test("formal storage path is exact and cannot be replaced by a temporary path", () => {
  const formalPath = buildFormalPhotoStoragePath(machineId, photoId);
  assert.equal(formalPath, `vending_machines/${machineId}/${photoId}/original.jpg`);
  assert.equal(formalPath.includes(uid), false);
  assert.equal(formalPath.includes("machine_uploads/"), false);
  assert.throws(() => buildPhotoPublicationMetadata({
    machineId, photoId, uploadedBy: uid, uploadedAt: "time", recognitionProvider: "vertex",
    storagePath: `machine_uploads/${uid}/${uploadId}/original.jpg`, isPrimary: true,
  }));
});

test("photo identifiers are retry-safe and do not expose the UID", () => {
  const createFirst = buildPhotoRegistrationIds(uid, requestId, uploadId);
  const createReplay = buildPhotoRegistrationIds(uid, requestId, uploadId);
  const addFirst = buildAddedPhotoId(uid, machineId, uploadId);
  const addReplay = buildAddedPhotoId(uid, machineId, uploadId);
  assert.deepEqual(createFirst, createReplay);
  assert.equal(addFirst, addReplay);
  for (const id of [createFirst.photoId, addFirst]) {
    assert.match(id, /^p_[0-9a-f]{30}$/);
    assert.equal(id.includes(uid), false);
  }
});

test("metadata writer stages private data before public data", () => {
  const writes: Array<{reference: string; data: Readonly<Record<string, unknown>>}> = [];
  writePhotoPublicationMetadata({
    create(reference, data) { writes.push({reference: reference as string, data}); },
  }, "public-photo", "private-photo", metadata());
  assert.deepEqual(writes.map((write) => write.reference), ["private-photo", "public-photo"]);
  assert.deepEqual(Object.keys(writes[1]!.data).sort(), ["createdAt", "status"]);
});

test("private write failure prevents public metadata staging", () => {
  const writes: string[] = [];
  assert.throws(() => writePhotoPublicationMetadata({
    create(reference) {
      writes.push(reference as string);
      if (reference === "private-photo") throw new Error("private failed");
    },
  }, "public-photo", "private-photo", metadata()), /private failed/);
  assert.deepEqual(writes, ["private-photo"]);
});

test("public write failure leaves no committed public-facing state in the transaction model", () => {
  const staged: string[] = [];
  let committed: string[] = [];
  assert.throws(() => {
    writePhotoPublicationMetadata({
      create(reference) {
        staged.push(reference as string);
        if (reference === "public-photo") throw new Error("public failed");
      },
    }, "public-photo", "private-photo", metadata());
    committed = [...staged];
  }, /public failed/);
  assert.deepEqual(committed, []);
  assert.deepEqual(staged, ["private-photo", "public-photo"]);
});

test("formal storage failure is surfaced before photo metadata can be published", async () => {
  const paths: string[] = [];
  const bucket = {
    file(path: string) {
      paths.push(path);
      return {
        async getMetadata() { return [{}] as const; },
        async download() { return [Buffer.alloc(0)] as [Buffer]; },
        async save() { throw new Error("storage failure"); },
        async delete() { return undefined; },
      };
    },
  };
  await assert.rejects(
    () => saveFormalPhoto(bucket, buildFormalPhotoStoragePath(machineId, photoId), {
      objectPath: `machine_uploads/${uid}/${uploadId}/original.jpg`,
      bytes: Buffer.from([1]), contentType: "image/jpeg",
    }),
    {code: "internal"},
  );
  assert.deepEqual(paths, [buildFormalPhotoStoragePath(machineId, photoId)]);
});
