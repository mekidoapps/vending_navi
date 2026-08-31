import {strict as assert} from "node:assert";
import {readFile} from "node:fs/promises";
import {after, before, beforeEach, test} from "node:test";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  deleteObject,
  getBytes,
  ref,
  uploadBytes,
} from "firebase/storage";

const PROJECT_ID = "vendingnavi";
const BUCKET = "gs://vendingnavi.firebasestorage.app";
const STORAGE_HOST = "127.0.0.1";
const STORAGE_PORT = 9199;
const FIVE_MIB = 5 * 1024 * 1024;

const OWNER_UID = "p711-owner";
const OTHER_UID = "p711-other";
const VALID_UPLOAD_ID = "123e4567-e89b-42d3-a456-426614174000";
const SECOND_UPLOAD_ID = "550e8400-e29b-41d4-a716-446655440000";

let testEnv;

function tempPath(uid = OWNER_UID, uploadId = VALID_UPLOAD_ID) {
  return `machine_uploads/${uid}/${uploadId}/original.jpg`;
}

function jpegBytes(size = 4) {
  const bytes = new Uint8Array(size);
  if (size >= 4) {
    bytes[0] = 0xff;
    bytes[1] = 0xd8;
    bytes[size - 2] = 0xff;
    bytes[size - 1] = 0xd9;
  }
  return bytes;
}

async function ownerStorage() {
  return testEnv.authenticatedContext(OWNER_UID).storage(BUCKET);
}

async function otherStorage() {
  return testEnv.authenticatedContext(OTHER_UID).storage(BUCKET);
}

async function anonymousStorage() {
  return testEnv.unauthenticatedContext().storage(BUCKET);
}

before(async () => {
  const rules = await readFile(
    new URL("../../firebase/v2/storage.rules", import.meta.url),
    "utf8",
  );

  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    storage: {
      host: STORAGE_HOST,
      port: STORAGE_PORT,
      rules,
    },
  });
});

beforeEach(async () => {
  await testEnv.clearStorage();
});

after(async () => {
  await testEnv.cleanup();
});

test("canonical rules permit create without update or delete", async () => {
  const productionRules = await readFile(
    new URL("../../firebase/v2/storage.rules", import.meta.url),
    "utf8",
  );

  assert.match(
    productionRules,
    /allow create:\s*if isOwner\(uid\)/,
  );
  assert.doesNotMatch(
    productionRules,
    /allow update:\s*if isOwner\(uid\)/,
  );
  assert.doesNotMatch(
    productionRules,
    /allow delete:\s*if isOwner\(uid\)/,
  );
});

test("owner can create one valid JPEG in own temporary UUID path", async () => {
  const storage = await ownerStorage();
  await assertSucceeds(
    uploadBytes(
      ref(storage, tempPath()),
      jpegBytes(),
      {contentType: "image/jpeg"},
    ),
  );
});

test("unauthenticated upload is denied", async () => {
  const storage = await anonymousStorage();
  await assertFails(
    uploadBytes(
      ref(storage, tempPath()),
      jpegBytes(),
      {contentType: "image/jpeg"},
    ),
  );
});

test("authenticated user cannot upload into another user's path", async () => {
  const storage = await otherStorage();
  await assertFails(
    uploadBytes(
      ref(storage, tempPath()),
      jpegBytes(),
      {contentType: "image/jpeg"},
    ),
  );
});

test("non-JPEG content type is denied", async () => {
  const storage = await ownerStorage();
  await assertFails(
    uploadBytes(
      ref(storage, tempPath()),
      jpegBytes(),
      {contentType: "image/png"},
    ),
  );
});

test("zero-byte upload is denied", async () => {
  const storage = await ownerStorage();
  await assertFails(
    uploadBytes(
      ref(storage, tempPath()),
      new Uint8Array(0),
      {contentType: "image/jpeg"},
    ),
  );
});

test("exactly 5 MiB JPEG is allowed", async () => {
  const storage = await ownerStorage();
  await assertSucceeds(
    uploadBytes(
      ref(storage, tempPath()),
      jpegBytes(FIVE_MIB),
      {contentType: "image/jpeg"},
    ),
  );
});

test("JPEG larger than 5 MiB is denied", async () => {
  const storage = await ownerStorage();
  await assertFails(
    uploadBytes(
      ref(storage, tempPath()),
      jpegBytes(FIVE_MIB + 1),
      {contentType: "image/jpeg"},
    ),
  );
});

test("non-UUID-v4 upload folder is denied", async () => {
  const storage = await ownerStorage();
  await assertFails(
    uploadBytes(
      ref(storage, tempPath(OWNER_UID, "not-a-uuid")),
      jpegBytes(),
      {contentType: "image/jpeg"},
    ),
  );
});

test("wrong temporary filename is denied", async () => {
  const storage = await ownerStorage();
  const path =
    `machine_uploads/${OWNER_UID}/${VALID_UPLOAD_ID}/camera.jpg`;
  await assertFails(
    uploadBytes(
      ref(storage, path),
      jpegBytes(),
      {contentType: "image/jpeg"},
    ),
  );
});

test("owner can read own temporary JPEG", async () => {
  const storage = await ownerStorage();
  const objectRef = ref(storage, tempPath());

  await assertSucceeds(
    uploadBytes(
      objectRef,
      jpegBytes(),
      {contentType: "image/jpeg"},
    ),
  );
  const bytes = await assertSucceeds(getBytes(objectRef));
  assert.equal(bytes.byteLength, 4);
});

test("other authenticated user cannot read owner's temporary JPEG", async () => {
  const owner = await ownerStorage();
  const other = await otherStorage();

  await assertSucceeds(
    uploadBytes(
      ref(owner, tempPath()),
      jpegBytes(),
      {contentType: "image/jpeg"},
    ),
  );
  await assertFails(getBytes(ref(other, tempPath())));
});

test.skip(
  "overwrite immutability: Storage Emulator treats a second upload as create",
  () => {},
);

test("owner cannot delete temporary JPEG; server owns cleanup", async () => {
  const storage = await ownerStorage();
  const objectRef = ref(storage, tempPath());

  await assertSucceeds(
    uploadBytes(
      objectRef,
      jpegBytes(),
      {contentType: "image/jpeg"},
    ),
  );
  await assertFails(deleteObject(objectRef));
});

test("a second UUID upload folder can be created for retake", async () => {
  const storage = await ownerStorage();

  await assertSucceeds(
    uploadBytes(
      ref(storage, tempPath(OWNER_UID, VALID_UPLOAD_ID)),
      jpegBytes(),
      {contentType: "image/jpeg"},
    ),
  );
  await assertSucceeds(
    uploadBytes(
      ref(storage, tempPath(OWNER_UID, SECOND_UPLOAD_ID)),
      jpegBytes(),
      {contentType: "image/jpeg"},
    ),
  );
});

test("formal vending-machine photo writes remain denied", async () => {
  const storage = await ownerStorage();
  await assertFails(
    uploadBytes(
      ref(
        storage,
        "vending_machines/machine-1/photo-1/original.jpg",
      ),
      jpegBytes(),
      {contentType: "image/jpeg"},
    ),
  );
});

test("formal vending-machine photo reads remain denied at P7-11", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const storage = context.storage(BUCKET);
    await uploadBytes(
      ref(
        storage,
        "vending_machines/machine-1/photo-1/original.jpg",
      ),
      jpegBytes(),
      {contentType: "image/jpeg"},
    );
  });

  const storage = await ownerStorage();
  await assertFails(
    getBytes(
      ref(
        storage,
        "vending_machines/machine-1/photo-1/original.jpg",
      ),
    ),
  );
});
