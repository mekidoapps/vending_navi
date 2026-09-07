import assert from "node:assert/strict";
import test from "node:test";
import {deleteAccountForUser} from "../src/delete_account";

type Data = Record<string, unknown>;

class FakeFirestore {
  readonly data = new Map<string, Data>();
  readonly events: string[];
  failDeletePath: string | null = null;

  constructor(events: string[]) { this.events = events; }
  collection(id: string): FakeCollection { return new FakeCollection(this, [id]); }
  collectionGroup(id: string): FakeQuery { return new FakeQuery(this, null, id, []); }
  document(parts: readonly string[]): FakeDocument { return new FakeDocument(this, [...parts]); }
  documentsIn(path: readonly string[], filters: readonly [string, unknown][]): FakeDocument[] {
    return [...this.data.keys()].map((key) => this.document(key.split("/")))
      .filter((doc) => doc.pathParts.length === path.length + 1 && doc.pathParts.slice(0, -1).join("/") === path.join("/"))
      .filter((doc) => filters.every(([field, value]) => doc.data()?.[field] === value));
  }
  documentsInGroup(id: string, filters: readonly [string, unknown][]): FakeDocument[] {
    return [...this.data.keys()].map((key) => this.document(key.split("/")))
      .filter((doc) => doc.pathParts.length >= 2 && doc.pathParts[doc.pathParts.length - 2] === id)
      .filter((doc) => filters.every(([field, value]) => doc.data()?.[field] === value));
  }
}

class FakeCollection {
  constructor(readonly firestore: FakeFirestore, readonly path: readonly string[]) {}
  doc(id: string): FakeDocument { return this.firestore.document([...this.path, id]); }
  where(field: string, _operator: "==", value: unknown): FakeQuery { return new FakeQuery(this.firestore, this.path, null, [[field, value]]); }
  async get(): Promise<{docs: FakeDocument[]; size: number}> {
    const docs = this.firestore.documentsIn(this.path, []); return {docs, size: docs.length};
  }
}

class FakeQuery {
  constructor(readonly firestore: FakeFirestore, readonly path: readonly string[] | null, readonly group: string | null, readonly filters: readonly [string, unknown][]) {}
  where(field: string, _operator: "==", value: unknown): FakeQuery { return new FakeQuery(this.firestore, this.path, this.group, [...this.filters, [field, value]]); }
  async get(): Promise<{docs: FakeDocument[]; size: number}> {
    const docs = this.path === null ? this.firestore.documentsInGroup(this.group!, this.filters) : this.firestore.documentsIn(this.path, this.filters);
    return {docs, size: docs.length};
  }
}

class FakeDocument {
  constructor(readonly firestore: FakeFirestore, readonly pathParts: readonly string[]) {}
  get path(): string { return this.pathParts.join("/"); }
  get ref(): FakeDocument { return this; }
  get exists(): boolean { return this.firestore.data.has(this.path); }
  data(): Data | undefined { return this.firestore.data.get(this.path); }
  collection(id: string): FakeCollection { return new FakeCollection(this.firestore, [...this.pathParts, id]); }
  async get(): Promise<FakeDocument> { return this; }
  async delete(): Promise<void> {
    this.firestore.events.push(`firestore:delete:${this.path}`);
    if (this.firestore.failDeletePath === this.path) throw new Error("firestore cleanup failed");
    this.firestore.data.delete(this.path);
  }
  async update(patch: Data): Promise<void> {
    this.firestore.events.push(`firestore:update:${this.path}`);
    const current = {...this.data()};
    for (const field of Object.keys(patch)) deleteNested(current, field);
    this.firestore.data.set(this.path, current);
  }
  async listCollections(): Promise<FakeCollection[]> {
    const names = new Set<string>();
    for (const path of this.firestore.data.keys()) {
      const parts = path.split("/");
      if (parts.length > this.pathParts.length + 1 && parts.slice(0, this.pathParts.length).join("/") === this.path) names.add(parts[this.pathParts.length]!);
    }
    return [...names].map((name) => this.collection(name));
  }
}

function deleteNested(data: Data, field: string): void {
  const parts = field.split("."); let target: Data = data;
  for (const part of parts.slice(0, -1)) {
    const value = target[part]; if (typeof value !== "object" || value === null || Array.isArray(value)) return;
    target = value as Data;
  }
  delete target[parts[parts.length - 1]!];
}

const asFirestore = (db: FakeFirestore) => db as unknown as import("firebase-admin/firestore").Firestore;
const deletingUid = "delete-user";
const otherUid = "other-user";

function seed(db: FakeFirestore, path: string, data: Data): void { db.data.set(path, {...data}); }

function auth(events: string[], userNotFoundAfterDelete = false) {
  let deleted = false;
  return {
    async getUser() { return {email: "delete@example.test"}; },
    async deleteUser(uid: string) {
      events.push(`auth:delete:${uid}`);
      if (deleted && userNotFoundAfterDelete) throw {code: "auth/user-not-found"};
      deleted = true;
    },
  };
}

function bucket(events: string[], fail = false) {
  return {async deleteFiles({prefix}: {prefix: string}) {
    events.push(`storage:delete:${prefix}`);
    if (fail) throw new Error("storage cleanup failed");
  }};
}

