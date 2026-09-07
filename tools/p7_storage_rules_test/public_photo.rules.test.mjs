import {readFile} from "node:fs/promises";
import {after, before, beforeEach, test} from "node:test";
import {assertFails, assertSucceeds, initializeTestEnvironment} from "@firebase/rules-unit-testing";
import {deleteDoc, doc, getDoc, setDoc, updateDoc} from "firebase/firestore";
import {deleteObject, getBytes, ref, uploadBytes} from "firebase/storage";

const projectId = "vendingnavi";
const bucket = "gs://vendingnavi.firebasestorage.app";
const machineId = "machine_photo_rules";
const photoId = "p_0123456789abcdef0123456789abcd";
const formalPath = `vending_machines/${machineId}/${photoId}/original.jpg`;
const tempPath = "machine_uploads/photo-owner/123e4567-e89b-42d3-a456-426614174000/original.jpg";
const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
let env;

const machine = (db, id = machineId) => doc(db, "vending_machines", id);
const photo = (db, id = machineId, pid = photoId) => doc(db, "vending_machines", id, "photos", pid);
const privatePhoto = db => doc(db, "vending_machine_private", machineId, "photos", photoId);
const seedFirestore = async (machineStatus = "active", photoStatus = "active") => env.withSecurityRulesDisabled(async c => {
  const db = c.firestore();
  await setDoc(machine(db), {status: machineStatus});
  await setDoc(photo(db), {status: photoStatus, createdAt: new Date()});
  await setDoc(privatePhoto(db), {uploadedBy: "private"});
});

const seedFormalObject = async () => env.withSecurityRulesDisabled(async c => {
  await uploadBytes(ref(c.storage(bucket), formalPath), bytes, {contentType: "image/jpeg"});
});

before(async () => {
  const [firestoreRules, storageRules] = await Promise.all([
    readFile(new URL("../../firebase/v2/firestore.rules", import.meta.url), "utf8"),
    readFile(new URL("../../firebase/v2/storage.rules", import.meta.url), "utf8"),
  ]);
  env = await initializeTestEnvironment({projectId, firestore: {host: "127.0.0.1", port: 8080, rules: firestoreRules}, storage: {host: "127.0.0.1", port: 9199, rules: storageRules}});
});
beforeEach(async () => { await env.clearFirestore(); await env.clearStorage(); });
after(async () => env.cleanup());

test("public active photo is readable by guest and auth; all client writes and private access are denied", async () => {
  await seedFirestore();
  const guest = env.unauthenticatedContext().firestore();
  const auth = env.authenticatedContext("reader").firestore();
  await assertSucceeds(getDoc(photo(guest)));
  await assertSucceeds(getDoc(photo(auth)));
  await assertFails(setDoc(photo(auth, machineId, "p_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"), {status: "active"}));
  await assertFails(updateDoc(photo(auth), {status: "inactive"}));
  await assertFails(deleteDoc(photo(auth)));
  await assertFails(getDoc(privatePhoto(guest)));
  await assertFails(getDoc(privatePhoto(auth)));
  await assertFails(setDoc(privatePhoto(auth), {uploadedBy: "forged"}));
  await assertFails(updateDoc(privatePhoto(auth), {uploadedBy: "forged"}));
  await assertFails(deleteDoc(privatePhoto(auth)));
});

test("inactive or missing public parent/photo is unreadable", async () => {
  for (const [machineStatus, photoStatus, removeParent] of [["active", "inactive", false], ["inactive", "active", false], ["active", "active", true]]) {
    await seedFirestore(machineStatus, photoStatus);
    if (removeParent) await env.withSecurityRulesDisabled(async c => deleteDoc(machine(c.firestore())));
    await assertFails(getDoc(photo(env.unauthenticatedContext().firestore())));
    await env.clearFirestore(); await env.clearStorage();
  }
});

test("formal photo reads require active public machine/photo and clients cannot write", async () => {
  await seedFirestore();
  await seedFormalObject();
  const guest = env.unauthenticatedContext().storage(bucket);
  const auth = env.authenticatedContext("reader").storage(bucket);
  await assertSucceeds(getBytes(ref(guest, formalPath)));
  await assertSucceeds(getBytes(ref(auth, formalPath)));
  await assertFails(uploadBytes(ref(auth, formalPath), bytes, {contentType: "image/jpeg"}));
  await assertFails(deleteObject(ref(auth, formalPath)));
});

test("formal read is denied for inactive or missing public metadata", async () => {
  for (const [machineStatus, photoStatus, removePhoto] of [["active", "inactive", false], ["inactive", "active", false], ["active", "active", true]]) {
    await seedFirestore(machineStatus, photoStatus);
    await seedFormalObject();
    if (removePhoto) await env.withSecurityRulesDisabled(async c => deleteDoc(photo(c.firestore())));
    await assertFails(getBytes(ref(env.unauthenticatedContext().storage(bucket), formalPath)));
    await env.clearFirestore(); await env.clearStorage();
  }
});

test("temporary upload remains owner-only", async () => {
  const owner = env.authenticatedContext("photo-owner").storage(bucket);
  await assertSucceeds(uploadBytes(ref(owner, tempPath), bytes, {contentType: "image/jpeg"}));
  await assertSucceeds(getBytes(ref(owner, tempPath)));
  await assertFails(getBytes(ref(env.authenticatedContext("other").storage(bucket), tempPath)));
  await assertFails(getBytes(ref(env.unauthenticatedContext().storage(bucket), tempPath)));
});
