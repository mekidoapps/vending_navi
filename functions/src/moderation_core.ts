export type ModerationTarget =
  | {readonly targetType: "machine"; readonly machineId: string}
  | {readonly targetType: "photo"; readonly machineId: string; readonly photoId: string}
  | {readonly targetType: "product"; readonly machineId: string; readonly productId: string}
  | {readonly targetType: "user"; readonly targetUserId: string};

export type ModerationAction =
  | "underReview"
  | "hidden"
  | "removed"
  | "merged"
  | "deleted"
  | "inactive"
  | "restricted"
  | "suspended"
  | "active";

export interface ModeratorAuthorizationInput {
  readonly uid: unknown;
  readonly customClaims: unknown;
  readonly accountStatus: unknown;
}

export interface ModerationQueueItem {
  readonly source: "report" | "correction";
  readonly id: string;
  readonly target: ModerationTarget;
  readonly categoryOrReason: string | null;
  readonly createdAt: unknown;
  readonly status: "new" | "inReview" | "resolutionPending";
}

export interface ModerationPlan {
  readonly allowed: boolean;
  readonly reason: string | null;
  readonly target: ModerationTarget;
  readonly action: ModerationAction;
  readonly previousStatus: string;
  readonly nextStatus: string | null;
  readonly publicStatus: "active" | "inactive" | null;
  readonly affectsMachineProductIndex: boolean;
  readonly deleteFormalStorage: boolean;
}

export interface PrivateModerationAuditRecord {
  readonly action: ModerationAction;
  readonly target: ModerationTarget;
  readonly previousStatus: string;
  readonly nextStatus: string;
  readonly reason: string | null;
  readonly moderatorUid: string;
  readonly timestamp: "serverTimestamp";
}

export interface PublicModerationAuditRecord {
  readonly action: ModerationAction;
  readonly target: ModerationTarget;
  readonly previousStatus: string;
  readonly nextStatus: string;
  readonly reason: string | null;
  readonly timestamp: "serverTimestamp";
}

const restrictedStatuses = new Set(["restricted", "suspended"]);
const machineStatuses = new Set(["active", "underReview", "hidden", "removed", "merged"]);
const photoStatuses = new Set(["active", "inactive"]);
const userStatuses = new Set(["active", "restricted", "suspended"]);

export function assertModeratorAuthorized(input: ModeratorAuthorizationInput): void {
  if (typeof input.uid !== "string" || input.uid.trim().length === 0) {
    throw new ModerationValidationError("unauthenticated");
  }
  if (typeof input.accountStatus === "string" && restrictedStatuses.has(input.accountStatus)) {
    throw new ModerationValidationError("account-restricted");
  }
  if (!isRecord(input.customClaims) || input.customClaims.admin !== true) {
    throw new ModerationValidationError("admin-required");
  }
}

export function parseModerationTarget(value: unknown): ModerationTarget {
  if (!isRecord(value) || typeof value.targetType !== "string") {
    throw new ModerationValidationError("invalid-target");
  }
  const machineId = optionalIdentifier(value.machineId);
  const photoId = optionalIdentifier(value.photoId);
  const productId = optionalIdentifier(value.productId);
  const targetUserId = optionalIdentifier(value.targetUserId);
  switch (value.targetType) {
    case "machine":
      if (machineId !== null && photoId === null && productId === null && targetUserId === null) {
        return {targetType: "machine", machineId};
      }
      break;
    case "photo":
      if (machineId !== null && photoId !== null && productId === null && targetUserId === null) {
        return {targetType: "photo", machineId, photoId};
      }
      break;
    case "product":
      if (machineId !== null && productId !== null && photoId === null && targetUserId === null) {
        return {targetType: "product", machineId, productId};
      }
      break;
    case "user":
      if (targetUserId !== null && machineId === null && photoId === null && productId === null) {
        return {targetType: "user", targetUserId};
      }
      break;
  }
  throw new ModerationValidationError("invalid-target");
}

export function parseModerationAction(value: unknown): ModerationAction {
  if (typeof value !== "string") throw new ModerationValidationError("invalid-action");
  const actions = new Set<ModerationAction>([
    "underReview", "hidden", "removed", "merged", "deleted", "inactive", "restricted", "suspended", "active",
  ]);
  if (!actions.has(value as ModerationAction)) throw new ModerationValidationError("invalid-action");
  return value as ModerationAction;
}

export function buildModerationQueue(items: readonly unknown[]): readonly ModerationQueueItem[] {
  return items
    .map(parseModerationQueueItem)
    .filter((item): item is ModerationQueueItem => item !== null)
    .sort((left, right) => timestampValue(left.createdAt) - timestampValue(right.createdAt));
}

export function planModerationAction(
  target: ModerationTarget,
  action: ModerationAction,
  currentStatus: unknown,
): ModerationPlan {
  const previousStatus = typeof currentStatus === "string" ? currentStatus : "unknown";
  if (target.targetType === "machine") return planMachine(target, action, previousStatus);
  if (target.targetType === "photo") return planPhoto(target, action, previousStatus);
  if (target.targetType === "product") return planProduct(target, action, previousStatus);
  return planUser(target, action, previousStatus);
}

