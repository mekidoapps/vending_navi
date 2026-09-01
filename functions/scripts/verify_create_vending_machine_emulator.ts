import {randomUUID} from "node:crypto";

import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

import {buildRequestDeduplicationId} from "../src/create_vending_machine_core";

interface AuthSignUpResponse {
  readonly localId: string;
  readonly idToken: string;
}

interface CallableResult {
  readonly machineId: string;
  readonly created: boolean;
  readonly duplicateCandidates: readonly string[];
}

const projectId = process.env.GCLOUD_PROJECT ?? "vendingnavi";
const firestoreHost =
  process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8080";
const authHost =
  process.env.FIREBASE_AUTH_EMULATOR_HOST ?? "127.0.0.1:9099";
const functionsHost =
  process.env.FUNCTIONS_EMULATOR_HOST ?? "127.0.0.1:5001";

process.env.FIRESTORE_EMULATOR_HOST = firestoreHost;
process.env.FIREBASE_AUTH_EMULATOR_HOST = authHost;

async function main(): Promise<void> {
  if (getApps().length === 0) {
    initializeApp({projectId});
  }

  const firestore = getFirestore();
  const manufacturer = await findActiveManufacturer(firestore);
  const auth = await createAuthUser();
  const createdMachineIds: string[] = [];
  const requestIds: string[] = [];

  try {
    const beforeCount = (
      await firestore.collection("vending_machines").get()
    ).size;

    const manufacturerRequestId = randomUUID();
    requestIds.push(manufacturerRequestId);
    const input = {
      requestId: manufacturerRequestId,
      registrationMethod: "manufacturer",
      location: {
        latitude: 35.681236,
        longitude: 139.767125,
      },
      name: null,
      manufacturerId: manufacturer.id,
      confirmedProductIds: [],
      temporaryPhotoUploadId: null,
      placeDescription: "P6-09 Emulator verification",
      installationType: "outdoor",
    };

    const first = await callCreateVendingMachine(auth.idToken, input);
    assertCallableResult(first);
    createdMachineIds.push(first.machineId);

    const afterFirstCount = (
      await firestore.collection("vending_machines").get()
    ).size;
    assert(
      afterFirstCount === beforeCount + 1,
      "First call must create exactly one vending machine.",
    );

    const machineSnapshot = await firestore
      .collection("vending_machines")
      .doc(first.machineId)
      .get();
    assert(machineSnapshot.exists, "Created machine must exist.");

    const machine = machineSnapshot.data() ?? {};
    assert(machine.schemaVersion === 2, "schemaVersion must be 2.");
    assert(
      machine.manufacturerId === manufacturer.id,
      "manufacturerId must match.",
    );
    assert(machine.manufacturerStatus === "confirmed");
    assert(machine.status === "active");
    assert(typeof machine.geohash === "string" && machine.geohash.length === 6);
    assert(
      !Object.prototype.hasOwnProperty.call(machine, "createdBy"),
      "Public machine must not expose createdBy.",
    );

    const privateMachineSnapshot = await firestore
      .collection("vending_machine_private")
      .doc(first.machineId)
      .get();

    assert(
      privateMachineSnapshot.exists,
      "Private machine metadata must exist.",
    );
    assert(
      privateMachineSnapshot.data()?.createdBy === auth.localId,
      "Private machine metadata must preserve creator UID.",
    );

    const productsSnapshot = await machineSnapshot.ref
      .collection("products")
      .get();
    const activePresetCount = await countActivePresetProducts(
      firestore,
      manufacturer.presetProductIds,
    );
    assert(
      productsSnapshot.size === activePresetCount,
      "Manufacturer inferred product count must match active presets.",
    );

    for (const product of productsSnapshot.docs) {
      const data = product.data();
      assert(data.evidenceType === "manufacturer_inferred");
      assert(data.availability === "unknown");
      assert(data.isActive === true);

      const index = await firestore
        .collection("machine_product_index")
        .doc(`${first.machineId}_${product.id}`)
        .get();
      assert(index.exists, `Index must exist for ${product.id}.`);
      assert(index.data()?.machineId === first.machineId);
    }

    const revisions = await machineSnapshot.ref.collection("revisions").get();
    assert(revisions.size === 1, "Creation must write exactly one revision.");
    assert(revisions.docs[0].data().updateType === "machineCreated");
    assert(revisions.docs[0].data().requestId === manufacturerRequestId);

    const userSnapshot = await firestore
      .collection("users")
      .doc(auth.localId)
      .get();
    assert(userSnapshot.exists, "Function must create the v2 user profile.");
    assert(
      userSnapshot.data()?.accountStatus === "active",
      "Missing accountStatus must migrate to active.",
    );

    const dedupeId = buildRequestDeduplicationId(
      auth.localId,
      manufacturerRequestId,
    );
    const dedupe = await firestore
      .collection("request_deduplication")
      .doc(dedupeId)
      .get();
    assert(dedupe.exists, "Idempotency record must exist.");
    assert(dedupe.data()?.operation === "createVendingMachine");

    const second = await callCreateVendingMachine(auth.idToken, input);
    assertCallableResult(second);
    assert(
      second.machineId === first.machineId,
      "Retry must return the first machineId.",
    );

    const afterRetryCount = (
      await firestore.collection("vending_machines").get()
    ).size;
    assert(
      afterRetryCount === afterFirstCount,
      "Retry must not create another vending machine.",
    );

    const locationRequestId = randomUUID();
    requestIds.push(locationRequestId);
    const locationOnly = await callCreateVendingMachine(auth.idToken, {
      requestId: locationRequestId,
      registrationMethod: "locationOnly",
      location: {
        latitude: 35.6815,
        longitude: 139.7674,
      },
      name: null,
      manufacturerId: null,
      confirmedProductIds: [],
      temporaryPhotoUploadId: null,
      placeDescription: null,
      installationType: "unknown",
    });
    assertCallableResult(locationOnly);
    createdMachineIds.push(locationOnly.machineId);

    const locationMachine = await firestore
      .collection("vending_machines")
      .doc(locationOnly.machineId)
      .get();
    assert(locationMachine.data()?.manufacturerId === null);
    assert(locationMachine.data()?.manufacturerStatus === "unknown");
    assert(locationMachine.data()?.dataLevel === "locationOnly");
    assert(locationMachine.data()?.name === "自販機");
    assert(
      (await locationMachine.ref.collection("products").get()).empty,
      "locationOnly must not create product documents.",
    );

    await firestore
      .collection("users")
      .doc(auth.localId)
      .set({accountStatus: "restricted"}, {merge: true});

    const restrictedResponse = await rawCallable(auth.idToken, {
      requestId: randomUUID(),
      registrationMethod: "locationOnly",
      location: {
        latitude: 35.682,
        longitude: 139.768,
      },
      name: null,
      manufacturerId: null,
      confirmedProductIds: [],
      temporaryPhotoUploadId: null,
      placeDescription: null,
      installationType: "unknown",
    });

    assert(
      restrictedResponse.error !== undefined,
      "restricted account must be rejected.",
    );

    console.log(
      [
        "P6-09 createVendingMachine emulator verification passed.",
        `manufacturer=${manufacturer.id}`,
        `inferredProducts=${activePresetCount}`,
        "idempotency=ok",
        "locationOnly=ok",
        "accountStatus=ok",
      ].join(" "),
    );
  } finally {
    await cleanup(
      firestore,
      auth.localId,
      createdMachineIds,
      requestIds,
    );
  }
}

