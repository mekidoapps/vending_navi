import {createHash, randomBytes} from "node:crypto";
import {type DocumentData, type Firestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import {isMasterId} from "./create_vending_machine_core";

export type BlockTargetType = "machine" | "photo" | "product" | "text";
export type ContentBlockMode = "actor" | "content";
export interface BlockInput { readonly targetType: BlockTargetType; readonly machineId: string; readonly photoId: string | null; readonly productId: string | null; }
const types = new Set<BlockTargetType>(["machine", "photo", "product", "text"]);
const photoPattern = /^p_[0-9a-f]{30}$/;

export function parseBlockInput(raw: unknown): BlockInput {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) throw invalid();
  const value = raw as Record<string, unknown>;
  for (const key of Object.keys(value)) if (!["targetType", "machineId", "photoId", "productId"].includes(key)) throw invalid();
  if (typeof value.targetType !== "string" || !types.has(value.targetType as BlockTargetType)) throw invalid();
  if (typeof value.machineId !== "string" || !isMasterId(value.machineId.trim())) throw invalid();
  const photoId = nullableId(value.photoId, photoPattern);
  const productId = nullableId(value.productId, /^[a-z0-9_]{1,100}$/);
  const targetType = value.targetType as BlockTargetType;
  if (
    (targetType === "photo" && (photoId === null || productId !== null)) ||
    (targetType === "product" && (productId === null || photoId !== null)) ||
    ((targetType === "machine" || targetType === "text") &&
      (photoId !== null || productId !== null))
  ) throw invalid();
  return {targetType, machineId: value.machineId.trim(), photoId, productId};
}

export async function blockContentSourceForUser(firestore: Firestore, uid: string, raw: unknown): Promise<{readonly blocked: true; readonly fallback: boolean}> {
  const {input, actor} = await resolveContentBlockTarget(firestore, raw);
  const now = Timestamp.now(); const user = firestore.collection("users").doc(uid);
  if (actor !== null && actor !== uid) {
    await user.collection("blocked_actors").doc(opaqueId(actor)).set({actorUid: actor, handle: randomHandle(), createdAt: now});
    return {blocked: true, fallback: false};
  }
  await user.collection("blocked_content").doc(contentId(input)).set({kind: input.targetType, machineId: input.machineId, photoId: input.photoId, productId: input.productId, handle: randomHandle(), createdAt: now});
  return {blocked: true, fallback: true};
}

/**
 * Resolves only the safe presentation mode. Actor identifiers and private
 * attribution details intentionally remain inside this module.
 */
export async function resolveContentBlockMode(
  firestore: Firestore,
  raw: unknown,
): Promise<{readonly blockMode: ContentBlockMode}> {
  const {actor} = await resolveContentBlockTarget(firestore, raw);
  return {blockMode: actor === null ? "content" : "actor"};
}

export async function unblockContentSourceForUser(firestore: Firestore, uid: string, raw: unknown): Promise<{readonly unblocked: true}> {
  if (typeof raw === "object" && raw !== null && !Array.isArray(raw) && typeof (raw as Record<string, unknown>).handle === "string") {
    const handle = (raw as Record<string, unknown>).handle as string;
    if (!/^h_[a-f0-9]{48}$/.test(handle)) throw invalid();
    const user = firestore.collection("users").doc(uid);
    for (const collection of ["blocked_actors", "blocked_content"]) {
      const matches = await user.collection(collection).where("handle", "==", handle).get();
      for (const doc of matches.docs) await doc.ref.delete();
    }
    return {unblocked: true};
  }
  const input = parseBlockInput(raw); const actor = await resolveActor(firestore, input); const user = firestore.collection("users").doc(uid);
  if (actor !== null) await user.collection("blocked_actors").doc(opaqueId(actor)).delete();
  await user.collection("blocked_content").doc(contentId(input)).delete();
  return {unblocked: true};
}

