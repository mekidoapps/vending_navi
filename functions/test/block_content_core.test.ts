import assert from "node:assert/strict";
import test from "node:test";
import {
  blockContentSourceForUser,
  getBlockedContentIdsForUser,
  resolveContentBlockMode,
  unblockContentSourceForUser,
} from "../src/content_blocking";

type Data = Record<string, unknown>;

class FakeFirestore {
  readonly data = new Map<string, Data>();

  collection(id: string): FakeCollection {
    return new FakeCollection(this, [id], null);
  }

  collectionGroup(id: string): FakeQuery {
    return new FakeQuery(this, null, id, []);
  }

  documentsIn(collectionPath: readonly string[], filters: readonly [string, unknown][]): FakeDocument[] {
    return [...this.data.keys()]
      .map((path) => this.document(path.split("/")))
      .filter((document) => document.parent.path.join("/") === collectionPath.join("/"))
      .filter((document) => filters.every(([field, value]) => document.data()?.[field] === value));
  }

  documentsInGroup(collectionId: string, filters: readonly [string, unknown][]): FakeDocument[] {
    return [...this.data.keys()]
      .map((path) => this.document(path.split("/")))
      .filter((document) => document.parent.id === collectionId)
      .filter((document) => filters.every(([field, value]) => document.data()?.[field] === value));
  }

  document(parts: readonly string[]): FakeDocument {
    let collection: FakeCollection | null = null;
    for (let index = 0; index < parts.length; index += 2) {
      collection = new FakeCollection(this, parts.slice(0, index + 1), index === 0 ? null : this.document(parts.slice(0, index)));
    }
    return new FakeDocument(this, [...parts], collection!);
  }
}

class FakeCollection {
  constructor(readonly firestore: FakeFirestore, readonly path: readonly string[], readonly parent: FakeDocument | null) {}
  get id(): string { return this.path[this.path.length - 1]!; }
  doc(id: string): FakeDocument { return new FakeDocument(this.firestore, [...this.path, id], this); }
  collection(id: string): FakeCollection { return this.doc(id).collection(id); }
  where(field: string, _operator: "==", value: unknown): FakeQuery { return new FakeQuery(this.firestore, this.path, null, [[field, value]]); }
  async get(): Promise<{docs: FakeDocument[]}> { return {docs: this.firestore.documentsIn(this.path, [])}; }
}

class FakeQuery {
  constructor(
    readonly firestore: FakeFirestore,
    readonly collectionPath: readonly string[] | null,
    readonly groupId: string | null,
    readonly filters: readonly [string, unknown][],
  ) {}
  where(field: string, _operator: "==", value: unknown): FakeQuery {
    return new FakeQuery(this.firestore, this.collectionPath, this.groupId, [...this.filters, [field, value]]);
  }
  async get(): Promise<{docs: FakeDocument[]}> {
    return {
      docs: this.collectionPath === null ?
        this.firestore.documentsInGroup(this.groupId!, this.filters) :
        this.firestore.documentsIn(this.collectionPath, this.filters),
    };
  }
}

class FakeDocument {
  constructor(readonly firestore: FakeFirestore, readonly pathParts: readonly string[], readonly parent: FakeCollection) {}
  get id(): string { return this.pathParts[this.pathParts.length - 1]!; }
  get path(): string { return this.pathParts.join("/"); }
  get ref(): FakeDocument { return this; }
  collection(id: string): FakeCollection { return new FakeCollection(this.firestore, [...this.pathParts, id], this); }
  data(): Data | undefined { return this.firestore.data.get(this.path); }
  async get(): Promise<{data: () => Data | undefined; exists: boolean}> {
    return {data: () => this.data(), exists: this.data() !== undefined};
  }
  async set(value: Data, options?: {merge?: boolean}): Promise<void> {
    this.firestore.data.set(this.path, options?.merge ? {...this.data(), ...value} : {...value});
  }
  async delete(): Promise<void> { this.firestore.data.delete(this.path); }
}

const firestore = () => new FakeFirestore() as unknown as import("firebase-admin/firestore").Firestore;
const asFake = (value: import("firebase-admin/firestore").Firestore) => value as unknown as FakeFirestore;
const machineId = "machine_v2_station_east";
const photoId = "p_0123456789abcdef0123456789abcd";
const actor = "actor-secret-user-id";

