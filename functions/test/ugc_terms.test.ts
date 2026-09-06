import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

import {acceptUgcTermsForUser, assertUgcTermsAccepted, getUgcTermsConsentForUser, UGC_TERMS_URL, UGC_TERMS_VERSION} from "../src/ugc_terms";

class FakeDocument {
  dataValue: Record<string, unknown> | undefined;
  children = new Map<string, FakeDocument>();
  collection(name: string) { return {doc: (id: string) => this.child(`${name}/${id}`)}; }
  child(key: string) { let value = this.children.get(key); if (!value) { value = new FakeDocument(); this.children.set(key, value); } return value; }
  async get() { return {data: () => this.dataValue}; }
  async set(value: Record<string, unknown>) { this.dataValue = value; }
}

class FakeFirestore {
  root = new FakeDocument();
  collection(name: string) { return {doc: (id: string) => this.root.child(`${name}/${id}`)}; }
  user(uid: string) { return this.root.child(`users/${uid}`); }
}

test("acceptUgcTerms validates the exact version and writes server-owned values", async () => {
  const firestore = new FakeFirestore();
  await assert.rejects(() => acceptUgcTermsForUser(firestore as never, "u1", "old"));
  await acceptUgcTermsForUser(firestore as never, "u1", UGC_TERMS_VERSION);
  const stored = firestore.user("u1").child("ugc_consent/current").dataValue!;
  assert.equal(stored.version, UGC_TERMS_VERSION);
  assert.equal(stored.termsUrl, UGC_TERMS_URL);
  assert.ok("acceptedAt" in stored);
});

test("restricted and suspended accounts cannot accept contribution terms", async () => {
  for (const status of ["restricted", "suspended"]) {
    const firestore = new FakeFirestore();
    firestore.user("u1").dataValue = {accountStatus: status};
    await assert.rejects(() => acceptUgcTermsForUser(firestore as never, "u1", UGC_TERMS_VERSION));
  }
});

test("consent state distinguishes missing and outdated consent", async () => {
  const firestore = new FakeFirestore();
  await assert.rejects(() => assertUgcTermsAccepted(firestore as never, "u1"), /Current contribution terms/);
  firestore.user("u1").child("ugc_consent/current").dataValue = {version: "old"};
  await assert.rejects(() => assertUgcTermsAccepted(firestore as never, "u1"), /Current contribution terms/);
  firestore.user("u1").child("ugc_consent/current").dataValue = {version: UGC_TERMS_VERSION};
  await assert.doesNotReject(() => assertUgcTermsAccepted(firestore as never, "u1"));
  assert.equal((await getUgcTermsConsentForUser(firestore as never, "u1")).accepted, true);
});

test("only public contribution callables are wired to the consent guard", () => {
  const source = readFileSync("src/index.ts", "utf8");
  for (const callable of ["createVendingMachine", "updateVendingMachineProducts", "addVendingMachinePhoto"]) {
    const section = source.slice(source.indexOf(`export const ${callable}`), source.indexOf("export const", source.indexOf(`export const ${callable}`) + 1));
    assert.match(section, /assertUgcTermsAccepted/);
  }
  for (const callable of ["recognizeVendingMachinePhoto", "submitMachineCorrection", "submitMachineReport", "deleteAccount"]) {
    const start = source.indexOf(`export const ${callable}`);
    const section = source.slice(start, source.indexOf("export const", start + 1));
    assert.doesNotMatch(section, /assertUgcTermsAccepted/);
  }
});