function fixture(events: string[]) {
  const db = new FakeFirestore(events);
  seed(db, `users/${deletingUid}`, {accountStatus: "active"});
  seed(db, `users/${deletingUid}/blocked_actors/a`, {actorUid: "actor-a", handle: "h_a"});
  seed(db, `users/${deletingUid}/blocked_content/c`, {machineId: "machine-a", handle: "h_c"});
  seed(db, `users/${otherUid}`, {accountStatus: "active"});
  seed(db, `users/${otherUid}/blocked_actors/delete`, {actorUid: deletingUid, handle: "h_delete"});
  seed(db, `users/${otherUid}/blocked_actors/keep`, {actorUid: "actor-b", handle: "h_keep"});
  seed(db, `users/${otherUid}/blocked_content/keep`, {machineId: "machine-b", handle: "h_content"});
  seed(db, "vending_machine_private/machine-a", {createdBy: deletingUid});
  seed(db, "vending_machine_private/machine-a/photos/photo-a", {uploadedBy: deletingUid, recognitionProvider: "vertex"});
  seed(db, "vending_machine_private/machine-a/photos/photo-b", {uploadedBy: otherUid});
  seed(db, "vending_machine_private/machine-a/photos/photo-c", {recognitionProvider: "vertex"});
  seed(db, "vending_machine_private/machine-b", {});
  seed(db, "vending_machine_private/machine-b/photos/photo-d", {uploadedBy: deletingUid});
  seed(db, "vending_machines/machine-a", {status: "active"});
  seed(db, "vending_machines/machine-a/photos/photo-a", {status: "active", createdAt: "time"});
  seed(db, "vending_machines/machine-b", {status: "active"});
  seed(db, "vending_machines/machine-b/photos/photo-d", {status: "active", createdAt: "time"});
  seed(db, "request_deduplication/delete-request", {uid: deletingUid});
  return db;
}

test("deletion removes own blocks, removes other-user actor references, and anonymizes only matching private photo attribution", async () => {
  const events: string[] = []; const db = fixture(events);
  await deleteAccountForUser(asFirestore(db), auth(events) as never, bucket(events), deletingUid);

  assert.equal(db.data.has(`users/${deletingUid}`), false);
  assert.equal(db.data.has(`users/${deletingUid}/blocked_actors/a`), false);
  assert.equal(db.data.has(`users/${deletingUid}/blocked_content/c`), false);
  assert.equal(db.data.has(`users/${otherUid}/blocked_actors/delete`), false);
  assert.deepEqual(db.data.get(`users/${otherUid}/blocked_actors/keep`), {actorUid: "actor-b", handle: "h_keep"});
  assert.deepEqual(db.data.get(`users/${otherUid}/blocked_content/keep`), {machineId: "machine-b", handle: "h_content"});
  assert.deepEqual(db.data.get("vending_machine_private/machine-a/photos/photo-a"), {recognitionProvider: "vertex"});
  assert.deepEqual(db.data.get("vending_machine_private/machine-a/photos/photo-b"), {uploadedBy: otherUid});
  assert.deepEqual(db.data.get("vending_machine_private/machine-a/photos/photo-c"), {recognitionProvider: "vertex"});
  assert.deepEqual(db.data.get("vending_machine_private/machine-b/photos/photo-d"), {});
  for (const path of ["vending_machines/machine-a/photos/photo-a", "vending_machines/machine-b/photos/photo-d"]) {
    const publicPhoto = db.data.get(path)!;
    assert.equal("uploadedBy" in publicPhoto, false);
    assert.equal("actorUid" in publicPhoto, false);
    assert.equal("uid" in publicPhoto, false);
  }
});

test("cleanup is idempotent and Auth is invoked after Firestore and temporary Storage", async () => {
  const events: string[] = []; const db = fixture(events); const fakeAuth = auth(events, true);
  await deleteAccountForUser(asFirestore(db), fakeAuth as never, bucket(events), deletingUid);
  await deleteAccountForUser(asFirestore(db), fakeAuth as never, bucket(events), deletingUid);
  const firstAuth = events.indexOf(`auth:delete:${deletingUid}`);
  assert.ok(firstAuth > events.findIndex((event) => event === `storage:delete:machine_uploads/${deletingUid}/`));
  assert.equal(db.data.has(`users/${otherUid}/blocked_actors/delete`), false);
});

test("a Firestore cleanup failure leaves Authentication intact", async () => {
  const events: string[] = []; const db = fixture(events);
  db.failDeletePath = "request_deduplication/delete-request";
  await assert.rejects(() => deleteAccountForUser(asFirestore(db), auth(events) as never, bucket(events), deletingUid), /firestore cleanup failed/);
  assert.equal(events.some((event) => event.startsWith("auth:delete:")), false);
});

test("restricted and suspended accounts receive the same block and photo attribution cleanup", async () => {
  for (const status of ["restricted", "suspended"]) {
    const events: string[] = []; const db = fixture(events);
    seed(db, `users/${deletingUid}`, {accountStatus: status});
    await deleteAccountForUser(asFirestore(db), auth(events) as never, bucket(events), deletingUid);
    assert.equal(db.data.has(`users/${otherUid}/blocked_actors/delete`), false);
    assert.equal("uploadedBy" in db.data.get("vending_machine_private/machine-a/photos/photo-a")!, false);
  }
});