async function seed(document: import("firebase-admin/firestore").Firestore, path: readonly string[], data: Data): Promise<void> {
  const fake = asFake(document);
  await fake.document(path).set(data);
}

test("block mode resolves actor and content for machine, photo, product, and text with no private response", async () => {
  const actorDb = firestore();
  const contentDb = firestore();
  const productId = "product_tea_green";
  const inputs = [
    {targetType: "machine", machineId, photoId: null, productId: null},
    {targetType: "photo", machineId, photoId, productId: null},
    {targetType: "product", machineId, photoId: null, productId},
    {targetType: "text", machineId, photoId: null, productId: null},
  ] as const;

  await seed(actorDb, ["vending_machine_private", machineId], {createdBy: actor});
  await seed(actorDb, ["vending_machine_private", machineId, "photos", photoId], {uploadedBy: actor});
  await seed(actorDb, ["vending_machine_private", machineId, "products", productId], {confirmedBy: actor});

  for (const input of inputs) {
    const actorResponse = await resolveContentBlockMode(actorDb, input);
    const contentResponse = await resolveContentBlockMode(contentDb, input);
    assert.deepEqual(actorResponse, {blockMode: "actor"});
    assert.deepEqual(contentResponse, {blockMode: "content"});
    const serialized = JSON.stringify(actorResponse);
    for (const forbidden of [actor, "uid", "email", "displayName", "storagePath", "vending_machine_private"]) {
      assert.equal(serialized.includes(forbidden), false);
    }
  }
});

test("block mode uses the same actor/content outcome as the block mutation", async () => {
  const productId = "product_tea_green";
  const inputs = [
    {targetType: "machine", machineId, photoId: null, productId: null},
    {targetType: "photo", machineId, photoId, productId: null},
    {targetType: "product", machineId, photoId: null, productId},
    {targetType: "text", machineId, photoId: null, productId: null},
  ] as const;

  for (const finalCase of ["actor", "content"] as const) {
    const db = firestore();
    if (finalCase === "actor") {
      await seed(db, ["vending_machine_private", machineId], {createdBy: actor});
      await seed(db, ["vending_machine_private", machineId, "photos", photoId], {uploadedBy: actor});
      await seed(db, ["vending_machine_private", machineId, "products", productId], {confirmedBy: actor});
    }
    for (const input of inputs) {
      const mode = await resolveContentBlockMode(db, input);
      const mutation = await blockContentSourceForUser(db, `reader-${finalCase}-${input.targetType}`, input);
      assert.equal(mode.blockMode === "content", mutation.fallback);
    }
  }
});

test("block mode rejects tampered targets and has no terms or account-status gate", async () => {
  const db = firestore();
  await assert.rejects(
    () => resolveContentBlockMode(db, {targetType: "photo", machineId, photoId: null, productId: null, actorUid: actor}),
    {code: "invalid-argument"},
  );
  // This resolver deliberately has no uid or terms input. It shares the
  // existing block callable's auth/App Check/rate-limit wrapper instead.
  assert.deepEqual(
    await resolveContentBlockMode(db, {targetType: "text", machineId, photoId: null, productId: null}),
    {blockMode: "content"},
  );
});

test("machine actor is resolved from private attribution without returning its UID", async () => {
  const db = firestore();
  await seed(db, ["vending_machine_private", machineId], {createdBy: actor});
  const response = await blockContentSourceForUser(db, "reader", {targetType: "machine", machineId, photoId: null, productId: null});
  const blocked = await getBlockedContentIdsForUser(db, "reader");

  assert.deepEqual(response, {blocked: true, fallback: false});
  assert.deepEqual(blocked.machineIds, [machineId]);
  const serialized = JSON.stringify(blocked);
  assert.equal(serialized.includes(actor), false);
  assert.equal(serialized.includes("vending_machine_private"), false);
});