async function findActiveManufacturer(
  firestore: ReturnType<typeof getFirestore>,
): Promise<{
  readonly id: string;
  readonly presetProductIds: readonly string[];
}> {
  const snapshot = await firestore
    .collection("manufacturers")
    .where("isActive", "==", true)
    .limit(20)
    .get();

  for (const document of snapshot.docs) {
    const rawPreset = document.data().presetProductIds;
    const presetProductIds = Array.isArray(rawPreset) ?
      rawPreset.filter(
        (item: unknown): item is string => typeof item === "string",
      ) :
      [];

    return {
      id: document.id,
      presetProductIds,
    };
  }

  throw new Error(
    "No active manufacturer master found. Run npm run seed:master first.",
  );
}

async function countActivePresetProducts(
  firestore: ReturnType<typeof getFirestore>,
  presetIds: readonly string[],
): Promise<number> {
  let count = 0;
  for (const productId of new Set(presetIds)) {
    const snapshot = await firestore.collection("products").doc(productId).get();
    if (snapshot.exists && snapshot.data()?.isActive === true) {
      count += 1;
    }
  }
  return count;
}

async function createAuthUser(): Promise<AuthSignUpResponse> {
  const email = `p609-${Date.now()}@example.test`;
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key`,
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({
        email,
        password: "P609-test-password-123!",
        returnSecureToken: true,
      }),
    },
  );

  const body = await response.json() as Partial<AuthSignUpResponse> & {
    error?: unknown;
  };

  if (
    !response.ok ||
    typeof body.localId !== "string" ||
    typeof body.idToken !== "string"
  ) {
    throw new Error(
      `Auth emulator sign-up failed: ${JSON.stringify(body.error ?? body)}`,
    );
  }

  return {
    localId: body.localId,
    idToken: body.idToken,
  };
}

async function callCreateVendingMachine(
  idToken: string,
  data: Record<string, unknown>,
): Promise<CallableResult> {
  const body = await rawCallable(idToken, data);
  if (body.error !== undefined) {
    throw new Error(
      `Callable returned an error: ${JSON.stringify(body.error)}`,
    );
  }

  const result = body.result ?? body.data;
  if (
    typeof result !== "object" ||
    result === null ||
    Array.isArray(result)
  ) {
    throw new Error(
      `Callable response has no result/data: ${JSON.stringify(body)}`,
    );
  }

  return result as CallableResult;
}

async function rawCallable(
  idToken: string,
  data: Record<string, unknown>,
): Promise<{
  readonly result?: unknown;
  readonly data?: unknown;
  readonly error?: unknown;
}> {
  const response = await fetch(
    `http://${functionsHost}/${projectId}/us-central1/createVendingMachine`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${idToken}`,
      },
      body: JSON.stringify({data}),
    },
  );

  const body = await response.json() as {
    readonly result?: unknown;
    readonly data?: unknown;
    readonly error?: unknown;
  };

  return body;
}