export async function getBlockedContentIdsForUser(firestore: Firestore, uid: string): Promise<{readonly machineIds: readonly string[]; readonly photoIds: readonly string[]; readonly productIds: readonly string[]; readonly blocks: readonly Record<string, unknown>[]}> {
  const user = firestore.collection("users").doc(uid);
  const [actors, content] = await Promise.all([user.collection("blocked_actors").get(), user.collection("blocked_content").get()]);
  const machineIds = new Set<string>(); const photoIds = new Set<string>(); const productIds = new Set<string>();
  for (const doc of content.docs) addIds(doc.data(), machineIds, photoIds, productIds);
  // Actor identifiers never leave Functions; resolve their currently attributed content server-side.
  for (const doc of actors.docs) {
    const actor = doc.data().actorUid; if (typeof actor !== "string") continue;
    const privateMachines = await firestore.collection("vending_machine_private").where("createdBy", "==", actor).get();
    for (const machine of privateMachines.docs) machineIds.add(machine.id);
    const privatePhotos = await firestore
      .collectionGroup("photos")
      .where("uploadedBy", "==", actor)
      .get();
    for (const photo of privatePhotos.docs) {
      // Only private photo metadata is attributable. Public photo documents
      // deliberately never contain an actor field.
      if (photo.ref.parent.parent?.parent.id === "vending_machine_private") {
        photoIds.add(photo.id);
      }
    }
    const machines = await firestore.collection("vending_machines").get();
    for (const machine of machines.docs) {
      const products = await firestore.collection("vending_machine_private").doc(machine.id).collection("products").where("confirmedBy", "==", actor).get();
      for (const product of products.docs) productIds.add(product.id);
    }
  }
  const blocks: Record<string, unknown>[] = [];
  for (const doc of actors.docs) { const d = doc.data(); if (typeof d.handle === "string") blocks.push({handle: d.handle, kind: "actor", targetType: "machine"}); }
  for (const doc of content.docs) { const d = doc.data(); if (typeof d.handle === "string") blocks.push({handle: d.handle, kind: "content", targetType: d.kind, machineId: d.machineId, photoId: d.photoId, productId: d.productId}); }
  return {machineIds: [...machineIds], photoIds: [...photoIds], productIds: [...productIds], blocks};
}

async function resolveActor(firestore: Firestore, input: BlockInput): Promise<string | null> {
  const privateRef = firestore.collection("vending_machine_private").doc(input.machineId);
  if (input.targetType === "machine" || input.targetType === "text") { const snap = await privateRef.get(); return stringField(snap.data(), "createdBy"); }
  if (input.targetType === "photo" && input.photoId !== null) { const snap = await privateRef.collection("photos").doc(input.photoId).get(); return stringField(snap.data(), "uploadedBy"); }
  if (input.productId !== null) { const snap = await privateRef.collection("products").doc(input.productId).get(); return stringField(snap.data(), "confirmedBy"); }
  return null;
}

async function resolveContentBlockTarget(
  firestore: Firestore,
  raw: unknown,
): Promise<{readonly input: BlockInput; readonly actor: string | null}> {
  const input = parseBlockInput(raw);
  return {input, actor: await resolveActor(firestore, input)};
}
function addIds(data: DocumentData, machines: Set<string>, photos: Set<string>, products: Set<string>): void { if (typeof data.machineId === "string") machines.add(data.machineId); if (typeof data.photoId === "string") photos.add(data.photoId); if (typeof data.productId === "string") products.add(data.productId); }
function nullableId(value: unknown, pattern: RegExp): string | null { if (value === undefined || value === null) return null; if (typeof value !== "string" || !pattern.test(value.trim())) throw invalid(); return value.trim(); }
function stringField(data: DocumentData | undefined, field: string): string | null { const value = data?.[field]; return typeof value === "string" && value.trim().length > 0 ? value.trim() : null; }
function opaqueId(uid: string): string { return `b_${createHash("sha256").update(`blockedActor:${uid}`).digest("hex").slice(0, 30)}`; }
function contentId(input: BlockInput): string { return `c_${createHash("sha256").update(JSON.stringify(input)).digest("hex").slice(0, 30)}`; }
function randomHandle(): string { return `h_${randomBytes(24).toString("hex")}`; }
function invalid(): HttpsError { return new HttpsError("invalid-argument", "The content target is invalid.", {appCode: "invalid-content-target"}); }
