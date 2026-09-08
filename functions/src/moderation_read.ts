import type {Firestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {
  type ModerationAction,
  type ModerationPlan,
  type ModerationQueueItem,
  type ModerationTarget,
  ModerationValidationError,
  assertModeratorAuthorized,
  buildModerationQueue,
  parseModerationAction,
  parseModerationTarget,
  planModerationAction as buildModerationPlan,
} from "./moderation_core";

const DEFAULT_QUEUE_LIMIT = 50;
const MAX_QUEUE_LIMIT = 100;
const MAX_QUEUE_OFFSET = 1000;

export interface ModerationCaller {
  readonly uid: string;
  readonly customClaims: unknown;
}

export interface ModerationQueuePage {
  readonly items: readonly ModerationQueueItem[];
  readonly nextCursor: string | null;
}

export interface ModerationTargetDetail {
  readonly target: ModerationTarget;
  readonly currentStatus: string;
  readonly publicStatus: "active" | "inactive" | null;
  readonly hasPrivateMetadata: boolean;
  readonly indexIsActive: boolean | null;
}

export interface ModerationPlanResponse {
  readonly allowed: boolean;
  readonly targetType: ModerationTarget["targetType"];
  readonly action: ModerationAction;
  readonly currentStatus: string;
  readonly nextStatus: string | null;
  readonly requiresStorageDelete: boolean;
  readonly affectsIndex: boolean;
  readonly requiresPrivateAudit: boolean;
}

export interface ModerationReadStore {
  getAccountStatus(uid: string): Promise<unknown>;
  listQueueDocuments(limit: number): Promise<readonly unknown[]>;
  getMachine(machineId: string): Promise<unknown | null>;
  getPublicPhoto(machineId: string, photoId: string): Promise<unknown | null>;
  getPrivatePhoto(machineId: string, photoId: string): Promise<unknown | null>;
  getMachineProduct(machineId: string, productId: string): Promise<unknown | null>;
  getMachineProductIndex(machineId: string, productId: string): Promise<unknown | null>;
  getUser(targetUserId: string): Promise<unknown | null>;
}

export async function listModerationQueueForCaller(
  store: ModerationReadStore,
  caller: ModerationCaller,
  rawInput: unknown,
): Promise<ModerationQueuePage> {
  await assertModeratorForCaller(store, caller);
  const {limit, offset} = parseQueueInput(rawInput);
  const queue = buildModerationQueue(await store.listQueueDocuments(Math.min(MAX_QUEUE_OFFSET + MAX_QUEUE_LIMIT, offset + limit + 1)));
  const items = queue.slice(offset, offset + limit);
  const nextCursor = queue.length > offset + limit ? encodeCursor(offset + limit) : null;
  return {items, nextCursor};
}

export async function getModerationTargetForCaller(
  store: ModerationReadStore,
  caller: ModerationCaller,
  rawInput: unknown,
): Promise<ModerationTargetDetail> {
  await assertModeratorForCaller(store, caller);
  return getModerationTarget(store, parseInputTarget(rawInput));
}

export async function planModerationActionForCaller(
  store: ModerationReadStore,
  caller: ModerationCaller,
  rawInput: unknown,
): Promise<ModerationPlanResponse> {
  await assertModeratorForCaller(store, caller);
  if (!isRecord(rawInput)) throw invalidArgument("invalid-moderation-plan");
  const target = parseInputTarget(rawInput.target);
  let action: ModerationAction;
  try {
    action = parseModerationAction(rawInput.action);
  } catch (error: unknown) {
    throw mapValidationError(error, "invalid-moderation-action");
  }
  const detail = await getModerationTarget(store, target);
  return toPlanResponse(buildModerationPlan(target, action, detail.currentStatus));
}

export function createFirestoreModerationReadStore(firestore: Firestore): ModerationReadStore {
  return {
    async getAccountStatus(uid) {
      const snapshot = await firestore.collection("users").doc(uid).get();
      return snapshot.data()?.accountStatus ?? "active";
    },
    async listQueueDocuments(limit) {
      const [reports, corrections] = await Promise.all([
        firestore.collection("machine_reports").where("status", "in", ["new", "inReview", "resolutionPending"]).orderBy("createdAt", "asc").limit(limit).get(),
        firestore.collection("machine_corrections").where("status", "in", ["new", "inReview", "resolutionPending"]).orderBy("createdAt", "asc").limit(limit).get(),
      ]);
      return [
        ...reports.docs.map((document) => ({source: "report", id: document.id, ...document.data()})),
        ...corrections.docs.map((document) => ({source: "correction", id: document.id, ...document.data()})),
      ];
    },
    async getMachine(machineId) { return documentData(await firestore.collection("vending_machines").doc(machineId).get()); },
    async getPublicPhoto(machineId, photoId) { return documentData(await firestore.collection("vending_machines").doc(machineId).collection("photos").doc(photoId).get()); },
    async getPrivatePhoto(machineId, photoId) { return documentData(await firestore.collection("vending_machine_private").doc(machineId).collection("photos").doc(photoId).get()); },
    async getMachineProduct(machineId, productId) { return documentData(await firestore.collection("vending_machines").doc(machineId).collection("products").doc(productId).get()); },
    async getMachineProductIndex(machineId, productId) { return documentData(await firestore.collection("machine_product_index").doc(`${machineId}_${productId}`).get()); },
    async getUser(targetUserId) { return documentData(await firestore.collection("users").doc(targetUserId).get()); },
  };
}

export async function assertModeratorForCaller(store: ModerationReadStore, caller: ModerationCaller): Promise<void> {
  try {
    assertModeratorAuthorized({uid: caller.uid, customClaims: caller.customClaims, accountStatus: await store.getAccountStatus(caller.uid)});
  } catch (error: unknown) {
    throw mapAuthorizationError(error);
  }
}

async function getModerationTarget(store: ModerationReadStore, target: ModerationTarget): Promise<ModerationTargetDetail> {
  if (target.targetType === "machine") {
    const machine = asRecord(await store.getMachine(target.machineId));
    return {target, currentStatus: requiredStatus(machine, "machine"), publicStatus: null, hasPrivateMetadata: false, indexIsActive: null};
  }
  if (target.targetType === "photo") {
    const publicPhoto = asRecord(await store.getPublicPhoto(target.machineId, target.photoId));
    const privatePhoto = await store.getPrivatePhoto(target.machineId, target.photoId);
    return {target, currentStatus: requiredStatus(publicPhoto, "photo"), publicStatus: photoPublicStatus(publicPhoto), hasPrivateMetadata: privatePhoto !== null, indexIsActive: null};
  }
  if (target.targetType === "product") {
    const product = asRecord(await store.getMachineProduct(target.machineId, target.productId));
    const index = await store.getMachineProductIndex(target.machineId, target.productId);
    return {target, currentStatus: product.isActive === true ? "active" : "inactive", publicStatus: null, hasPrivateMetadata: false, indexIsActive: isRecord(index) && index.isActive === true};
  }
  const user = asRecord(await store.getUser(target.targetUserId));
  return {target, currentStatus: user.accountStatus === undefined ? "active" : requiredAccountStatus(user), publicStatus: null, hasPrivateMetadata: false, indexIsActive: null};
}

function parseQueueInput(value: unknown): {readonly limit: number; readonly offset: number} {
  if (value === undefined || value === null) return {limit: DEFAULT_QUEUE_LIMIT, offset: 0};
  if (!isRecord(value)) throw invalidArgument("invalid-moderation-queue-input");
  const limit = value.limit === undefined ? DEFAULT_QUEUE_LIMIT : value.limit;
  if (!Number.isInteger(limit) || typeof limit !== "number" || limit < 1 || limit > MAX_QUEUE_LIMIT) throw invalidArgument("invalid-moderation-queue-limit");
  return {limit, offset: value.cursor === undefined || value.cursor === null ? 0 : decodeCursor(value.cursor)};
}

function parseInputTarget(value: unknown): ModerationTarget {
  try { return parseModerationTarget(value); } catch (error: unknown) { throw mapValidationError(error, "invalid-moderation-target"); }
}

function encodeCursor(offset: number): string {
  return Buffer.from(JSON.stringify({offset}), "utf8").toString("base64url");
}

function decodeCursor(value: unknown): number {
  if (typeof value !== "string" || value.length === 0) throw invalidArgument("invalid-moderation-queue-cursor");
  try {
    const parsed: unknown = JSON.parse(Buffer.from(value, "base64url").toString("utf8"));
    if (isRecord(parsed) && typeof parsed.offset === "number" && Number.isInteger(parsed.offset) && parsed.offset >= 0 && parsed.offset <= MAX_QUEUE_OFFSET) return parsed.offset;
  } catch {}
  throw invalidArgument("invalid-moderation-queue-cursor");
}

function toPlanResponse(plan: ModerationPlan): ModerationPlanResponse {
  return {allowed: plan.allowed, targetType: plan.target.targetType, action: plan.action, currentStatus: plan.previousStatus, nextStatus: plan.nextStatus, requiresStorageDelete: plan.deleteFormalStorage, affectsIndex: plan.affectsMachineProductIndex, requiresPrivateAudit: plan.allowed};
}

function documentData(snapshot: {readonly exists: boolean; data(): unknown}): unknown | null { return snapshot.exists ? snapshot.data() : null; }
function asRecord(value: unknown | null): Record<string, unknown> { if (!isRecord(value)) throw new HttpsError("not-found", "Moderation target was not found.", {appCode: "moderation-target-not-found"}); return value; }
function requiredStatus(value: Record<string, unknown>, target: string): string { if (typeof value.status !== "string") throw new HttpsError("failed-precondition", "Moderation target status is invalid.", {appCode: `moderation-${target}-status-invalid`}); return value.status; }
function requiredAccountStatus(value: Record<string, unknown>): string { if (typeof value.accountStatus !== "string") throw new HttpsError("failed-precondition", "Moderation target status is invalid.", {appCode: "moderation-user-status-invalid"}); return value.accountStatus; }
function photoPublicStatus(value: Record<string, unknown>): "active" | "inactive" { const status = requiredStatus(value, "photo"); if (status === "active" || status === "inactive") return status; throw new HttpsError("failed-precondition", "Moderation photo status is invalid.", {appCode: "moderation-photo-status-invalid"}); }
function invalidArgument(appCode: string): HttpsError { return new HttpsError("invalid-argument", "Moderation request is invalid.", {appCode}); }
function mapValidationError(error: unknown, appCode: string): HttpsError { if (error instanceof ModerationValidationError) return invalidArgument(appCode); throw error; }
function mapAuthorizationError(error: unknown): HttpsError { if (!(error instanceof ModerationValidationError)) throw error; return new HttpsError(error.code === "unauthenticated" ? "unauthenticated" : "permission-denied", "Moderator authorization is required.", {appCode: error.code}); }
function isRecord(value: unknown): value is Record<string, unknown> { return typeof value === "object" && value !== null && !Array.isArray(value); }
