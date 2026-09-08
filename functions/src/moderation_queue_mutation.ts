import {createHash} from "node:crypto";
import type {Firestore, Transaction} from "firebase-admin/firestore";
import {Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {type ModerationTarget, parseModerationTarget} from "./moderation_core";
import {assertModeratorForCaller, createFirestoreModerationReadStore, type ModerationCaller} from "./moderation_read";
import {type ModerationQueueRef, type ModerationQueueStatus, ModerationQueueValidationError, parseModerationQueueRef, planQueueLinkedModeration, planQueueTransition, targetFromStoredQueueItem} from "./moderation_queue_core";
import {applyPreparedModerationActionForCaller, applyPreparedPhotoDeletionForCaller, type ApplyModerationActionResult, type ModerationStorageBucket, type ModerationTransactionPreparation, type PreparedPhotoDeletion, type PreparedPhotoDeletionState} from "./moderation_mutation";
import {type ModerationTransactionExtension} from "./moderation_transaction_extension";

const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export const MARK_MODERATION_ITEM_IN_REVIEW_OPERATION = "markModerationItemInReview";
export const RESOLVE_MODERATION_ITEM_OPERATION = "resolveModerationItem";
export const APPLY_MODERATION_QUEUE_ACTION_OPERATION = "applyModerationQueueAction";

interface InReviewInput { readonly queueRef: ModerationQueueRef; readonly requestId: string; }
interface ResolveInput { readonly queueRef: ModerationQueueRef; readonly resolution: "noAction" | "rejected"; readonly reason: string; readonly requestId: string; }
interface QueueMachineActionInput { readonly queueRef: ModerationQueueRef; readonly action: unknown; readonly reason: unknown; readonly requestId: unknown; readonly requestedTarget: ModerationTarget | undefined; }
export interface MarkModerationItemInReviewResult { readonly sourceType: "report" | "correction"; readonly itemId: string; readonly status: "inReview"; readonly target: ModerationTarget; readonly changed: boolean; }
export interface ResolveModerationItemResult { readonly sourceType: "report" | "correction"; readonly itemId: string; readonly status: "resolved"; readonly resolution: "noAction" | "rejected"; readonly target: ModerationTarget; }
export interface ApplyModerationQueueActionResult extends ApplyModerationActionResult { readonly sourceType: "report" | "correction"; readonly itemId: string; readonly machineId?: string; readonly photoId?: string; readonly productId?: string; readonly targetUserId?: string; readonly status: "resolved"; readonly resolution: "actionTaken"; }

export async function markModerationItemInReviewForCaller(firestore: Firestore, caller: ModerationCaller, rawInput: unknown): Promise<MarkModerationItemInReviewResult> {
  await assertModeratorForCaller(createFirestoreModerationReadStore(firestore), caller);
  const input = parseInput(rawInput);
  const dedupeRef = firestore.collection("request_deduplication").doc(digest(`queueInReview:${caller.uid}:${input.requestId}`));
  const stored = await dedupeRef.get();
  if (stored.exists) return parseStoredResult(stored.data()?.result);
  return firestore.runTransaction(async (transaction) => {
    const duplicate = await transaction.get(dedupeRef);
    if (duplicate.exists) return parseStoredResult(duplicate.data()?.result);
    const queueRef = queueDocument(firestore, input.queueRef);
    const queue = await transaction.get(queueRef);
    if (!queue.exists) throw queueNotFound();
    const queueData = queue.data();
    const target = parseStoredTarget(input.queueRef, queueData);
    const status = parseQueueStatus(queueData?.status);
    if (status === "inReview") return {sourceType: input.queueRef.sourceType, itemId: input.queueRef.itemId, status: "inReview", target, changed: false};
    const plan = planQueueTransition(status, "inReview");
    if (!plan.allowed || plan.nextStatus !== "inReview") throw invalidQueueTransition();
    const now = Timestamp.now();
    const result: MarkModerationItemInReviewResult = {sourceType: input.queueRef.sourceType, itemId: input.queueRef.itemId, status: "inReview", target, changed: true};
    transaction.update(queueRef, {status: "inReview", updatedAt: now});
    transaction.create(firestore.collection("moderation_private_queue_audit").doc(digest(`queueInReviewAudit:${caller.uid}:${input.requestId}`)), {sourceType: input.queueRef.sourceType, itemId: input.queueRef.itemId, previousStatus: status, nextStatus: "inReview", target, moderatorUid: caller.uid, requestId: input.requestId, createdAt: now});
    transaction.create(dedupeRef, {uid: caller.uid, operation: MARK_MODERATION_ITEM_IN_REVIEW_OPERATION, requestId: input.requestId, status: "completed", result, createdAt: now, updatedAt: now});
    return result;
  });
}

export async function resolveModerationItemForCaller(firestore: Firestore, caller: ModerationCaller, rawInput: unknown): Promise<ResolveModerationItemResult> {
  await assertModeratorForCaller(createFirestoreModerationReadStore(firestore), caller);
  const input = parseResolveInput(rawInput);
  const dedupeRef = firestore.collection("request_deduplication").doc(digest(`queueResolve:${caller.uid}:${input.requestId}`));
  const stored = await dedupeRef.get();
  if (stored.exists) return parseStoredResolveResult(stored.data()?.result);
  return firestore.runTransaction(async (transaction) => {
    const duplicate = await transaction.get(dedupeRef);
    if (duplicate.exists) return parseStoredResolveResult(duplicate.data()?.result);
    const queueRef = queueDocument(firestore, input.queueRef);
    const queue = await transaction.get(queueRef);
    if (!queue.exists) throw queueNotFound();
    const queueData = queue.data();
    const target = parseStoredTarget(input.queueRef, queueData);
    const status = parseQueueStatus(queueData?.status);
    const plan = planQueueTransition(status, input.resolution);
    if (!plan.allowed || plan.nextStatus !== "resolved" || plan.resolution !== input.resolution) throw invalidQueueTransition();
    const now = Timestamp.now();
    const result: ResolveModerationItemResult = {sourceType: input.queueRef.sourceType, itemId: input.queueRef.itemId, status: "resolved", resolution: input.resolution, target};
    transaction.update(queueRef, {status: "resolved", resolution: input.resolution, updatedAt: now});
    transaction.create(firestore.collection("moderation_private_queue_audit").doc(digest(`queueResolveAudit:${caller.uid}:${input.requestId}`)), {sourceType: input.queueRef.sourceType, itemId: input.queueRef.itemId, previousStatus: status, nextStatus: "resolved", resolution: input.resolution, reason: input.reason, target, moderatorUid: caller.uid, requestId: input.requestId, createdAt: now});
    transaction.create(dedupeRef, {uid: caller.uid, operation: RESOLVE_MODERATION_ITEM_OPERATION, requestId: input.requestId, status: "completed", result, createdAt: now, updatedAt: now});
    return result;
  });
}

export async function applyModerationQueueActionForCaller(firestore: Firestore, caller: ModerationCaller, rawInput: unknown, bucket?: ModerationStorageBucket): Promise<ApplyModerationQueueActionResult> {
  await assertModeratorForCaller(createFirestoreModerationReadStore(firestore), caller);
  const input = parseQueueMachineActionInput(rawInput);
  if (input.action === "deleted") {
    if (bucket === undefined) throw new HttpsError("failed-precondition", "Photo storage is not configured.", {appCode: "moderation-photo-storage-unavailable"});
    return applyQueuedPhotoDeletionForCaller(firestore, caller, input, bucket);
  }
  const result = await applyPreparedModerationActionForCaller(firestore, caller, {requestId: input.requestId, target: {targetType: "machine", machineId: "placeholder"}, action: input.action, reason: input.reason}, async (_store, transaction, preparedCaller, preparedInput) => {
    const queueRef = queueDocument(firestore, input.queueRef);
    const queue = await transaction.get(queueRef);
    if (!queue.exists) throw queueNotFound();
    const target = parseStoredTarget(input.queueRef, queue.data());
    if (target.targetType !== "machine" && target.targetType !== "product" && target.targetType !== "user" && target.targetType !== "photo") throw queueTargetNotSupported();
    if (input.requestedTarget !== undefined && JSON.stringify(input.requestedTarget) !== JSON.stringify(target)) throw queueTargetMismatch();
    if (preparedInput.target.targetType !== "machine" || preparedInput.target.machineId !== "placeholder") throw queueTargetMismatch();
    const status = parseQueueStatus(queue.data()?.status);
    const lifecycle = planQueueTransition(status, "actionTaken");
    if (!lifecycle.allowed || lifecycle.nextStatus !== "resolved" || lifecycle.resolution !== "actionTaken") throw invalidQueueTransition();
    const queueExtension = target.targetType === "machine" ? createMachineQueueExtension(input.queueRef, target, status, preparedInput.action) : target.targetType === "product" ? createProductQueueExtension(input.queueRef, target, status, preparedInput.action) : target.targetType === "user" ? createUserQueueExtension(input.queueRef, target, status, preparedInput.action) : createPhotoQueueExtension(input.queueRef, target, status, preparedInput.action);
    const resultFields = {sourceType: input.queueRef.sourceType, itemId: input.queueRef.itemId, ...("machineId" in target ? {machineId: target.machineId} : {targetUserId: target.targetUserId}), ...(target.targetType === "photo" ? {photoId: target.photoId} : {}), ...(target.targetType === "product" ? {productId: target.productId} : {}), status: "resolved", resolution: "actionTaken"};
    return {extension: queueExtension, target, auditFields: {queue: queueExtension.metadata.queue}, resultFields} as ModerationTransactionPreparation;
  });
  return parseQueueActionResult(result);
}

async function applyQueuedPhotoDeletionForCaller(firestore: Firestore, caller: ModerationCaller, input: QueueMachineActionInput, bucket: ModerationStorageBucket): Promise<ApplyModerationQueueActionResult> {
  const result = await applyPreparedPhotoDeletionForCaller(firestore, caller, {requestId: input.requestId, target: {targetType: "machine", machineId: "placeholder"}, action: input.action, reason: input.reason}, bucket, {
    async resolveTarget(_store, transaction, _preparedCaller, preparedInput) {
      if (preparedInput.target.targetType !== "machine" || preparedInput.target.machineId !== "placeholder") throw queueTargetMismatch();
      const queue = await transaction.get(queueDocument(firestore, input.queueRef));
      if (!queue.exists) throw queueNotFound();
      const target = parseStoredTarget(input.queueRef, queue.data());
      if (target.targetType !== "photo") throw queueTargetNotSupported();
      if (input.requestedTarget !== undefined && JSON.stringify(input.requestedTarget) !== JSON.stringify(target)) throw queueTargetMismatch();
      return target;
    },
    async prepare(_store, transaction, _preparedCaller, preparedInput, target, state) {
      const queueRef = queueDocument(firestore, input.queueRef);
      const queue = await transaction.get(queueRef);
      if (!queue.exists) throw queueNotFound();
      const queueTarget = parseStoredTarget(input.queueRef, queue.data());
      if (queueTarget.targetType !== "photo" || queueTarget.machineId !== target.machineId || queueTarget.photoId !== target.photoId) throw queueTargetMismatch();
      const status = parseQueueStatus(queue.data()?.status);
      if (state === "initial") {
        const lifecycle = planQueueLinkedModeration(status, true);
        if (!lifecycle.allowed || lifecycle.nextStatus !== "resolutionPending") throw invalidQueueTransition();
      } else if (state === "retry") {
        if (status !== "resolutionPending") throw invalidQueueTransition();
      } else if (status !== "resolved" || queue.data()?.resolution !== "actionTaken") throw invalidQueueTransition();
      const mutationExtension = createPhotoDeletionMutationQueueExtension(input.queueRef, target, status);
      const finalizeExtension = createPhotoDeletionFinalizeQueueExtension(input.queueRef, target);
      const resultFields = {sourceType: input.queueRef.sourceType, itemId: input.queueRef.itemId, machineId: target.machineId, photoId: target.photoId, status: "resolved", resolution: "actionTaken"} as const;
      const prepared: PreparedPhotoDeletion = {target, mutationExtension, finalizeExtension, auditFields: {queue: mutationExtension.metadata.queue}, resultFields, finalizePrepare: async (_finalStore, finalTransaction, _finalCaller, _finalInput, finalTarget) => {
        const finalQueue = await finalTransaction.get(queueDocument(firestore, input.queueRef));
        if (!finalQueue.exists) throw queueNotFound();
        const finalTargetFromQueue = parseStoredTarget(input.queueRef, finalQueue.data());
        if (finalTargetFromQueue.targetType !== "photo" || finalTargetFromQueue.machineId !== finalTarget.machineId || finalTargetFromQueue.photoId !== finalTarget.photoId) throw queueTargetMismatch();
        const finalStatus = parseQueueStatus(finalQueue.data()?.status);
        const plan = planQueueTransition(finalStatus, "photoFinalize");
        if (!plan.allowed || plan.nextStatus !== "resolved" || plan.resolution !== "actionTaken") throw invalidQueueTransition();
        return createPhotoDeletionFinalizeQueueExtension(input.queueRef, finalTarget);
      }};
      return prepared;
    },
  });
  return parseQueueActionResult(result);
}

function parseInput(value: unknown): InReviewInput {
  if (!isRecord(value) || !hasOnlyKeys(value, new Set(["queueRef", "requestId"])) || typeof value.requestId !== "string" || !UUID_V4.test(value.requestId)) throw invalidInput();
  try { return {queueRef: parseModerationQueueRef(value.queueRef), requestId: value.requestId}; } catch (error: unknown) { if (error instanceof ModerationQueueValidationError) throw invalidInput(); throw error; }
}
function parseResolveInput(value: unknown): ResolveInput {
  if (!isRecord(value) || !hasOnlyKeys(value, new Set(["queueRef", "resolution", "reason", "requestId"])) || typeof value.requestId !== "string" || !UUID_V4.test(value.requestId) || (value.resolution !== "noAction" && value.resolution !== "rejected") || typeof value.reason !== "string") throw invalidResolveInput();
  const reason = value.reason.trim();
  if (reason.length < 1 || reason.length > 500) throw invalidResolveInput();
  try { return {queueRef: parseModerationQueueRef(value.queueRef), resolution: value.resolution, reason, requestId: value.requestId}; } catch (error: unknown) { if (error instanceof ModerationQueueValidationError) throw invalidResolveInput(); throw error; }
}
function parseQueueMachineActionInput(value: unknown): QueueMachineActionInput {
  if (!isRecord(value) || !hasOnlyKeys(value, new Set(["queueRef", "action", "reason", "requestId", "target"]))) throw invalidQueueActionInput();
  try { return {queueRef: parseModerationQueueRef(value.queueRef), action: value.action, reason: value.reason, requestId: value.requestId, requestedTarget: value.target === undefined ? undefined : parseModerationTarget(value.target)}; } catch { throw invalidQueueActionInput(); }
}

function queueDocument(firestore: Firestore, queueRef: ModerationQueueRef) { return firestore.collection(queueRef.sourceType === "report" ? "machine_reports" : "machine_corrections").doc(queueRef.itemId); }
function parseStoredTarget(queueRef: ModerationQueueRef, value: unknown): ModerationTarget {
  if (!isRecord(value)) throw malformedQueueItem();
  const targetType = queueRef.sourceType === "correction" && value.targetType === undefined ? "machine" : value.targetType;
  try { return targetFromStoredQueueItem({targetType: targetType as "machine" | "photo" | "product" | "text" | "user", machineId: value.machineId as string | undefined, photoId: value.photoId as string | null | undefined, productId: value.productId as string | null | undefined, targetUserId: value.targetUserId as string | null | undefined}); } catch { throw malformedQueueItem(); }
}
function parseQueueStatus(value: unknown): ModerationQueueStatus { if (value === "new" || value === "inReview" || value === "resolutionPending" || value === "resolved") return value; throw malformedQueueItem(); }
function parseStoredResult(value: unknown): MarkModerationItemInReviewResult { if (!isRecord(value) || (value.sourceType !== "report" && value.sourceType !== "correction") || typeof value.itemId !== "string" || value.status !== "inReview" || typeof value.changed !== "boolean") throw new HttpsError("internal", "Stored queue result is invalid.", {appCode: "queue-idempotency-record-invalid"}); return value as unknown as MarkModerationItemInReviewResult; }
function parseStoredResolveResult(value: unknown): ResolveModerationItemResult { if (!isRecord(value) || (value.sourceType !== "report" && value.sourceType !== "correction") || typeof value.itemId !== "string" || value.status !== "resolved" || (value.resolution !== "noAction" && value.resolution !== "rejected")) throw new HttpsError("internal", "Stored queue result is invalid.", {appCode: "queue-idempotency-record-invalid"}); return value as unknown as ResolveModerationItemResult; }
function parseQueueActionResult(value: ApplyModerationActionResult): ApplyModerationQueueActionResult { if (!isRecord(value) || value.ok !== true || (value.targetType !== "machine" && value.targetType !== "product" && value.targetType !== "user" && value.targetType !== "photo") || (value.sourceType !== "report" && value.sourceType !== "correction") || typeof value.itemId !== "string" || (value.targetType !== "user" && typeof value.machineId !== "string") || (value.targetType === "photo" && typeof value.photoId !== "string") || (value.targetType === "product" && typeof value.productId !== "string") || (value.targetType === "user" && typeof value.targetUserId !== "string") || value.status !== "resolved" || value.resolution !== "actionTaken") throw new HttpsError("internal", "Stored queue result is invalid.", {appCode: "queue-idempotency-record-invalid"}); return value as unknown as ApplyModerationQueueActionResult; }
function createMachineQueueExtension(queueRef: ModerationQueueRef, target: Extract<ModerationTarget, {targetType: "machine"}>, previousStatus: ModerationQueueStatus, action: ApplyModerationActionResult["action"]): ModerationTransactionExtension { const metadata = {kind: "machine-queue-action", queue: {sourceType: queueRef.sourceType, itemId: queueRef.itemId, previousStatus, nextStatus: "resolved", resolution: "actionTaken"}} as const; return {phase: "mutation", metadata, validate(context) { if (context.target.targetType !== "machine" || context.target.machineId !== target.machineId || context.action !== action) throw queueTargetMismatch(); }, stage(_context, port) { port.setQueueRecord(queueRef.sourceType, queueRef.itemId, {status: "resolved", resolution: "actionTaken", linkedAction: action, updatedAt: Timestamp.now()}); }}; }
function createProductQueueExtension(queueRef: ModerationQueueRef, target: Extract<ModerationTarget, {targetType: "product"}>, previousStatus: ModerationQueueStatus, action: ApplyModerationActionResult["action"]): ModerationTransactionExtension { const metadata = {kind: "product-queue-action", queue: {sourceType: queueRef.sourceType, itemId: queueRef.itemId, previousStatus, nextStatus: "resolved", resolution: "actionTaken"}} as const; return {phase: "mutation", metadata, validate(context) { if (context.target.targetType !== "product" || context.target.machineId !== target.machineId || context.target.productId !== target.productId || context.action !== action) throw queueTargetMismatch(); }, stage(_context, port) { port.setQueueRecord(queueRef.sourceType, queueRef.itemId, {status: "resolved", resolution: "actionTaken", linkedAction: action, updatedAt: Timestamp.now()}); }}; }
function createUserQueueExtension(queueRef: ModerationQueueRef, target: Extract<ModerationTarget, {targetType: "user"}>, previousStatus: ModerationQueueStatus, action: ApplyModerationActionResult["action"]): ModerationTransactionExtension { const metadata = {kind: "user-queue-action", queue: {sourceType: queueRef.sourceType, itemId: queueRef.itemId, previousStatus, nextStatus: "resolved", resolution: "actionTaken"}} as const; return {phase: "mutation", metadata, validate(context) { if (context.target.targetType !== "user" || context.target.targetUserId !== target.targetUserId || context.action !== action) throw queueTargetMismatch(); }, stage(_context, port) { port.setQueueRecord(queueRef.sourceType, queueRef.itemId, {status: "resolved", resolution: "actionTaken", linkedAction: action, updatedAt: Timestamp.now()}); }}; }
function createPhotoQueueExtension(queueRef: ModerationQueueRef, target: Extract<ModerationTarget, {targetType: "photo"}>, previousStatus: ModerationQueueStatus, action: ApplyModerationActionResult["action"]): ModerationTransactionExtension { const metadata = {kind: "photo-queue-action", queue: {sourceType: queueRef.sourceType, itemId: queueRef.itemId, previousStatus, nextStatus: "resolved", resolution: "actionTaken"}} as const; return {phase: "mutation", metadata, validate(context) { if (context.target.targetType !== "photo" || context.target.machineId !== target.machineId || context.target.photoId !== target.photoId || context.action !== action) throw queueTargetMismatch(); }, stage(_context, port) { port.setQueueRecord(queueRef.sourceType, queueRef.itemId, {status: "resolved", resolution: "actionTaken", linkedAction: action, updatedAt: Timestamp.now()}); }}; }
function createPhotoDeletionMutationQueueExtension(queueRef: ModerationQueueRef, target: Extract<ModerationTarget, {targetType: "photo"}>, previousStatus: ModerationQueueStatus): ModerationTransactionExtension { const metadata = {kind: "photo-deletion-queue-mutation", queue: {sourceType: queueRef.sourceType, itemId: queueRef.itemId, previousStatus, nextStatus: "resolutionPending", resolution: null}} as const; return {phase: "mutation", metadata, validate(context) { if (context.target.targetType !== "photo" || context.target.machineId !== target.machineId || context.target.photoId !== target.photoId || context.action !== "deleted" || context.phase !== "mutation") throw queueTargetMismatch(); }, stage(_context, port) { port.setQueueRecord(queueRef.sourceType, queueRef.itemId, {status: "resolutionPending", resolution: null, linkedAction: "deleted", updatedAt: Timestamp.now()}); }}; }
function createPhotoDeletionFinalizeQueueExtension(queueRef: ModerationQueueRef, target: Extract<ModerationTarget, {targetType: "photo"}>): ModerationTransactionExtension { const metadata = {kind: "photo-deletion-queue-finalize", queue: {sourceType: queueRef.sourceType, itemId: queueRef.itemId, previousStatus: "resolutionPending", nextStatus: "resolved", resolution: "actionTaken"}} as const; return {phase: "finalize", metadata, validate(context) { if (context.target.targetType !== "photo" || context.target.machineId !== target.machineId || context.target.photoId !== target.photoId || context.action !== "deleted" || context.phase !== "finalize") throw queueTargetMismatch(); }, stage(_context, port) { port.setQueueRecord(queueRef.sourceType, queueRef.itemId, {status: "resolved", resolution: "actionTaken", linkedAction: "deleted", updatedAt: Timestamp.now()}); }}; }
function digest(value: string): string { return createHash("sha256").update(value).digest("hex"); }
function hasOnlyKeys(value: Record<string, unknown>, keys: ReadonlySet<string>): boolean { return Object.keys(value).every((key) => keys.has(key)); }
function isRecord(value: unknown): value is Record<string, unknown> { return typeof value === "object" && value !== null && !Array.isArray(value); }
function invalidInput(): HttpsError { return new HttpsError("invalid-argument", "Moderation queue request is invalid.", {appCode: "invalid-moderation-queue-in-review"}); }
function invalidResolveInput(): HttpsError { return new HttpsError("invalid-argument", "Moderation queue request is invalid.", {appCode: "invalid-moderation-queue-resolve"}); }
function invalidQueueActionInput(): HttpsError { return new HttpsError("invalid-argument", "Moderation queue request is invalid.", {appCode: "invalid-moderation-queue-action"}); }
function queueTargetMismatch(): HttpsError { return new HttpsError("failed-precondition", "Moderation queue target does not match.", {appCode: "moderation-queue-target-mismatch"}); }
function queueTargetNotSupported(): HttpsError { return new HttpsError("failed-precondition", "Moderation queue target is not supported.", {appCode: "moderation-queue-target-not-supported"}); }
function queueNotFound(): HttpsError { return new HttpsError("not-found", "Moderation queue item was not found.", {appCode: "moderation-queue-item-not-found"}); }
function malformedQueueItem(): HttpsError { return new HttpsError("failed-precondition", "Moderation queue item is invalid.", {appCode: "moderation-queue-item-invalid"}); }
function invalidQueueTransition(): HttpsError { return new HttpsError("failed-precondition", "Moderation queue transition is not allowed.", {appCode: "moderation-queue-transition-not-allowed"}); }
