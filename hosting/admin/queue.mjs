const allowedSources = new Set(["report", "correction"]);
const allowedStatuses = new Set(["new", "inReview", "resolutionPending"]);

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

function parseItem(value) {
  if (!isRecord(value) || !allowedSources.has(value.source) || !allowedStatuses.has(value.status)) return null;
  const id = identifier(value.id);
  const target = parseTarget(value.target);
  if (!id || !target) return null;
  const categoryOrReason = typeof value.categoryOrReason === "string" && value.categoryOrReason.trim().length > 0 ? value.categoryOrReason.trim() : null;
  return {source: value.source, id, target, categoryOrReason, createdAt: value.createdAt, status: value.status};
}

export function parseQueueResponse(value) {
  if (!isRecord(value) || !Array.isArray(value.items) || !(value.nextCursor === null || (typeof value.nextCursor === "string" && value.nextCursor.length > 0))) {
    throw new Error("invalid-queue-response");
  }
  const items = value.items.map(parseItem).filter((item) => item !== null);
  if (value.items.length > 0 && items.length === 0) throw new Error("invalid-queue-response");
  return {items, nextCursor: value.nextCursor};
}

export function queueItemKey(item) {
  return `${item.source}:${item.id}`;
}

export function mergeQueueItems(existing, incoming, reset) {
  const merged = reset ? [] : [...existing];
  const keys = new Set(merged.map(queueItemKey));
  for (const item of incoming) {
    const key = queueItemKey(item);
    if (!keys.has(key)) {
      keys.add(key);
      merged.push(item);
    }
  }
  return merged;
}

export function sourceLabel(source) {
  return source === "report" ? "通報" : "修正提案";
}

export function statusLabel(status) {
  return {new: "未対応", inReview: "確認中", resolutionPending: "処理中"}[status];
}

export function targetPresentation(target) {
  switch (target.targetType) {
    case "machine": return {label: "自販機", identifier: target.machineId};
    case "product": return {label: "商品", identifier: `${target.machineId} / ${target.productId}`};
    case "photo": return {label: "写真", identifier: `${target.machineId} / ${target.photoId}`};
    case "user": return {label: "ユーザー", identifier: "非公開"};
  }
}

export function formatCreatedAt(value) {
  let milliseconds = Number.NaN;
  if (isRecord(value)) {
    const seconds = Number.isFinite(value.seconds) ? value.seconds : value._seconds;
    const nanoseconds = Number.isFinite(value.nanoseconds) ? value.nanoseconds : value._nanoseconds;
    if (Number.isFinite(seconds)) milliseconds = (seconds * 1000) + ((Number.isFinite(nanoseconds) ? nanoseconds : 0) / 1000000);
  }
  const date = new Date(milliseconds);
  if (!Number.isFinite(date.getTime())) return "日時不明";
  return new Intl.DateTimeFormat("ja-JP", {dateStyle: "medium", timeStyle: "short"}).format(date);
}
