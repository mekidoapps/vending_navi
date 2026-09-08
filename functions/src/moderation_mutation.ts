import {createHash} from "node:crypto";
import type {Firestore, Transaction} from "firebase-admin/firestore";
import {Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {type ModerationAction, type ModerationTarget, parseModerationAction, parseModerationTarget, planModerationAction} from "./moderation_core";
import {assertModeratorForCaller, createFirestoreModerationReadStore, type ModerationCaller} from "./moderation_read";
import {createModerationTransactionContext, noFinalizeModerationTransactionExtension, noModerationTransactionExtension, type ModerationTransactionContext, type ModerationTransactionExtension, type ModerationTransactionPort} from "./moderation_transaction_extension";

const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const MAX_REASON_LENGTH = 500;
export const APPLY_MODERATION_ACTION_OPERATION = "applyModerationAction";

interface ApplyInput { readonly requestId: string; readonly target: ModerationTarget; readonly action: ModerationAction; readonly reason: string; }
export interface ApplyModerationActionResult { readonly ok: true; readonly targetType: ModerationTarget["targetType"]; readonly action: ModerationAction; readonly previousStatus: string; readonly nextStatus: string; readonly affectsIndex: boolean; }
export interface ModerationTransactionPreparation { readonly extension: ModerationTransactionExtension; readonly target?: ModerationTarget; readonly auditFields?: Readonly<Record<string, unknown>>; readonly resultFields?: Readonly<Record<string, unknown>>; }
export type ModerationTransactionPreparer = (firestore: Firestore, transaction: Transaction, caller: ModerationCaller, input: ApplyInput) => Promise<ModerationTransactionPreparation>;
export interface ModerationStorageBucket { file(path: string): {delete(): Promise<unknown>}; }
export type PreparedPhotoDeletionState = "initial" | "retry" | "completed";
export interface PreparedPhotoDeletion { readonly target: Extract<ModerationTarget, {targetType: "photo"}>; readonly mutationExtension: ModerationTransactionExtension; readonly finalizeExtension: ModerationTransactionExtension; readonly finalizePrepare?: (firestore: Firestore, transaction: Transaction, caller: ModerationCaller, input: ApplyInput, target: Extract<ModerationTarget, {targetType: "photo"}>) => Promise<ModerationTransactionExtension>; readonly auditFields?: Readonly<Record<string, unknown>>; readonly resultFields?: Readonly<Record<string, unknown>>; }
export interface PreparedPhotoDeletionHooks {
  resolveTarget(firestore: Firestore, transaction: Transaction, caller: ModerationCaller, input: ApplyInput): Promise<Extract<ModerationTarget, {targetType: "photo"}>>;
  prepare(firestore: Firestore, transaction: Transaction, caller: ModerationCaller, input: ApplyInput, target: Extract<ModerationTarget, {targetType: "photo"}>, state: PreparedPhotoDeletionState): Promise<PreparedPhotoDeletion>;
}

export async function applyModerationActionForCaller(firestore: Firestore, caller: ModerationCaller, rawInput: unknown, bucket?: ModerationStorageBucket, extension: ModerationTransactionExtension = noModerationTransactionExtension, finalizeExtension: ModerationTransactionExtension = noFinalizeModerationTransactionExtension): Promise<ApplyModerationActionResult> {
  await assertModeratorForCaller(createFirestoreModerationReadStore(firestore), caller);
  const input = parseApplyInput(rawInput);
  if (input.target.targetType === "photo") return applyPhotoModeration(firestore, caller, input, bucket, extension, finalizeExtension);
  const dedupeRef = firestore.collection("request_deduplication").doc(dedupeId(caller.uid, input.requestId));
  const stored = await dedupeRef.get();
  if (stored.exists) return parseStoredResult(stored.data()?.result);

  return firestore.runTransaction(async (transaction) => {
    const duplicate = await transaction.get(dedupeRef);
    if (duplicate.exists) return parseStoredResult(duplicate.data()?.result);
    const now = Timestamp.now();
    const result = await applyInTransaction(firestore, transaction, caller.uid, input, now, extension);
    transaction.create(firestore.collection("moderation_private_audit").doc(auditId(caller.uid, input.requestId)), {
      action: input.action,
      targetType: input.target.targetType,
      machineId: "machineId" in input.target ? input.target.machineId : null,
      photoId: null,
      productId: input.target.targetType === "product" ? input.target.productId : null,
      targetUserId: "targetUserId" in input.target ? input.target.targetUserId : null,
      previousStatus: result.previousStatus,
      nextStatus: result.nextStatus,
      reason: input.reason,
      moderatorUid: caller.uid,
      createdAt: now,
    });
    transaction.create(dedupeRef, {uid: caller.uid, operation: APPLY_MODERATION_ACTION_OPERATION, requestId: input.requestId, status: "completed", result, createdAt: now, updatedAt: now});
    return result;
  });
}

export async function applyPreparedModerationActionForCaller(firestore: Firestore, caller: ModerationCaller, rawInput: unknown, prepare: ModerationTransactionPreparer): Promise<ApplyModerationActionResult> {
  await assertModeratorForCaller(createFirestoreModerationReadStore(firestore), caller);
  const input = parseApplyInput(rawInput);
  if (input.target.targetType !== "machine" && input.target.targetType !== "product" && input.target.targetType !== "user" && input.target.targetType !== "photo") throw new HttpsError("failed-precondition", "This moderation target is not supported.", {appCode: "moderation-queue-target-not-supported"});
  const dedupeRef = firestore.collection("request_deduplication").doc(dedupeId(caller.uid, input.requestId));
  const stored = await dedupeRef.get();
  if (stored.exists) return parseStoredResult(stored.data()?.result);
  return firestore.runTransaction(async (transaction) => {
    const duplicate = await transaction.get(dedupeRef);
    if (duplicate.exists) return parseStoredResult(duplicate.data()?.result);
    const prepared = await prepare(firestore, transaction, caller, input);
    const resolvedInput = prepared.target === undefined ? input : {...input, target: prepared.target};
    const now = Timestamp.now();
    const result = {...await applyInTransaction(firestore, transaction, caller.uid, resolvedInput, now, prepared.extension), ...prepared.resultFields} as ApplyModerationActionResult;
    if (resolvedInput.target.targetType !== "machine" && resolvedInput.target.targetType !== "product" && resolvedInput.target.targetType !== "user" && resolvedInput.target.targetType !== "photo") throw new HttpsError("failed-precondition", "This moderation target is not supported.", {appCode: "moderation-queue-target-not-supported"});
    transaction.create(firestore.collection("moderation_private_audit").doc(auditId(caller.uid, input.requestId)), {action: resolvedInput.action, targetType: resolvedInput.target.targetType, machineId: "machineId" in resolvedInput.target ? resolvedInput.target.machineId : null, photoId: resolvedInput.target.targetType === "photo" ? resolvedInput.target.photoId : null, productId: resolvedInput.target.targetType === "product" ? resolvedInput.target.productId : null, targetUserId: resolvedInput.target.targetType === "user" ? resolvedInput.target.targetUserId : null, previousStatus: result.previousStatus, nextStatus: result.nextStatus, reason: resolvedInput.reason, moderatorUid: caller.uid, createdAt: now, ...prepared.auditFields});
    transaction.create(dedupeRef, {uid: caller.uid, operation: APPLY_MODERATION_ACTION_OPERATION, requestId: input.requestId, status: "completed", result, createdAt: now, updatedAt: now});
    return result;
  });
}

export async function applyPreparedPhotoDeletionForCaller(firestore: Firestore, caller: ModerationCaller, rawInput: unknown, bucket: ModerationStorageBucket, hooks: PreparedPhotoDeletionHooks): Promise<ApplyModerationActionResult> {
  await assertModeratorForCaller(createFirestoreModerationReadStore(firestore), caller);
  const input = parseApplyInput(rawInput);
  if (input.action !== "deleted") throw new HttpsError("failed-precondition", "Photo moderation action is not supported.", {appCode: "moderation-photo-action-not-supported"});
  const dedupeRef = firestore.collection("request_deduplication").doc(dedupeId(caller.uid, input.requestId));
  const phase = await firestore.runTransaction(async (transaction) => {
    const duplicate = await transaction.get(dedupeRef);
    const target = await hooks.resolveTarget(firestore, transaction, caller, input);
    const privateRef = firestore.collection("vending_machine_private").doc(target.machineId).collection("photos").doc(target.photoId);
    const privatePhoto = await transaction.get(privateRef);
    const state: PreparedPhotoDeletionState = duplicate.exists ? privatePhoto.data()?.moderationStatus === "deleted" ? "completed" : privatePhoto.data()?.moderationStatus === "deletionPending" ? "retry" : (() => { throw targetNotFound(); })() : "initial";
    const prepared = await hooks.prepare(firestore, transaction, caller, input, target, state);
    if (prepared.target.machineId !== target.machineId || prepared.target.photoId !== target.photoId) throw targetNotFound();
    if (state === "completed") return {state, target, result: parseStoredResult(duplicate.data()?.result), prepared};
    if (state === "retry") return {state, target, result: parseStoredResult(duplicate.data()?.result), prepared};
    const publicRef = firestore.collection("vending_machines").doc(target.machineId).collection("photos").doc(target.photoId);
    const publicPhoto = await transaction.get(publicRef);
    if (!publicPhoto.exists || typeof publicPhoto.data()?.status !== "string") throw targetNotFound();
    const resolvedInput = {...input, target};
    const plan = planModerationAction(target, input.action, publicPhoto.data()!.status); assertAllowed(plan);
    const context = createModerationTransactionContext({moderatorUid: caller.uid, requestId: input.requestId, target, action: input.action, reason: input.reason, phase: "mutation", previousStatus: plan.previousStatus, nextStatus: plan.nextStatus ?? undefined});
    prepared.mutationExtension.validate(context);
    const now = Timestamp.now(); transaction.update(publicRef, {status: "inactive"}); transaction.set(privateRef, {moderationStatus: "deletionPending", moderationUpdatedAt: now}, {merge: true});
    prepared.mutationExtension.stage(context, createFirestoreModerationTransactionPort(firestore, transaction));
    const result = {...resultFor(resolvedInput, plan.previousStatus, plan.nextStatus!, false), ...prepared.resultFields} as ApplyModerationActionResult;
    transaction.create(firestore.collection("moderation_private_audit").doc(auditId(caller.uid, input.requestId)), {action: input.action, targetType: "photo", machineId: target.machineId, photoId: target.photoId, productId: null, targetUserId: null, previousStatus: plan.previousStatus, nextStatus: plan.nextStatus, reason: input.reason, moderatorUid: caller.uid, createdAt: now, ...prepared.auditFields});
    transaction.create(dedupeRef, {uid: caller.uid, operation: APPLY_MODERATION_ACTION_OPERATION, requestId: input.requestId, status: "completed", result, createdAt: now, updatedAt: now});
    return {state, target, result, prepared};
  });
  if (phase.state === "completed") return phase.result;
  try { await bucket.file(`vending_machines/${phase.target.machineId}/${phase.target.photoId}/original.jpg`).delete(); } catch (error: unknown) { if (!isMissingStorageObject(error)) throw error; }
  await finalizePreparedPhotoDeletionInTransaction(firestore, caller, {...input, target: phase.target}, phase.prepared);
  return phase.result;
}

async function applyPhotoModeration(firestore: Firestore, caller: ModerationCaller, input: ApplyInput, bucket: ModerationStorageBucket | undefined, extension: ModerationTransactionExtension, finalizeExtension: ModerationTransactionExtension): Promise<ApplyModerationActionResult> {
  if (input.target.targetType !== "photo") throw new HttpsError("failed-precondition", "Photo moderation is not available yet.", {appCode: "moderation-photo-not-supported"});
  const target = input.target;
  if (input.action !== "hidden" && input.action !== "deleted") throw new HttpsError("failed-precondition", "Photo moderation action is not supported.", {appCode: "moderation-photo-action-not-supported"});
  if (input.action === "hidden") return applyPhotoHiddenModerationInTransaction(firestore, caller, input, extension);
  if (input.action === "deleted" && bucket === undefined) throw new HttpsError("failed-precondition", "Photo storage is not configured.", {appCode: "moderation-photo-storage-unavailable"});
  const dedupeRef = firestore.collection("request_deduplication").doc(dedupeId(caller.uid, input.requestId));
  const existing = await dedupeRef.get();
  if (existing.exists) {
    const storedResult = parseStoredResult(existing.data()?.result);
    const privatePhoto = await firestore.collection("vending_machine_private").doc(target.machineId).collection("photos").doc(target.photoId).get();
    if (input.action !== "deleted" || privatePhoto.data()?.moderationStatus === "deleted") return storedResult;
  }
  const result = await firestore.runTransaction(async (transaction) => {
    const duplicate = await transaction.get(dedupeRef); if (duplicate.exists) return parseStoredResult(duplicate.data()?.result);
    const publicRef = firestore.collection("vending_machines").doc(target.machineId).collection("photos").doc(target.photoId);
    const privateRef = firestore.collection("vending_machine_private").doc(target.machineId).collection("photos").doc(target.photoId);
    const [publicPhoto] = await Promise.all([transaction.get(publicRef), transaction.get(privateRef)]); if (!publicPhoto.exists || typeof publicPhoto.data()?.status !== "string") throw targetNotFound();
    const plan = planModerationAction(target, input.action, publicPhoto.data()!.status); assertAllowed(plan);
    const context = createModerationTransactionContext({moderatorUid: caller.uid, requestId: input.requestId, target, action: input.action, reason: input.reason, phase: "mutation"});
    const plannedContext: ModerationTransactionContext = {...context, previousStatus: plan.previousStatus, nextStatus: plan.nextStatus ?? undefined};
    extension.validate(plannedContext);
    const now = Timestamp.now(); transaction.update(publicRef, {status: "inactive"}); transaction.set(privateRef, {moderationStatus: "deletionPending", moderationUpdatedAt: now}, {merge: true});
    extension.stage(plannedContext, createFirestoreModerationTransactionPort(firestore, transaction));
    const safe = resultFor(input, plan.previousStatus, plan.nextStatus!, false);
    transaction.create(firestore.collection("moderation_private_audit").doc(auditId(caller.uid, input.requestId)), {action: input.action, targetType: "photo", machineId: target.machineId, photoId: target.photoId, productId: null, targetUserId: null, previousStatus: plan.previousStatus, nextStatus: plan.nextStatus, reason: input.reason, moderatorUid: caller.uid, createdAt: now});
    transaction.create(dedupeRef, {uid: caller.uid, operation: APPLY_MODERATION_ACTION_OPERATION, requestId: input.requestId, status: "completed", result: safe, createdAt: now, updatedAt: now}); return safe;
  });
  if (input.action === "deleted") {
    try { await bucket!.file(`vending_machines/${target.machineId}/${target.photoId}/original.jpg`).delete(); } catch (error: unknown) { if (!isMissingStorageObject(error)) throw error; }
    await finalizePhotoDeletionInTransaction(firestore, caller, input, finalizeExtension);
  }
  return result;
}

async function finalizePhotoDeletionInTransaction(firestore: Firestore, caller: ModerationCaller, input: ApplyInput, extension: ModerationTransactionExtension): Promise<void> {
  if (input.target.targetType !== "photo" || input.action !== "deleted") throw targetNotFound();
  const target = input.target;
  await firestore.runTransaction(async (transaction) => {
    const privateRef = firestore.collection("vending_machine_private").doc(target.machineId).collection("photos").doc(target.photoId);
    const privatePhoto = await transaction.get(privateRef);
    if (!privatePhoto.exists || privatePhoto.data()?.moderationStatus !== "deletionPending") throw targetNotFound();
    const context = createModerationTransactionContext({moderatorUid: caller.uid, requestId: input.requestId, target, action: input.action, reason: input.reason, phase: "finalize", previousStatus: "deletionPending", nextStatus: "deleted"});
    extension.validate(context);
    transaction.set(privateRef, {moderationStatus: "deleted", deletionCompletedAt: Timestamp.now()}, {merge: true});
    extension.stage(context, createFirestoreModerationTransactionPort(firestore, transaction));
  });
}

async function finalizePreparedPhotoDeletionInTransaction(firestore: Firestore, caller: ModerationCaller, input: ApplyInput, prepared: PreparedPhotoDeletion): Promise<void> {
  if (input.target.targetType !== "photo" || input.action !== "deleted") throw targetNotFound();
  const target = input.target;
  await firestore.runTransaction(async (transaction) => {
    const privateRef = firestore.collection("vending_machine_private").doc(target.machineId).collection("photos").doc(target.photoId);
    const privatePhoto = await transaction.get(privateRef);
    if (!privatePhoto.exists || privatePhoto.data()?.moderationStatus !== "deletionPending") throw targetNotFound();
    const extension = prepared.finalizePrepare === undefined ? prepared.finalizeExtension : await prepared.finalizePrepare(firestore, transaction, caller, input, target);
    const context = createModerationTransactionContext({moderatorUid: caller.uid, requestId: input.requestId, target, action: input.action, reason: input.reason, phase: "finalize", previousStatus: "deletionPending", nextStatus: "deleted"});
    extension.validate(context);
    transaction.set(privateRef, {moderationStatus: "deleted", deletionCompletedAt: Timestamp.now()}, {merge: true});
    extension.stage(context, createFirestoreModerationTransactionPort(firestore, transaction));
  });
}

async function applyPhotoHiddenModerationInTransaction(firestore: Firestore, caller: ModerationCaller, input: ApplyInput, extension: ModerationTransactionExtension): Promise<ApplyModerationActionResult> {
  if (input.target.targetType !== "photo" || input.action !== "hidden") throw targetNotFound();
  const target = input.target;
  const dedupeRef = firestore.collection("request_deduplication").doc(dedupeId(caller.uid, input.requestId));
  const stored = await dedupeRef.get();
  if (stored.exists) return parseStoredResult(stored.data()?.result);
  return firestore.runTransaction(async (transaction) => {
    const duplicate = await transaction.get(dedupeRef);
    if (duplicate.exists) return parseStoredResult(duplicate.data()?.result);
    const publicRef = firestore.collection("vending_machines").doc(target.machineId).collection("photos").doc(target.photoId);
    const privateRef = firestore.collection("vending_machine_private").doc(target.machineId).collection("photos").doc(target.photoId);
    const [publicPhoto] = await Promise.all([transaction.get(publicRef), transaction.get(privateRef)]);
    if (!publicPhoto.exists || typeof publicPhoto.data()?.status !== "string") throw targetNotFound();
    const plan = planModerationAction(target, input.action, publicPhoto.data()!.status);
    assertAllowed(plan);
    const context = createModerationTransactionContext({moderatorUid: caller.uid, requestId: input.requestId, target, action: input.action, reason: input.reason, phase: "mutation"});
    const plannedContext: ModerationTransactionContext = {...context, previousStatus: plan.previousStatus, nextStatus: plan.nextStatus ?? undefined};
    extension.validate(plannedContext);
    const now = Timestamp.now();
    transaction.update(publicRef, {status: "inactive"});
    transaction.set(privateRef, {moderationStatus: "hidden", moderationUpdatedAt: now}, {merge: true});
    extension.stage(plannedContext, createFirestoreModerationTransactionPort(firestore, transaction));
    const safe = resultFor(input, plan.previousStatus, plan.nextStatus!, false);
    transaction.create(firestore.collection("moderation_private_audit").doc(auditId(caller.uid, input.requestId)), {action: input.action, targetType: "photo", machineId: target.machineId, photoId: target.photoId, productId: null, targetUserId: null, previousStatus: plan.previousStatus, nextStatus: plan.nextStatus, reason: input.reason, moderatorUid: caller.uid, createdAt: now});
    transaction.create(dedupeRef, {uid: caller.uid, operation: APPLY_MODERATION_ACTION_OPERATION, requestId: input.requestId, status: "completed", result: safe, createdAt: now, updatedAt: now});
    return safe;
  });
}

async function applyInTransaction(firestore: Firestore, transaction: Transaction, moderatorUid: string, input: ApplyInput, now: Timestamp, extension: ModerationTransactionExtension): Promise<ApplyModerationActionResult> {
  if (input.target.targetType === "machine") {
    const context = createModerationTransactionContext({moderatorUid, requestId: input.requestId, target: input.target, action: input.action, reason: input.reason, phase: "mutation"});
    return applyMachineModerationInTransaction(firestore, transaction, input, context, now, extension);
  }
  if (input.target.targetType === "product") {
    const context = createModerationTransactionContext({moderatorUid, requestId: input.requestId, target: input.target, action: input.action, reason: input.reason, phase: "mutation"});
    return applyProductModerationInTransaction(firestore, transaction, input, context, now, extension);
  }
  if (input.target.targetType === "photo") return applyPhotoHiddenTargetInTransaction(firestore, transaction, moderatorUid, input, now, extension);
  if (input.target.targetType !== "user") throw new HttpsError("failed-precondition", "Photo moderation is not available yet.", {appCode: "moderation-photo-not-supported"});
  const context = createModerationTransactionContext({moderatorUid, requestId: input.requestId, target: input.target, action: input.action, reason: input.reason, phase: "mutation"});
  return applyUserModerationInTransaction(firestore, transaction, input, context, now, extension);
}

async function applyPhotoHiddenTargetInTransaction(firestore: Firestore, transaction: Transaction, moderatorUid: string, input: ApplyInput, now: Timestamp, extension: ModerationTransactionExtension): Promise<ApplyModerationActionResult> {
  if (input.target.targetType !== "photo" || input.action !== "hidden") throw new HttpsError("failed-precondition", "Photo moderation action is not supported.", {appCode: "moderation-photo-action-not-supported"});
  const target = input.target;
  const publicRef = firestore.collection("vending_machines").doc(target.machineId).collection("photos").doc(target.photoId);
  const privateRef = firestore.collection("vending_machine_private").doc(target.machineId).collection("photos").doc(target.photoId);
  const [publicPhoto, privatePhoto] = await Promise.all([transaction.get(publicRef), transaction.get(privateRef)]);
  if (!publicPhoto.exists || !privatePhoto.exists || typeof publicPhoto.data()?.status !== "string") throw targetNotFound();
  const privateStatus = privatePhoto.data()?.moderationStatus;
  if (privateStatus !== undefined && privateStatus !== "active") throw targetNotFound();
  const plan = planModerationAction(target, input.action, publicPhoto.data()!.status);
  assertAllowed(plan);
  const context = createModerationTransactionContext({moderatorUid, requestId: input.requestId, target, action: input.action, reason: input.reason, phase: "mutation"});
  const plannedContext: ModerationTransactionContext = {...context, previousStatus: plan.previousStatus, nextStatus: plan.nextStatus ?? undefined};
  extension.validate(plannedContext);
  transaction.update(publicRef, {status: "inactive"});
  transaction.set(privateRef, {moderationStatus: "hidden", moderationUpdatedAt: now}, {merge: true});
  extension.stage(plannedContext, createFirestoreModerationTransactionPort(firestore, transaction));
  return resultFor(input, plan.previousStatus, plan.nextStatus!, false);
}

async function applyUserModerationInTransaction(firestore: Firestore, transaction: Transaction, input: ApplyInput, context: ModerationTransactionContext, now: Timestamp, extension: ModerationTransactionExtension): Promise<ApplyModerationActionResult> {
  if (context.target.targetType !== "user") throw targetNotFound();
  const userRef = firestore.collection("users").doc(context.target.targetUserId);
  const user = await transaction.get(userRef);
  if (!user.exists) throw targetNotFound();
  const currentStatus = user.data()?.accountStatus === undefined ? "active" : user.data()?.accountStatus;
  const plan = planModerationAction(context.target, context.action, currentStatus);
  assertAllowed(plan);
  const plannedContext: ModerationTransactionContext = {...context, previousStatus: plan.previousStatus, nextStatus: plan.nextStatus ?? undefined};
  extension.validate(plannedContext);
  transaction.set(userRef, {accountStatus: plan.nextStatus, updatedAt: now}, {merge: true});
  extension.stage(plannedContext, createFirestoreModerationTransactionPort(firestore, transaction));
  return resultFor(input, plan.previousStatus, plan.nextStatus!, false);
}

async function applyProductModerationInTransaction(firestore: Firestore, transaction: Transaction, input: ApplyInput, context: ModerationTransactionContext, now: Timestamp, extension: ModerationTransactionExtension): Promise<ApplyModerationActionResult> {
  if (context.target.targetType !== "product") throw targetNotFound();
  const target = context.target;
  const productRef = firestore.collection("vending_machines").doc(target.machineId).collection("products").doc(target.productId);
  const indexRef = firestore.collection("machine_product_index").doc(`${target.machineId}_${target.productId}`);
  const [product, index] = await Promise.all([transaction.get(productRef), transaction.get(indexRef)]);
  if (!product.exists || !index.exists || product.data()?.isActive !== true || index.data()?.isActive !== true) throw targetNotFound();
  const plan = planModerationAction(context.target, context.action, "active");
  assertAllowed(plan);
  const plannedContext: ModerationTransactionContext = {...context, previousStatus: plan.previousStatus, nextStatus: plan.nextStatus ?? undefined};
  extension.validate(plannedContext);
  transaction.update(productRef, {isActive: false, updatedAt: now});
  transaction.update(indexRef, {isActive: false, updatedAt: now});
  extension.stage(plannedContext, createFirestoreModerationTransactionPort(firestore, transaction));
  return resultFor(input, plan.previousStatus, plan.nextStatus!, true);
}

async function applyMachineModerationInTransaction(firestore: Firestore, transaction: Transaction, input: ApplyInput, context: ModerationTransactionContext, now: Timestamp, extension: ModerationTransactionExtension): Promise<ApplyModerationActionResult> {
  if (context.target.targetType !== "machine") throw targetNotFound();
  const target = context.target;
  const machineRef = firestore.collection("vending_machines").doc(target.machineId);
  const machine = await transaction.get(machineRef);
  if (!machine.exists || typeof machine.data()?.status !== "string") throw targetNotFound();
  const plan = planModerationAction(context.target, context.action, machine.data()!.status);
  assertAllowed(plan);
  const plannedContext: ModerationTransactionContext = {...context, previousStatus: plan.previousStatus, nextStatus: plan.nextStatus ?? undefined};
  extension.validate(plannedContext);
  const indexes = await transaction.get(firestore.collection("machine_product_index").where("machineId", "==", target.machineId));
  transaction.update(machineRef, {status: plan.nextStatus, updatedAt: now});
  for (const index of indexes.docs) transaction.update(index.ref, {machineStatus: plan.nextStatus, isActive: false, machineUpdatedAt: now, updatedAt: now});
  extension.stage(plannedContext, createFirestoreModerationTransactionPort(firestore, transaction));
  return resultFor(input, plan.previousStatus, plan.nextStatus!, indexes.docs.length > 0);
}

function createFirestoreModerationTransactionPort(firestore: Firestore, transaction: Transaction): ModerationTransactionPort {
  return {
    setPrivateRecord(id, value) {
      transaction.set(firestore.collection("moderation_private_transaction_extensions").doc(id), value);
    },
    setQueueRecord(sourceType, itemId, value) {
      transaction.update(firestore.collection(sourceType === "report" ? "machine_reports" : "machine_corrections").doc(itemId), value);
    },
  };
}

function parseApplyInput(value: unknown): ApplyInput {
  if (!isRecord(value) || !hasOnlyKeys(value, new Set(["requestId", "target", "action", "reason"]))) throw invalidInput();
  if (typeof value.requestId !== "string" || !UUID_V4.test(value.requestId)) throw invalidInput();
  if (typeof value.reason !== "string") throw invalidInput();
  const reason = value.reason.trim();
  if (reason.length === 0 || reason.length > MAX_REASON_LENGTH) throw invalidInput();
  try { return {requestId: value.requestId, target: parseModerationTarget(value.target), action: parseModerationAction(value.action), reason}; } catch { throw invalidInput(); }
}

function resultFor(input: ApplyInput, previousStatus: string, nextStatus: string, affectsIndex: boolean): ApplyModerationActionResult { return {ok: true, targetType: input.target.targetType, action: input.action, previousStatus, nextStatus, affectsIndex}; }
function assertAllowed(plan: ReturnType<typeof planModerationAction>): void { if (!plan.allowed || plan.nextStatus === null) throw new HttpsError("failed-precondition", "Moderation transition is not allowed.", {appCode: "moderation-transition-not-allowed"}); }
function targetNotFound(): HttpsError { return new HttpsError("not-found", "Moderation target was not found or is not mutable.", {appCode: "moderation-target-not-found"}); }
function invalidInput(): HttpsError { return new HttpsError("invalid-argument", "Moderation request is invalid.", {appCode: "invalid-moderation-action"}); }
function dedupeId(uid: string, requestId: string): string { return digest(`moderationDedupe:${uid}:${requestId}`); }
function auditId(uid: string, requestId: string): string { return digest(`moderationAudit:${uid}:${requestId}`); }
function digest(value: string): string { return createHash("sha256").update(value).digest("hex"); }
function parseStoredResult(value: unknown): ApplyModerationActionResult { if (!isRecord(value) || value.ok !== true || typeof value.targetType !== "string" || typeof value.action !== "string" || typeof value.previousStatus !== "string" || typeof value.nextStatus !== "string" || typeof value.affectsIndex !== "boolean") throw new HttpsError("internal", "Stored moderation result is invalid.", {appCode: "idempotency-record-invalid"}); return value as unknown as ApplyModerationActionResult; }
function hasOnlyKeys(value: Record<string, unknown>, allowed: ReadonlySet<string>): boolean { return Object.keys(value).every((key) => allowed.has(key)); }
function isRecord(value: unknown): value is Record<string, unknown> { return typeof value === "object" && value !== null && !Array.isArray(value); }
function isMissingStorageObject(error: unknown): boolean { return typeof error === "object" && error !== null && "code" in error && ((error as {code?: unknown}).code === 404 || (error as {code?: unknown}).code === "storage/object-not-found"); }
