import assert from "node:assert/strict";
import test from "node:test";
import {
  applyPublicPhotoMigration,
  mergePrivateMetadata,
  planPublicPhotoMigration,
  type PublicPhotoMigrationAdapter,
} from "../src/public_photo_migration";

const machineId = "machine_001";
const photoId = "p_0123456789abcdef0123456789abcd";
const safePhoto = {status: "active", createdAt: new Date("2026-01-01T00:00:00Z")};

function adapter(existing?: Record<string, unknown>, fail?: "write" | "cleanup") {
  const calls: string[] = [];
  let privateData = existing;
  const value: PublicPhotoMigrationAdapter = {
    async readPrivateMetadata() { calls.push("read"); return privateData; },
    async writePrivateMetadata(metadata) {
      calls.push("write");
      if (fail === "write") throw new Error("write failed");
      privateData = {...metadata};
    },
    async cleanupPublicFields() {
      calls.push("cleanup");
      if (fail === "cleanup") throw new Error("cleanup failed");
    },
  };
  return {value, calls, privateData: () => privateData};
}

test("migration planning keeps already-safe documents unchanged", () => {
  assert.deepEqual(planPublicPhotoMigration(machineId, photoId, safePhoto), {kind: "already-safe"});
});

test("migration planning moves unsafe metadata while retaining public fields", () => {
  const plan = planPublicPhotoMigration(machineId, photoId, {
    ...safePhoto, uploadedBy: "uid-secret", recognitionProvider: "provider", thumbnailPath: "private/path",
  });
  assert.equal(plan.kind, "migrate");
  if (plan.kind !== "migrate") return;
  assert.deepEqual([...plan.publicCleanupFields].sort(), ["recognitionProvider", "thumbnailPath", "uploadedBy"]);
  assert.deepEqual(plan.privateMetadata, {
    uploadedBy: "uid-secret", recognitionProvider: "provider", thumbnailPath: "private/path",
  });
  assert.equal("status" in plan.privateMetadata, false);
  assert.equal("createdAt" in plan.privateMetadata, false);
});

test("invalid public fields and formal path mismatch require manual review", () => {
  for (const data of [
    {createdAt: new Date(), uploadedBy: "uid-secret"},
    {status: "pending", createdAt: new Date(), uploadedBy: "uid-secret"},
    {status: "active", uploadedBy: "uid-secret"},
    {status: "active", createdAt: {}, uploadedBy: "uid-secret"},
  ]) {
    assert.deepEqual(planPublicPhotoMigration(machineId, photoId, data), {
      kind: "manual-review", reason: "invalid-public-fields",
    });
  }
  assert.deepEqual(planPublicPhotoMigration(machineId, photoId, {
    ...safePhoto, storagePath: "vending_machines/other/photo/original.jpg",
  }), {kind: "manual-review", reason: "formal-path-mismatch"});
});

test("dry run creates no side effects", async () => {
  const plan = planPublicPhotoMigration(machineId, photoId, {...safePhoto, uploadedBy: "uid-secret"});
  const fake = adapter();
  assert.equal(await applyPublicPhotoMigration(plan, fake.value, true), "planned");
  assert.deepEqual(fake.calls, []);
});

test("execute writes merged private metadata before public cleanup", async () => {
  const plan = planPublicPhotoMigration(machineId, photoId, {...safePhoto, uploadedBy: "uid-secret"});
  const fake = adapter({existingKey: "preserved", uploadedBy: "existing-actor"});
  assert.equal(await applyPublicPhotoMigration(plan, fake.value, false), "migrated");
  assert.deepEqual(fake.calls, ["read", "write", "cleanup"]);
  assert.deepEqual(fake.privateData(), {existingKey: "preserved", uploadedBy: "existing-actor"});
});

test("private write failure prevents public cleanup and cleanup failure retains private metadata", async () => {
  const plan = planPublicPhotoMigration(machineId, photoId, {...safePhoto, uploadedBy: "uid-secret"});
  const writeFailure = adapter(undefined, "write");
  await assert.rejects(() => applyPublicPhotoMigration(plan, writeFailure.value, false), /write failed/);
  assert.deepEqual(writeFailure.calls, ["read", "write"]);

  const cleanupFailure = adapter(undefined, "cleanup");
  await assert.rejects(() => applyPublicPhotoMigration(plan, cleanupFailure.value, false), /cleanup failed/);
  assert.deepEqual(cleanupFailure.calls, ["read", "write", "cleanup"]);
  assert.deepEqual(cleanupFailure.privateData(), {uploadedBy: "uid-secret"});
});

test("manual review and already-safe plans are idempotent no-ops", async () => {
  const fake = adapter();
  const safePlan = planPublicPhotoMigration(machineId, photoId, safePhoto);
  const reviewPlan = planPublicPhotoMigration(machineId, photoId, {status: "active", storagePath: "other"});
  assert.equal(await applyPublicPhotoMigration(safePlan, fake.value, false), "already-safe");
  assert.equal(await applyPublicPhotoMigration(reviewPlan, fake.value, false), "manual-review");
  assert.deepEqual(fake.calls, []);
});

test("a completed migration is idempotent on its cleaned public document", async () => {
  const publicData: Record<string, unknown> = {...safePhoto, uploadedBy: "uid-secret"};
  const fake = adapter();
  const firstPlan = planPublicPhotoMigration(machineId, photoId, publicData);
  assert.equal(await applyPublicPhotoMigration(firstPlan, fake.value, false), "migrated");
  if (firstPlan.kind === "migrate") {
    for (const field of firstPlan.publicCleanupFields) delete publicData[field];
  }
  const secondPlan = planPublicPhotoMigration(machineId, photoId, publicData);
  assert.equal(await applyPublicPhotoMigration(secondPlan, fake.value, false), "already-safe");
  assert.deepEqual(fake.calls, ["read", "write", "cleanup"]);
});

test("private metadata merge preserves existing values", () => {
  assert.deepEqual(mergePrivateMetadata({uploadedBy: "existing", keep: true}, {uploadedBy: "incoming", newKey: "new"}), {
    uploadedBy: "existing", keep: true, newKey: "new",
  });
});
