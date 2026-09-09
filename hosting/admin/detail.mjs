const actionCandidates = {
  machine: ["underReview", "hidden", "removed", "merged"],
  product: ["inactive"],
  user: ["restricted", "suspended", "active"],
  photo: ["hidden", "deleted"],
};

const actionLabels = {
  underReview: "確認中にする", hidden: "非表示にする", removed: "削除済みにする",
  merged: "統合済みにする", inactive: "無効にする", restricted: "制限する",
  suspended: "停止する", active: "有効に戻す", deleted: "完全に削除する",
};

function isRecord(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function identifier(value) {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function parseTarget(value) {
  if (!isRecord(value)) return null;
  const machineId = identifier(value.machineId);
  const photoId = identifier(value.photoId);
  const productId = identifier(value.productId);
  const targetUserId = identifier(value.targetUserId);
  if (value.targetType === "machine" && machineId && !photoId && !productId && !targetUserId) return {targetType: "machine", machineId};
  if (value.targetType === "photo" && machineId && photoId && !productId && !targetUserId) return {targetType: "photo", machineId, photoId};
  if (value.targetType === "product" && machineId && productId && !photoId && !targetUserId) return {targetType: "product", machineId, productId};
  if (value.targetType === "user" && targetUserId && !machineId && !photoId && !productId) return {targetType: "user", targetUserId};
  return null;
}

export function parseTargetDetail(value) {
  if (!isRecord(value)) throw new Error("invalid-target-detail");
  const target = parseTarget(value.target);
  const currentStatus = identifier(value.currentStatus);
  const publicStatus = value.publicStatus;
  const hasPrivateMetadata = value.hasPrivateMetadata;
  const indexIsActive = value.indexIsActive;
  if (!target || !currentStatus || !(publicStatus === null || publicStatus === "active" || publicStatus === "inactive") ||
      typeof hasPrivateMetadata !== "boolean" || !(indexIsActive === null || typeof indexIsActive === "boolean")) {
    throw new Error("invalid-target-detail");
  }
  return {target, currentStatus, publicStatus, hasPrivateMetadata, indexIsActive};
}

export function actionsForTarget(targetType) {
  return [...(actionCandidates[targetType] ?? [])];
}

export function targetKey(target) {
  switch (target.targetType) {
    case "machine": return `machine:${target.machineId}`;
    case "photo": return `photo:${target.machineId}:${target.photoId}`;
    case "product": return `product:${target.machineId}:${target.productId}`;
    case "user": return `user:${target.targetUserId}`;
  }
}

export function actionLabel(action) {
  return actionLabels[action];
}

export function validateReason(value) {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized.length >= 1 && normalized.length <= 500 ? normalized : null;
}

export function parseModerationPlan(value) {
  if (!isRecord(value) || typeof value.allowed !== "boolean" || !Object.hasOwn(actionCandidates, value.targetType) ||
      !actionCandidates[value.targetType].includes(value.action) || !identifier(value.currentStatus) ||
      !(value.nextStatus === null || identifier(value.nextStatus)) || typeof value.requiresStorageDelete !== "boolean" ||
      typeof value.affectsIndex !== "boolean" || typeof value.requiresPrivateAudit !== "boolean") {
    throw new Error("invalid-moderation-plan");
  }
  return {
    allowed: value.allowed, targetType: value.targetType, action: value.action,
    currentStatus: value.currentStatus.trim(), nextStatus: value.nextStatus === null ? null : value.nextStatus.trim(),
    requiresStorageDelete: value.requiresStorageDelete, affectsIndex: value.affectsIndex,
    requiresPrivateAudit: value.requiresPrivateAudit,
  };
}