export function buildPrivateModerationAudit(input: {
  readonly action: ModerationAction;
  readonly target: ModerationTarget;
  readonly previousStatus: string;
  readonly nextStatus: string;
  readonly reason: string | null;
  readonly moderatorUid: string;
}): PrivateModerationAuditRecord {
  if (input.moderatorUid.trim().length === 0) throw new ModerationValidationError("invalid-moderator");
  return {...input, timestamp: "serverTimestamp"};
}

export function toPublicModerationAudit(record: PrivateModerationAuditRecord): PublicModerationAuditRecord {
  const {moderatorUid: _privateModeratorUid, ...safeRecord} = record;
  return safeRecord;
}

function parseModerationQueueItem(value: unknown): ModerationQueueItem | null {
  if (!isRecord(value) || (value.status !== "new" && value.status !== "inReview" && value.status !== "resolutionPending")) return null;
  const id = optionalIdentifier(value.id);
  const source = value.source;
  if (id === null || (source !== "report" && source !== "correction")) return null;
  try {
    const rawTargetType = source === "correction" && value.targetType === undefined ? "machine" : value.targetType === "text" ? "machine" : value.targetType;
    const target = parseModerationTarget({...value, targetType: rawTargetType});
    const categoryOrReason = optionalText(source === "report" ? value.category : value.message);
    return {source, id, target, categoryOrReason, createdAt: value.createdAt, status: value.status};
  } catch {
    return null;
  }
}

function planMachine(target: ModerationTarget, action: ModerationAction, previousStatus: string): ModerationPlan {
  if (target.targetType !== "machine" || !machineStatuses.has(previousStatus)) return rejected(target, action, previousStatus, "invalid-current-status");
  const permitted = new Map<string, readonly ModerationAction[]>([
    ["active", ["underReview"]],
    ["underReview", ["hidden", "removed", "merged"]],
  ]);
  if (!permitted.get(previousStatus)?.includes(action)) return rejected(target, action, previousStatus, "invalid-transition");
  return allowed(target, action, previousStatus, action, null, false, false);
}

function planPhoto(target: ModerationTarget, action: ModerationAction, previousStatus: string): ModerationPlan {
  if (target.targetType !== "photo" || !photoStatuses.has(previousStatus)) return rejected(target, action, previousStatus, "invalid-current-status");
  if (action === "underReview" && previousStatus === "active") return allowed(target, action, previousStatus, "underReview", "active", false, false);
  if (action === "hidden" && previousStatus === "active") return allowed(target, action, previousStatus, "hidden", "inactive", false, false);
  if (action === "deleted" && (previousStatus === "active" || previousStatus === "inactive")) return allowed(target, action, previousStatus, "deleted", "inactive", false, true);
  return rejected(target, action, previousStatus, "invalid-transition");
}

function planProduct(target: ModerationTarget, action: ModerationAction, previousStatus: string): ModerationPlan {
  if (target.targetType !== "product" || previousStatus !== "active") return rejected(target, action, previousStatus, "invalid-current-status");
  if (action !== "inactive") return rejected(target, action, previousStatus, "invalid-transition");
  return allowed(target, action, previousStatus, "inactive", null, true, false);
}

function planUser(target: ModerationTarget, action: ModerationAction, previousStatus: string): ModerationPlan {
  if (target.targetType !== "user" || !userStatuses.has(previousStatus)) return rejected(target, action, previousStatus, "invalid-current-status");
  if (action !== "active" && action !== "restricted" && action !== "suspended") return rejected(target, action, previousStatus, "invalid-transition");
  if (action === previousStatus) return rejected(target, action, previousStatus, "no-state-change");
  return allowed(target, action, previousStatus, action, null, false, false);
}

function allowed(target: ModerationTarget, action: ModerationAction, previousStatus: string, nextStatus: string, publicStatus: "active" | "inactive" | null, affectsMachineProductIndex: boolean, deleteFormalStorage: boolean): ModerationPlan {
  return {allowed: true, reason: null, target, action, previousStatus, nextStatus, publicStatus, affectsMachineProductIndex, deleteFormalStorage};
}

function rejected(target: ModerationTarget, action: ModerationAction, previousStatus: string, reason: string): ModerationPlan {
  return {allowed: false, reason, target, action, previousStatus, nextStatus: null, publicStatus: null, affectsMachineProductIndex: false, deleteFormalStorage: false};
}

function optionalIdentifier(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function optionalText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function timestampValue(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (value instanceof Date) return value.getTime();
  if (isRecord(value) && typeof value.toMillis === "function") {
    const milliseconds = value.toMillis();
    if (typeof milliseconds === "number" && Number.isFinite(milliseconds)) return milliseconds;
  }
  return Number.MAX_SAFE_INTEGER;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export class ModerationValidationError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}
