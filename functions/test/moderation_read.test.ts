import assert from "node:assert/strict";
import test from "node:test";

import {
  type ModerationReadStore,
  getModerationTargetForCaller,
  listModerationQueueForCaller,
  planModerationActionForCaller,
} from "../src/moderation_read";

const machineId = "machine_v2_station_east";
const photoId = "p_0123456789abcdef0123456789abcd";
const productId = "product_tea_green";
const admin = {uid: "admin", customClaims: {admin: true}};

class ReadOnlyStore implements ModerationReadStore {
  writes = 0;
  deletes = 0;
  authMutations = 0;
  accountStatus: unknown = "active";
  queue: readonly unknown[] = [];
  machine: unknown | null = {status: "active", schemaVersion: 2};
  publicPhoto: unknown | null = {status: "active"};
  privatePhoto: unknown | null = {uploadedBy: "private"};
  product: unknown | null = {isActive: true};
  index: unknown | null = {isActive: true};
  user: unknown | null = {accountStatus: "active"};

  async getAccountStatus(_uid: string): Promise<unknown> { return this.accountStatus; }
  async listQueueDocuments(_limit: number): Promise<readonly unknown[]> { return this.queue; }
  async getMachine(_machineId: string): Promise<unknown | null> { return this.machine; }
  async getPublicPhoto(_machineId: string, _photoId: string): Promise<unknown | null> { return this.publicPhoto; }
  async getPrivatePhoto(_machineId: string, _photoId: string): Promise<unknown | null> { return this.privatePhoto; }
  async getMachineProduct(_machineId: string, _productId: string): Promise<unknown | null> { return this.product; }
  async getMachineProductIndex(_machineId: string, _productId: string): Promise<unknown | null> { return this.index; }
  async getUser(_targetUserId: string): Promise<unknown | null> { return this.user; }
}

async function expectCode(action: () => Promise<unknown>, code: string): Promise<void> {
  await assert.rejects(action, (error: unknown) =>
    typeof error === "object" && error !== null && "details" in error &&
    (error as {details?: {appCode?: unknown}}).details?.appCode === code,
  );
}

test("moderation read calls reject guests, normal users, restricted users, and suspended users", async () => {
  const store = new ReadOnlyStore();
  await expectCode(() => listModerationQueueForCaller(store, {uid: "", customClaims: {admin: true}}, {}), "unauthenticated");
  await expectCode(() => listModerationQueueForCaller(store, {uid: "user", customClaims: {}}, {}), "admin-required");
  store.accountStatus = "restricted";
  await expectCode(() => getModerationTargetForCaller(store, admin, {targetType: "machine", machineId}), "account-restricted");
  store.accountStatus = "suspended";
  await expectCode(() => planModerationActionForCaller(store, admin, {target: {targetType: "machine", machineId}, action: "underReview"}), "account-restricted");
});

test("queue merges only unresolved safe entries in stable oldest-first order with opaque pagination", async () => {
  const store = new ReadOnlyStore();
  store.queue = [
    {source: "report", id: "report_2", targetType: "product", machineId, productId, category: "other", status: "new", createdAt: 20, reportedBy: "private"},
    {source: "correction", id: "correction_1", machineId, message: "修正", status: "inReview", createdAt: 10, submittedBy: "private"},
    {source: "report", id: "closed", targetType: "machine", machineId, status: "resolved", createdAt: 1},
    {source: "report", id: "invalid", targetType: "photo", machineId, status: "new", createdAt: 2},
  ];
  const first = await listModerationQueueForCaller(store, admin, {limit: 1});
  assert.deepEqual(first.items.map((item) => item.id), ["correction_1"]);
  assert.notEqual(first.nextCursor, null);
  assert.equal(JSON.stringify(first).includes("private"), false);
  const second = await listModerationQueueForCaller(store, admin, {limit: 1, cursor: first.nextCursor});
  assert.deepEqual(second.items.map((item) => item.id), ["report_2"]);
  await expectCode(() => listModerationQueueForCaller(store, admin, {limit: 101}), "invalid-moderation-queue-limit");
});

test("target reads expose only safe current moderation state for every target type", async () => {
  const store = new ReadOnlyStore();
  const machine = await getModerationTargetForCaller(store, admin, {targetType: "machine", machineId});
  const photo = await getModerationTargetForCaller(store, admin, {targetType: "photo", machineId, photoId});
  const product = await getModerationTargetForCaller(store, admin, {targetType: "product", machineId, productId});
  store.user = {accountStatus: "suspended", email: "private@example.invalid"};
  const user = await getModerationTargetForCaller(store, admin, {targetType: "user", targetUserId: "target_user"});
  assert.equal(machine.currentStatus, "active");
  assert.equal(photo.publicStatus, "active");
  assert.equal(photo.hasPrivateMetadata, true);
  assert.equal(product.indexIsActive, true);
  assert.equal(user.currentStatus, "suspended");
  const output = JSON.stringify([machine, photo, product, user]);
  for (const privateKey of ["uploadedBy", "confirmedBy", "createdBy", "actorUid", "moderatorUid", "email", "displayName", "path"]) assert.equal(output.includes(privateKey), false);
  store.machine = null;
  await expectCode(() => getModerationTargetForCaller(store, admin, {targetType: "machine", machineId}), "moderation-target-not-found");
  await expectCode(() => getModerationTargetForCaller(store, admin, {targetType: "photo", machineId}), "invalid-moderation-target");
});

test("planning returns safe mutation-free plans for machine, photo, product, and user actions", async () => {
  const store = new ReadOnlyStore();
  const machine = await planModerationActionForCaller(store, admin, {target: {targetType: "machine", machineId}, action: "underReview", reason: "ignored"});
  const hiddenPhoto = await planModerationActionForCaller(store, admin, {target: {targetType: "photo", machineId, photoId}, action: "hidden"});
  const deletedPhoto = await planModerationActionForCaller(store, admin, {target: {targetType: "photo", machineId, photoId}, action: "deleted"});
  const product = await planModerationActionForCaller(store, admin, {target: {targetType: "product", machineId, productId}, action: "inactive"});
  store.user = {accountStatus: "active"};
  const user = await planModerationActionForCaller(store, admin, {target: {targetType: "user", targetUserId: "target_user"}, action: "restricted"});
  assert.equal(machine.allowed, true);
  assert.equal(hiddenPhoto.requiresStorageDelete, false);
  assert.equal(deletedPhoto.requiresStorageDelete, true);
  assert.equal(product.affectsIndex, true);
  assert.equal(user.nextStatus, "restricted");
  assert.equal((await planModerationActionForCaller(store, admin, {target: {targetType: "machine", machineId}, action: "removed"})).allowed, false);
  assert.deepEqual([store.writes, store.deletes, store.authMutations], [0, 0, 0]);
});