function assertCallableResult(
  value: CallableResult,
): asserts value is CallableResult {
  assert(typeof value.machineId === "string" && value.machineId.length > 0);
  assert(value.created === true);
  assert(Array.isArray(value.duplicateCandidates));
}

async function cleanup(
  firestore: ReturnType<typeof getFirestore>,
  uid: string,
  machineIds: readonly string[],
  requestIds: readonly string[],
): Promise<void> {
  await firestore.collection("users").doc(uid).delete().catch(() => undefined);

  for (const requestId of requestIds) {
    const dedupeId = buildRequestDeduplicationId(uid, requestId);
    await firestore
      .collection("request_deduplication")
      .doc(dedupeId)
      .delete()
      .catch(() => undefined);
  }

  for (const machineId of machineIds) {
    const machineRef = firestore.collection("vending_machines").doc(machineId);

    for (const subcollection of ["products", "revisions"]) {
      const snapshot = await machineRef.collection(subcollection).get();
      for (const document of snapshot.docs) {
        await document.ref.delete();
      }
    }

    const indexes = await firestore
      .collection("machine_product_index")
      .where("machineId", "==", machineId)
      .get();
    for (const index of indexes.docs) {
      await index.ref.delete();
    }

    await machineRef.delete().catch(() => undefined);
  }
}

function assert(condition: unknown, message = "Assertion failed."): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

void main().catch((error: unknown) => {
  console.error(
    "P6-09 createVendingMachine emulator verification failed.",
    error,
  );
  process.exitCode = 1;
});