test("photo actor is resolved only from private photo attribution", async () => {
  const db = firestore();
  await seed(db, ["vending_machines", machineId, "photos", photoId], {status: "active"});
  await seed(db, ["vending_machine_private", machineId, "photos", photoId], {uploadedBy: actor});
  const response = await blockContentSourceForUser(db, "reader", {targetType: "photo", machineId, photoId, productId: null});

  assert.equal(response.fallback, false);
  const result = await getBlockedContentIdsForUser(db, "reader");
  assert.deepEqual(result.photoIds, [photoId]);
  assert.equal(JSON.stringify(result).includes(actor), false);
});

test("product actor is resolved from private product attribution", async () => {
  const db = firestore();
  const productId = "product_tea_green";
  await seed(db, ["vending_machines", machineId], {status: "active"});
  await seed(db, ["vending_machine_private", machineId, "products", productId], {confirmedBy: actor});
  const response = await blockContentSourceForUser(db, "reader", {targetType: "product", machineId, photoId: null, productId});

  assert.equal(response.fallback, false);
  assert.deepEqual((await getBlockedContentIdsForUser(db, "reader")).productIds, [productId]);
});

test("missing attribution falls back to safe content blocks for every target type", async () => {
  const db = firestore();
  const productId = "product_tea_green";
  const inputs = [
    {targetType: "machine", machineId, photoId: null, productId: null},
    {targetType: "photo", machineId, photoId, productId: null},
    {targetType: "product", machineId, photoId: null, productId},
    {targetType: "text", machineId, photoId: null, productId: null},
  ] as const;
  for (const input of inputs) assert.equal((await blockContentSourceForUser(db, "reader", input)).fallback, true);
  const result = await getBlockedContentIdsForUser(db, "reader");
  assert.deepEqual(result.machineIds, [machineId]);
  assert.deepEqual(result.photoIds, [photoId]);
  assert.deepEqual(result.productIds, [productId]);
  assert.equal(JSON.stringify(result).includes(actor), false);
});

test("blocked response exposes only safe IDs and a non-derived handle", async () => {
  const db = firestore();
  await seed(db, ["vending_machine_private", machineId], {createdBy: actor});
  await blockContentSourceForUser(db, "reader", {targetType: "machine", machineId, photoId: null, productId: null});
  const response = await getBlockedContentIdsForUser(db, "reader");
  const handle = response.blocks[0]?.handle;
  if (typeof handle !== "string") throw new Error("missing safe handle");
  assert.match(handle, /^h_[a-f0-9]{48}$/);
  const serialized = JSON.stringify(response);
  for (const privateValue of [actor, "email", "displayName", "blocked_actors", "vending_machine_private"]) {
    assert.equal(serialized.includes(privateValue), false);
  }
});

test("own handle unblocks without actor input; invalid, missing and other-user handles leak nothing", async () => {
  const db = firestore();
  await seed(db, ["vending_machine_private", machineId], {createdBy: actor});
  await blockContentSourceForUser(db, "reader-a", {targetType: "machine", machineId, photoId: null, productId: null});
  const handle = (await getBlockedContentIdsForUser(db, "reader-a")).blocks[0]?.handle as string;

  await assert.rejects(() => unblockContentSourceForUser(db, "reader-a", {handle: "not-a-handle"}), {code: "invalid-argument"});
  assert.deepEqual(await unblockContentSourceForUser(db, "reader-b", {handle}), {unblocked: true});
  assert.equal((await getBlockedContentIdsForUser(db, "reader-a")).blocks.length, 1);
  assert.deepEqual(await unblockContentSourceForUser(db, "reader-a", {handle: `h_${"0".repeat(48)}`}), {unblocked: true});
  assert.deepEqual(await unblockContentSourceForUser(db, "reader-a", {handle}), {unblocked: true});
  assert.equal((await getBlockedContentIdsForUser(db, "reader-a")).blocks.length, 0);
});

test("block helpers are terms-independent and keep the current restricted/suspended behavior", async () => {
  for (const uid of ["restricted-user", "suspended-user"]) {
    const db = firestore();
    await seed(db, ["users", uid], {status: uid.startsWith("restricted") ? "restricted" : "suspended"});
    const result = await blockContentSourceForUser(db, uid, {targetType: "text", machineId, photoId: null, productId: null});
    assert.deepEqual(result, {blocked: true, fallback: true});
    assert.equal((await getBlockedContentIdsForUser(db, uid)).machineIds[0], machineId);
  }
});
