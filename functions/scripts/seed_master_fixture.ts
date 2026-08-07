import {readFileSync} from "node:fs";
import {resolve} from "node:path";

import {initializeApp} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";

import {resolveMasterEmulatorConfig} from "./master_emulator_config";

interface FixtureDocument {
  readonly id: string;
  readonly createdAt: string;
  readonly updatedAt: string;
  readonly [key: string]: unknown;
}

interface MasterFixture {
  readonly schemaVersion: number;
  readonly manufacturers: readonly FixtureDocument[];
  readonly products: readonly FixtureDocument[];
}

async function main(): Promise<void> {
  const config = resolveMasterEmulatorConfig();

  initializeApp({
    projectId: config.projectId,
  });

  const firestore = getFirestore();
  const fixture = readFixture();

  await replaceCollection(
    firestore,
    "manufacturers",
    fixture.manufacturers,
  );
  await replaceCollection(
    firestore,
    "products",
    fixture.products,
  );

  console.log(
    [
      "V2 master fixture seeded.",
      `project=${config.projectId}`,
      `firestore=${config.firestoreHost}`,
      `manufacturers=${fixture.manufacturers.length}`,
      `products=${fixture.products.length}`,
    ].join(" "),
  );
}

function readFixture(): MasterFixture {
  const fixturePath = resolve(
    __dirname,
    "..",
    "..",
    "fixtures",
    "master_fixture.json",
  );
  const parsed = JSON.parse(readFileSync(fixturePath, "utf8")) as MasterFixture;

  if (parsed.schemaVersion !== 1) {
    throw new Error(`Unsupported fixture schema: ${parsed.schemaVersion}`);
  }

  return parsed;
}

async function replaceCollection(
  firestore: ReturnType<typeof getFirestore>,
  collectionPath: string,
  documents: readonly FixtureDocument[],
): Promise<void> {
  const existing = await firestore.collection(collectionPath).get();

  if (!existing.empty) {
    const deleteBatch = firestore.batch();
    for (const document of existing.docs) {
      deleteBatch.delete(document.ref);
    }
    await deleteBatch.commit();
  }

  const writeBatch = firestore.batch();

  for (const document of documents) {
    const {id, createdAt, updatedAt, ...data} = document;
    writeBatch.set(
      firestore.collection(collectionPath).doc(id),
      {
        ...data,
        createdAt: Timestamp.fromDate(new Date(createdAt)),
        updatedAt: Timestamp.fromDate(new Date(updatedAt)),
      },
    );
  }

  await writeBatch.commit();
}

void main().catch((error: unknown) => {
  console.error("V2 master fixture seed failed.", error);
  process.exitCode = 1;
});
