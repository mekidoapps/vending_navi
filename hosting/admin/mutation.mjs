const uuidV4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const resolutions = new Set(["noAction", "rejected"]);

function isRecord(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function text(value) {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

export function queueRefFromItem(item) {
  return {sourceType: item.source, itemId: item.id};
}

export function buildMutationRequest(operation) {
  const base = {queueRef: operation.queueRef, requestId: operation.requestId};
  if (operation.operationType === "mark") return base;
  if (operation.operationType === "resolve") return {...base, resolution: operation.resolution, reason: operation.reason};
  return {...base, action: operation.action, reason: operation.reason};
}

export function createPendingOperation({item, operationType, action, resolution, reason, requestId}) {
  const queueRef = queueRefFromItem(item);
  const normalizedReason = typeof reason === "string" ? reason.trim() : null;
  if (!uuidV4.test(requestId) || (operationType !== "mark" && operationType !== "resolve" && operationType !== "apply")) throw new Error("invalid-pending-operation");
  if (operationType === "mark") return {queueRef, operationType, requestId, state: "retryable"};
  if (!normalizedReason || normalizedReason.length > 500) throw new Error("invalid-pending-operation");
  if (operationType === "resolve" && resolutions.has(resolution)) return {queueRef, operationType, resolution, reason: normalizedReason, requestId, state: "retryable"};
  if (operationType === "apply" && text(action)) return {queueRef, operationType, action, reason: normalizedReason, requestId, state: "retryable"};
  throw new Error("invalid-pending-operation");
}

export function encodePendingOperation(operation) {
  return JSON.stringify(operation);
}

export function decodePendingOperation(value) {
  if (typeof value !== "string") return null;
  try {
    const parsed = JSON.parse(value);
    if (!isRecord(parsed) || parsed.state !== "retryable" || !isRecord(parsed.queueRef) ||
        (parsed.queueRef.sourceType !== "report" && parsed.queueRef.sourceType !== "correction") || !text(parsed.queueRef.itemId) ||
        !uuidV4.test(parsed.requestId) || Object.keys(parsed.queueRef).some((key) => key !== "sourceType" && key !== "itemId")) return null;
    const item = {source: parsed.queueRef.sourceType, id: parsed.queueRef.itemId};
    const normalized = createPendingOperation({item, operationType: parsed.operationType, action: parsed.action, resolution: parsed.resolution, reason: parsed.reason, requestId: parsed.requestId});
    const actualKeys = Object.keys(parsed).sort();
    const safeKeys = Object.keys(normalized).sort();
    if (actualKeys.length !== safeKeys.length || actualKeys.some((key, index) => key !== safeKeys[index])) return null;
    return normalized;
  } catch {
    return null;
  }
}

export function parseMutationResult(value, operation) {
  if (!isRecord(value) || value.sourceType !== operation.queueRef.sourceType || value.itemId !== operation.queueRef.itemId) throw new Error("invalid-mutation-result");
  if (operation.operationType === "mark" && value.status === "inReview" && typeof value.changed === "boolean") return {status: "inReview"};
  if (operation.operationType === "resolve" && value.status === "resolved" && value.resolution === operation.resolution) return {status: "resolved"};
  if (operation.operationType === "apply" && value.ok === true && value.status === "resolved" && value.resolution === "actionTaken" && value.action === operation.action) return {status: "resolved"};
  throw new Error("invalid-mutation-result");
}

export function operationMatchesItem(operation, item) {
  return operation.queueRef.sourceType === item.source && operation.queueRef.itemId === item.id;
}
