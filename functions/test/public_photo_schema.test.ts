import assert from "node:assert/strict";
import test from "node:test";
import {auditLogEntry, formalPhotoPath, inspectPublicPhoto} from "../src/public_photo_schema";

const machineId = "machine_001";
const photoId = "p_0123456789abcdef0123456789abcd";

test("public photo schema accepts status and createdAt only", () => {
  assert.equal(inspectPublicPhoto(machineId, photoId, {status: "active", createdAt: "server-time"}).safe, true);
});

test("public photo schema exposes field names but never field values", () => {
  const result = inspectPublicPhoto(machineId, photoId, {
    status: "active", createdAt: "server-time", uploadedBy: "uid-secret", storagePath: "private/path",
  });
  assert.deepEqual([...result.fields].sort(), ["storagePath", "uploadedBy"]);
  assert.equal(JSON.stringify(result).includes("uid-secret"), false);
  assert.equal(JSON.stringify(result).includes("private/path"), false);
});

test("invalid status and formal path mismatch are reported without values", () => {
  const result = inspectPublicPhoto(machineId, photoId, {status: "", storagePath: "elsewhere"});
  assert.equal(result.invalid, true);
  assert.equal(result.formalPathMismatch, true);
  assert.equal(formalPhotoPath(machineId, photoId), `vending_machines/${machineId}/${photoId}/original.jpg`);
});

test("matching formal path is not treated as a path mismatch", () => {
  const result = inspectPublicPhoto(machineId, photoId, {
    status: "active", createdAt: new Date(), storagePath: formalPhotoPath(machineId, photoId),
  });
  assert.equal(result.formalPathMismatch, false);
  assert.deepEqual(result.fields, ["storagePath"]);
});

test("public photo schema rejects every private and unknown field", () => {
  for (const field of ["uploadedBy", "uploadedAt", "recognitionStatus", "recognitionProvider", "storagePath", "thumbnailPath", "primary", "unknownField"]) {
    const result = inspectPublicPhoto(machineId, photoId, {
      status: "active", createdAt: new Date(), [field]: "private-value",
    });
    assert.equal(result.safe, false, field);
    assert.deepEqual(result.fields, [field]);
  }
  const multiple = inspectPublicPhoto(machineId, photoId, {
    status: "active", createdAt: new Date(), uploadedBy: "uid-secret", email: "person@example.test",
  });
  assert.deepEqual([...multiple.fields].sort(), ["email", "uploadedBy"]);
});

test("public photo schema requires an allowed status and valid createdAt", () => {
  for (const data of [
    {createdAt: new Date()},
    {status: "pending", createdAt: new Date()},
    {status: "active"},
    {status: "active", createdAt: ""},
    {status: "active", createdAt: {}},
  ]) {
    assert.equal(inspectPublicPhoto(machineId, photoId, data).invalid, true);
  }
});

test("audit entry includes only a document path and safe diagnostic names", () => {
  const result = inspectPublicPhoto(machineId, photoId, {
    status: "active", createdAt: new Date(), uploadedBy: "uid-secret", email: "person@example.test",
    storagePath: "machine_uploads/uid-secret/private.jpg",
  });
  const entry = JSON.stringify(auditLogEntry(`vending_machines/${machineId}/photos/${photoId}`, result));
  assert.equal(entry.includes("uid-secret"), false);
  assert.equal(entry.includes("person@example.test"), false);
  assert.equal(entry.includes("machine_uploads/"), false);
  assert.equal(entry.includes("uploadedBy"), true);
  assert.equal(entry.includes("storagePath"), true);
});
