import {strict as assert} from "node:assert";
import {readFile} from "node:fs/promises";
import {after, before, beforeEach, test} from "node:test";
import {assertFails, assertSucceeds, initializeTestEnvironment} from "@firebase/rules-unit-testing";
import {deleteDoc, doc, getDoc, setDoc, updateDoc} from "firebase/firestore";

const PROJECT_ID = "vendingnavi";
const OWNER = "ugc-owner";
const OTHER = "ugc-other";
let testEnv;

const consent = (db, uid = OWNER) => doc(db, "users", uid, "ugc_consent", "current");
const value = {version: "2026-09-06", termsUrl: "https://vendingnavi.web.app/terms"};

before(async () => {
  const rules = await readFile(new URL("../../firebase/v2/firestore.rules", import.meta.url), "utf8");
  testEnv = await initializeTestEnvironment({projectId: PROJECT_ID, firestore: {host: "127.0.0.1", port: 8080, rules}});
});
beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async context => setDoc(consent(context.firestore()), value));
});
after(async () => testEnv.cleanup());

test("owner can read consent, but other and anonymous callers cannot", async () => {
  await assertSucceeds(getDoc(consent(testEnv.authenticatedContext(OWNER).firestore())));
  await assertFails(getDoc(consent(testEnv.authenticatedContext(OTHER).firestore())));
  await assertFails(getDoc(consent(testEnv.unauthenticatedContext().firestore())));
});

test("clients cannot create, update, or delete consent", async () => {
  const owner = testEnv.authenticatedContext(OWNER).firestore();
  await assertFails(setDoc(consent(owner, "new-user"), value));
  await assertFails(updateDoc(consent(owner), {version: "forged"}));
  await assertFails(deleteDoc(consent(owner)));
});

test("admin-style write bypasses Rules for Functions", async () => {
  await assert.doesNotReject(() => testEnv.withSecurityRulesDisabled(async context => setDoc(consent(context.firestore()), value)));
});
