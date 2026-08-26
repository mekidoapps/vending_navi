import {readFileSync} from "node:fs";
import {resolve} from "node:path";

import {initializeApp} from "firebase-admin/app";
import {
  DocumentData,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";

const EXPECTED_PROJECT_ID = "vendingnavi";

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

interface PlannedWrite {
  readonly collection: "manufacturers" | "products";
  readonly id: string;
  readonly type: "create" | "update";
  readonly data: Readonly<Record<string, unknown>>;
}

async function main(): Promise<void> {
  refuseEmulator();

  const projectId = readRequiredProjectArgument();

  if (projectId !== EXPECTED_PROJECT_ID) {
    throw new Error(
      `Refusing production master sync for project=${projectId}. ` +
        `Expected ${EXPECTED_PROJECT_ID}.`,
    );
  }

  const apply = process.argv.includes("--apply");

  process.env.GCLOUD_PROJECT = projectId;
  process.env.GOOGLE_CLOUD_PROJECT = projectId;

  initializeApp({projectId});

  const firestore = getFirestore();
  const fixture = readFixture();

  validateFixture(fixture);

  console.log(
    [
      "P11_PRODUCTION_MASTER_SYNC",
      `project=${projectId}`,
      `mode=${apply ? "APPLY" : "DRY_RUN"}`,
      `manufacturers=${fixture.manufacturers.length}`,
      `products=${fixture.products.length}`,
    ].join(" "),
  );

  const writes: PlannedWrite[] = [];

  const manufacturerResult = await planCollection(
    firestore,
    "manufacturers",
    fixture.manufacturers,
    writes,
  );

  const productResult = await planCollection(
    firestore,
    "products",
    fixture.products,
    writes,
  );

  console.log("");
  console.log("PLAN SUMMARY");
  console.log(
    [
      `manufacturers.create=${manufacturerResult.create}`,
      `manufacturers.update=${manufacturerResult.update}`,
      `manufacturers.unchanged=${manufacturerResult.unchanged}`,
      `manufacturers.extra=${manufacturerResult.extra}`,
    ].join(" "),
  );
  console.log(
    [
      `products.create=${productResult.create}`,
      `products.update=${productResult.update}`,
      `products.unchanged=${productResult.unchanged}`,
      `products.extra=${productResult.extra}`,
    ].join(" "),
  );
  console.log(`writes.total=${writes.length}`);
  console.log("deletes=0");

  if (writes.length > 0) {
    console.log("");
    console.log("PLANNED WRITES");

    for (const write of writes) {
      console.log(`${write.type} ${write.collection}/${write.id}`);
    }
  }

  if (!apply) {
    console.log("");
    console.log(
      "DRY_RUN_COMPLETE no Firestore documents were modified.",
    );
    return;
  }

  if (writes.length === 0) {
    console.log("");
    console.log("APPLY_COMPLETE no changes required.");
    return;
  }

  const batch = firestore.batch();
  const now = Timestamp.now();

  for (const write of writes) {
    const reference = firestore
      .collection(write.collection)
      .doc(write.id);

    if (write.type === "create") {
      const fixtureDocument = fixtureDocumentById(
        fixture,
        write.collection,
        write.id,
      );

      batch.set(reference, {
        ...write.data,
        createdAt: Timestamp.fromDate(
          new Date(fixtureDocument.createdAt),
        ),
        updatedAt: now,
      });
      continue;
    }

    batch.update(reference, {
      ...write.data,
      updatedAt: now,
    });
  }

  await batch.commit();

  console.log("");
  console.log(
    `APPLY_COMPLETE writes=${writes.length} deletes=0`,
  );
}

async function planCollection(
  firestore: ReturnType<typeof getFirestore>,
  collection:
    | "manufacturers"
    | "products",
  fixtureDocuments: readonly FixtureDocument[],
  writes: PlannedWrite[],
): Promise<{
  readonly create: number;
  readonly update: number;
  readonly unchanged: number;
  readonly extra: number;
}> {
  const snapshot = await firestore.collection(collection).get();

  const existingById = new Map(
    snapshot.docs.map((document) => [
      document.id,
      document.data(),
    ]),
  );

  let create = 0;
  let update = 0;
  let unchanged = 0;

  for (const fixtureDocument of fixtureDocuments) {
    const existing = existingById.get(fixtureDocument.id);
    const desired = writableData(fixtureDocument);

    if (existing === undefined) {
      create += 1;
      writes.push({
        collection,
        id: fixtureDocument.id,
        type: "create",
        data: desired,
      });
      continue;
    }

    if (!masterDataEquals(existing, desired)) {
      update += 1;
      writes.push({
        collection,
        id: fixtureDocument.id,
        type: "update",
        data: desired,
      });
      continue;
    }

    unchanged += 1;
  }

  const fixtureIds = new Set(
    fixtureDocuments.map((document) => document.id),
  );

  const extras = snapshot.docs
    .map((document) => document.id)
    .filter((id) => !fixtureIds.has(id))
    .sort();

  if (extras.length > 0) {
    console.log("");
    console.log(
      `EXTRA ${collection} documents preserved:`,
    );
    for (const id of extras) {
      console.log(`preserve ${collection}/${id}`);
    }
  }

  return {
    create,
    update,
    unchanged,
    extra: extras.length,
  };
}

function writableData(
  document: FixtureDocument,
): Readonly<Record<string, unknown>> {
  const {
    id: _id,
    createdAt: _createdAt,
    updatedAt: _updatedAt,
    ...data
  } = document;

  return data;
}

function masterDataEquals(
  existing: DocumentData,
  desired: Readonly<Record<string, unknown>>,
): boolean {
  for (const [key, desiredValue] of Object.entries(desired)) {
    if (!valuesEqual(existing[key], desiredValue)) {
      return false;
    }
  }

  return true;
}

function valuesEqual(
  left: unknown,
  right: unknown,
): boolean {
  if (Array.isArray(left) && Array.isArray(right)) {
    if (left.length !== right.length) {
      return false;
    }

    return left.every(
      (value, index) => valuesEqual(value, right[index]),
    );
  }

  if (
    left !== null &&
    right !== null &&
    typeof left === "object" &&
    typeof right === "object"
  ) {
    const leftObject = left as Record<string, unknown>;
    const rightObject = right as Record<string, unknown>;
    const leftKeys = Object.keys(leftObject).sort();
    const rightKeys = Object.keys(rightObject).sort();

    if (!valuesEqual(leftKeys, rightKeys)) {
      return false;
    }

    return leftKeys.every(
      (key) =>
        valuesEqual(leftObject[key], rightObject[key]),
    );
  }

  return left === right;
}

function readFixture(): MasterFixture {
  const path = resolve(
    __dirname,
    "..",
    "..",
    "fixtures",
    "master_fixture.json",
  );

  return JSON.parse(
    readFileSync(path, "utf8"),
  ) as MasterFixture;
}

function validateFixture(
  fixture: MasterFixture,
): void {
  if (fixture.schemaVersion !== 1) {
    throw new Error(
      `Unsupported fixture schema=${fixture.schemaVersion}.`,
    );
  }

  if (fixture.manufacturers.length !== 7) {
    throw new Error(
      `Unexpected manufacturer count=${fixture.manufacturers.length}.`,
    );
  }

  if (fixture.products.length !== 96) {
    throw new Error(
      `Unexpected product count=${fixture.products.length}.`,
    );
  }

  assertUniqueIds(
    fixture.manufacturers,
    "manufacturer",
  );

  assertUniqueIds(
    fixture.products,
    "product",
  );

  const productIds = new Set(
    fixture.products.map((product) => product.id),
  );

  let presetTotal = 0;

  for (const manufacturer of fixture.manufacturers) {
    const rawPreset = manufacturer.presetProductIds;

    if (!Array.isArray(rawPreset)) {
      throw new Error(
        `${manufacturer.id}: presetProductIds must be an array.`,
      );
    }

    for (const value of rawPreset) {
      if (
        typeof value !== "string" ||
        !productIds.has(value)
      ) {
        throw new Error(
          `${manufacturer.id}: invalid preset Product ID.`,
        );
      }

      presetTotal += 1;
    }
  }

  if (presetTotal !== 33) {
    throw new Error(
      `Unexpected preset product count=${presetTotal}.`,
    );
  }
}

function assertUniqueIds(
  documents: readonly FixtureDocument[],
  label: string,
): void {
  const ids = new Set<string>();

  for (const document of documents) {
    if (!ids.add(document.id)) {
      throw new Error(
        `Duplicate ${label} ID=${document.id}.`,
      );
    }
  }
}

function fixtureDocumentById(
  fixture: MasterFixture,
  collection: "manufacturers" | "products",
  id: string,
): FixtureDocument {
  const documents =
    collection === "manufacturers" ?
      fixture.manufacturers :
      fixture.products;

  const document = documents.find(
    (candidate) => candidate.id === id,
  );

  if (document === undefined) {
    throw new Error(
      `Fixture document not found: ${collection}/${id}`,
    );
  }

  return document;
}

function readRequiredProjectArgument(): string {
  const prefix = "--project=";
  const argument = process.argv.find(
    (value) => value.startsWith(prefix),
  );

  const projectId = argument
    ?.slice(prefix.length)
    .trim();

  if (!projectId) {
    throw new Error(
      "Explicit --project=<projectId> is required.",
    );
  }

  return projectId;
}

function refuseEmulator(): void {
  const host =
    process.env.FIRESTORE_EMULATOR_HOST?.trim();

  if (host) {
    throw new Error(
      `Refusing production sync while ` +
        `FIRESTORE_EMULATOR_HOST=${host}.`,
    );
  }
}

void main().catch((error: unknown) => {
  console.error(
    "P11 production master sync failed.",
    error,
  );
  process.exitCode = 1;
});
