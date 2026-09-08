import assert from "node:assert/strict";
import test from "node:test";
import {
  ModerationValidationError,
  assertModeratorAuthorized,
  buildModerationQueue,
  buildPrivateModerationAudit,
  parseModerationAction,
  parseModerationTarget,
  planModerationAction,
  toPublicModerationAudit,
} from "../src/moderation_core";

const machineId = "machine_v2_station_east";
const photoId = "p_0123456789abcdef0123456789abcd";
const productId = "product_tea_green";

function expectCode(callback: () => unknown, code: string): void {
  assert.throws(callback, (error: unknown) => error instanceof ModerationValidationError && error.code === code);
}

test("moderator authorization rejects anonymous, normal, restricted, and suspended users", () => {
  expectCode(() => assertModeratorAuthorized({uid: null, customClaims: {admin: true}, accountStatus: "active"}), "unauthenticated");
  expectCode(() => assertModeratorAuthorized({uid: "user", customClaims: {}, accountStatus: "active"}), "admin-required");
  expectCode(() => assertModeratorAuthorized({uid: "admin", customClaims: {admin: true}, accountStatus: "restricted"}), "account-restricted");
  expectCode(() => assertModeratorAuthorized({uid: "admin", customClaims: {admin: true}, accountStatus: "suspended"}), "account-restricted");
  assert.doesNotThrow(() => assertModeratorAuthorized({uid: "admin", customClaims: {admin: true}, accountStatus: "active"}));
});

test("moderation targets require an exact valid identifier combination", () => {
  assert.deepEqual(parseModerationTarget({targetType: "machine", machineId}), {targetType: "machine", machineId});
  assert.deepEqual(parseModerationTarget({targetType: "photo", machineId, photoId}), {targetType: "photo", machineId, photoId});
  assert.deepEqual(parseModerationTarget({targetType: "product", machineId, productId}), {targetType: "product", machineId, productId});
  assert.deepEqual(parseModerationTarget({targetType: "user", targetUserId: "user_target"}), {targetType: "user", targetUserId: "user_target"});
  expectCode(() => parseModerationTarget({targetType: "photo", machineId}), "invalid-target");
  expectCode(() => parseModerationTarget({targetType: "product", machineId, productId, photoId}), "invalid-target");
  expectCode(() => parseModerationTarget({targetType: "user", targetUserId: "user_target", machineId}), "invalid-target");
});

test("queue extracts unresolved report and correction targets, orders oldest first, and ignores malformed data", () => {
  const queue = buildModerationQueue([
    {source: "report", id: "report_photo", targetType: "photo", machineId, photoId, category: "inappropriatePhoto", status: "new", createdAt: 20},
    {source: "correction", id: "correction_machine", machineId, message: "名前の修正", status: "inReview", createdAt: 10},
    {source: "report", id: "closed", targetType: "machine", machineId, status: "resolved", createdAt: 1},
    {source: "report", id: "invalid", targetType: "product", machineId, status: "new", createdAt: 2},
    {source: "report", id: "legacy_text", targetType: "text", machineId, category: "inappropriateText", status: "new", createdAt: 30},
  ]);
  assert.deepEqual(queue.map((item) => [item.id, item.target.targetType]), [
    ["correction_machine", "machine"], ["report_photo", "photo"], ["legacy_text", "machine"],
  ]);
  assert.equal(queue[0]?.categoryOrReason, "名前の修正");
});

test("planning is fail-closed and preserves current public photo and product contracts", () => {
  const machine = parseModerationTarget({targetType: "machine", machineId});
  const photo = parseModerationTarget({targetType: "photo", machineId, photoId});
  const product = parseModerationTarget({targetType: "product", machineId, productId});
  const user = parseModerationTarget({targetType: "user", targetUserId: "user_target"});
  assert.deepEqual(planModerationAction(machine, "underReview", "active").nextStatus, "underReview");
  assert.deepEqual(planModerationAction(machine, "hidden", "underReview").nextStatus, "hidden");
  assert.equal(planModerationAction(machine, "removed", "active").allowed, false);
  assert.deepEqual(planModerationAction(photo, "hidden", "active").publicStatus, "inactive");
  assert.equal(planModerationAction(photo, "deleted", "active").deleteFormalStorage, true);
  assert.equal(planModerationAction(photo, "underReview", "active").publicStatus, "active");
  assert.equal(planModerationAction(product, "inactive", "active").affectsMachineProductIndex, true);
  assert.equal(planModerationAction(product, "inactive", "inactive").allowed, false);
  assert.equal(planModerationAction(user, "restricted", "active").nextStatus, "restricted");
  assert.equal(planModerationAction(user, "active", "suspended").nextStatus, "active");
  expectCode(() => parseModerationAction("erase"), "invalid-action");
});

test("public audit projection never returns moderator identity", () => {
  const record = buildPrivateModerationAudit({
    action: "hidden",
    target: parseModerationTarget({targetType: "photo", machineId, photoId}),
    previousStatus: "active",
    nextStatus: "hidden",
    reason: "inappropriatePhoto",
    moderatorUid: "admin-private-uid",
  });
  const publicRecord = toPublicModerationAudit(record);
  assert.equal("moderatorUid" in publicRecord, false);
  assert.equal(JSON.stringify(publicRecord).includes("admin-private-uid"), false);
});
