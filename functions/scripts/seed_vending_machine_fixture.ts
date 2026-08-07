import {readFileSync} from "node:fs";
import {resolve} from "node:path";

import {initializeApp, getApps} from "firebase-admin/app";
import {GeoPoint, getFirestore, Timestamp} from "firebase-admin/firestore";

import {resolveMasterEmulatorConfig} from "./master_emulator_config";

interface FixtureProduct {
  readonly id: string;
  readonly data: Record<string, unknown>;
}

interface FixtureMachine {
  readonly id: string;
  readonly data: Record<string, unknown>;
  readonly products?: readonly FixtureProduct[];
}

interface VendingMachineFixture {
  readonly schemaVersion: number;
  readonly v2Machines: readonly FixtureMachine[];
  readonly legacyMachines: readonly FixtureMachine[];
}

async function main(): Promise<void> {
  const config = resolveMasterEmulatorConfig();

  if (getApps().length === 0) {
    initializeApp({projectId: config.projectId});
  }

  const firestore = getFirestore();
  const fixture = readFixture();

  await clearVendingMachines(firestore);

  for (const machine of [
    ...fixture.v2Machines,
    ...fixture.legacyMachines,
  ]) {
    const machineRef = firestore.collection("vending_machines").doc(machine.id);
    await machineRef.set(convertObject(machine.data));

    for (const product of machine.products ?? []) {
      await machineRef
        .collection("products")
        .doc(product.id)
        .set(convertObject(product.data));
    }
  }

  console.log(
    [
      "V2 vending-machine fixture seeded.",
      `project=${config.projectId}`,
      `firestore=${config.firestoreHost}`,
      `v2=${fixture.v2Machines.length}`,
      `legacy=${fixture.legacyMachines.length}`,
    ].join(" "),
  );
}

function readFixture(): VendingMachineFixture {
  const fixturePath = resolve(
    __dirname,
    "..",
    "..",
    "fixtures",
    "vending_machine_fixture.json",
  );
  const parsed = JSON.parse(
    readFileSync(fixturePath, "utf8"),
  ) as VendingMachineFixture;

  if (parsed.schemaVersion !== 1) {
    throw new Error(`Unsupported fixture schema: ${parsed.schemaVersion}`);
  }

  return parsed;
}

async function clearVendingMachines(
  firestore: ReturnType<typeof getFirestore>,
): Promise<void> {
  const snapshot = await firestore.collection("vending_machines").get();

  for (const document of snapshot.docs) {
    const products = await document.ref.collection("products").get();
    if (!products.empty) {
      const productBatch = firestore.batch();
      for (const product of products.docs) {
        productBatch.delete(product.ref);
      }
      await productBatch.commit();
    }

    await document.ref.delete();
  }
}

function convertObject(
  source: Record<string, unknown>,
): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(source).map(([key, value]) => [key, convertValue(key, value)]),
  );
}

function convertValue(key: string, value: unknown): unknown {
  if (value === null) {
    return null;
  }

  if (
    key === "location" &&
    typeof value === "object" &&
    value !== null &&
    "latitude" in value &&
    "longitude" in value
  ) {
    const latitude = Number((value as {latitude: unknown}).latitude);
    const longitude = Number((value as {longitude: unknown}).longitude);
    return new GeoPoint(latitude, longitude);
  }

  if (
    key.endsWith("At") &&
    typeof value === "string"
  ) {
    return Timestamp.fromDate(new Date(value));
  }

  if (Array.isArray(value)) {
    return value.map((item) => {
      if (typeof item === "object" && item !== null) {
        return convertObject(item as Record<string, unknown>);
      }
      return item;
    });
  }

  if (typeof value === "object" && value !== null) {
    return convertObject(value as Record<string, unknown>);
  }

  return value;
}

void main().catch((error: unknown) => {
  console.error("V2 vending-machine fixture seed failed.", error);
  process.exitCode = 1;
});
