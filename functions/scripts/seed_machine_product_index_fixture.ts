import {readFileSync} from "node:fs";
import {resolve} from "node:path";

import {initializeApp, getApps} from "firebase-admin/app";
import {GeoPoint, getFirestore, Timestamp} from "firebase-admin/firestore";

import {resolveMasterEmulatorConfig} from "./master_emulator_config";

interface IndexFixtureEntry {
  readonly id: string;
  readonly data: Record<string, unknown>;
}

interface IndexFixture {
  readonly schemaVersion: number;
  readonly entries: readonly IndexFixtureEntry[];
}

async function main(): Promise<void> {
  const config = resolveMasterEmulatorConfig();

  if (getApps().length === 0) {
    initializeApp({projectId: config.projectId});
  }

  const firestore = getFirestore();
  const fixture = readFixture();

  await clearCollection(firestore);

  for (const entry of fixture.entries) {
    await firestore
      .collection("machine_product_index")
      .doc(entry.id)
      .set(convertObject(entry.data));
  }

  console.log(
    [
      "Machine-product index fixture seeded.",
      `project=${config.projectId}`,
      `firestore=${config.firestoreHost}`,
      `entries=${fixture.entries.length}`,
    ].join(" "),
  );
}

function readFixture(): IndexFixture {
  const fixturePath = resolve(
    __dirname,
    "..",
    "..",
    "fixtures",
    "machine_product_index_fixture.json",
  );

  const parsed = JSON.parse(
    readFileSync(fixturePath, "utf8"),
  ) as IndexFixture;

  if (parsed.schemaVersion !== 1) {
    throw new Error(`Unsupported fixture schema: ${parsed.schemaVersion}`);
  }

  return parsed;
}

async function clearCollection(
  firestore: ReturnType<typeof getFirestore>,
): Promise<void> {
  const snapshot = await firestore
    .collection("machine_product_index")
    .get();

  if (snapshot.empty) {
    return;
  }

  const batch = firestore.batch();
  for (const document of snapshot.docs) {
    batch.delete(document.ref);
  }
  await batch.commit();
}

function convertObject(
  source: Record<string, unknown>,
): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(source).map(([key, value]) => [
      key,
      convertValue(key, value),
    ]),
  );
}

function convertValue(key: string, value: unknown): unknown {
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

  if (key.endsWith("At") && typeof value === "string") {
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
  console.error("Machine-product index fixture seed failed.", error);
  process.exitCode = 1;
});
