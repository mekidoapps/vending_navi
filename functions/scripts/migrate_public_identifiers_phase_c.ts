import {createHash} from "node:crypto";
import {execFileSync} from "node:child_process";

import {
  applicationDefault,
  initializeApp,
} from "firebase-admin/app";
import {
  DocumentData,
  DocumentReference,
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";

const PROJECT_ID = "vendingnavi";
const EXPECTED_MACHINE_COUNT = 42;
const EXPECTED_PRODUCT_COUNT = 32;
const APPLY_CONFIRMATION = "PHASE_C_PUBLIC_IDENTIFIER_MIGRATION";

interface RootPlan {
  readonly machineId: string;
  readonly publicRef: DocumentReference;
  readonly privateRef: DocumentReference;
  readonly uid: string;
  readonly publicCreatedAt: Timestamp | null;
  readonly privateWriteRequired: boolean;
}

interface ProductPlan {
  readonly machineId: string;
  readonly productId: string;
  readonly publicRef: DocumentReference;
  readonly privateRef: DocumentReference | null;
  readonly uid: string | null;
  readonly publicConfirmedAt: Timestamp | null;
  readonly publicCreatedAt: Timestamp | null;
  readonly privateWriteRequired: boolean;
}

interface MigrationPlan {
  readonly machineCount: number;
  readonly productCount: number;
  readonly rootsWithPublicCreatedBy: number;
  readonly productsWithPublicConfirmedBy: number;
  readonly rootsToDeletePublicField: readonly RootPlan[];
  readonly productsToDeletePublicField: readonly ProductPlan[];
  readonly privateRootWrites: number;
  readonly privateProductWrites: number;
  readonly conflicts: readonly string[];
}

function hasOwn(data: DocumentData, field: string): boolean {
  return Object.prototype.hasOwnProperty.call(data, field);
}

function nonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function timestampOrNull(value: unknown): Timestamp | null {
  return value instanceof Timestamp ? value : null;
}

async function buildPlan(): Promise<MigrationPlan> {
  const db = getFirestore();
  const machineSnapshot = await db.collection("vending_machines").get();

  const roots: RootPlan[] = [];
  const products: ProductPlan[] = [];
  const conflicts: string[] = [];

  let productCount = 0;
  let rootsWithPublicCreatedBy = 0;
  let productsWithPublicConfirmedBy = 0;
  let privateRootWrites = 0;
  let privateProductWrites = 0;

  for (const machineDoc of machineSnapshot.docs) {
    const machine = machineDoc.data();
    const privateRootRef = db
      .collection("vending_machine_private")
      .doc(machineDoc.id);
    const privateRootSnapshot = await privateRootRef.get();

    if (hasOwn(machine, "createdBy")) {
      rootsWithPublicCreatedBy += 1;

      const uid = nonEmptyString(machine.createdBy);
      if (uid === null) {
        conflicts.push(
          `machine:${machineDoc.id}: public createdBy exists but is empty/invalid`,
        );
      } else {
        let privateWriteRequired = true;

        if (privateRootSnapshot.exists) {
          const privateUid =
            nonEmptyString(privateRootSnapshot.data()?.createdBy);

          if (privateUid !== uid) {
            conflicts.push(
              `machine:${machineDoc.id}: private creator conflicts with public creator`,
            );
          } else {
            privateWriteRequired = false;
          }
        }

        if (privateWriteRequired) {
          privateRootWrites += 1;
        }

        roots.push({
          machineId: machineDoc.id,
          publicRef: machineDoc.ref,
          privateRef: privateRootRef,
          uid,
          publicCreatedAt: timestampOrNull(machine.createdAt),
          privateWriteRequired,
        });
      }
    } else {
      const privateUid =
        nonEmptyString(privateRootSnapshot.data()?.createdBy);

      if (privateUid === null) {
        conflicts.push(
          `machine:${machineDoc.id}: neither public nor private creator is present`,
        );
      }
    }

    const productSnapshot =
      await machineDoc.ref.collection("products").get();

    productCount += productSnapshot.size;

    for (const productDoc of productSnapshot.docs) {
      const product = productDoc.data();

      if (!hasOwn(product, "confirmedBy")) {
        continue;
      }

      productsWithPublicConfirmedBy += 1;

      const uid = nonEmptyString(product.confirmedBy);
      let privateRef: DocumentReference | null = null;
      let privateWriteRequired = false;

      if (uid !== null) {
        privateRef = privateRootRef
          .collection("products")
          .doc(productDoc.id);

        const privateSnapshot = await privateRef.get();

        if (privateSnapshot.exists) {
          const privateUid =
            nonEmptyString(privateSnapshot.data()?.confirmedBy);

          if (privateUid !== uid) {
            conflicts.push(
              `product:${machineDoc.id}/${productDoc.id}: private confirmer conflicts with public confirmer`,
            );
          }
        } else {
          privateWriteRequired = true;
          privateProductWrites += 1;
        }
      }

      products.push({
        machineId: machineDoc.id,
        productId: productDoc.id,
        publicRef: productDoc.ref,
        privateRef,
        uid,
        publicConfirmedAt: timestampOrNull(product.confirmedAt),
        publicCreatedAt: timestampOrNull(product.createdAt),
        privateWriteRequired,
      });
    }
  }

  if (machineSnapshot.size !== EXPECTED_MACHINE_COUNT) {
    conflicts.push(
      `machine count changed: expected=${EXPECTED_MACHINE_COUNT} actual=${machineSnapshot.size}`,
    );
  }

  if (productCount !== EXPECTED_PRODUCT_COUNT) {
    conflicts.push(
      `product count changed: expected=${EXPECTED_PRODUCT_COUNT} actual=${productCount}`,
    );
  }

  return {
    machineCount: machineSnapshot.size,
    productCount,
    rootsWithPublicCreatedBy,
    productsWithPublicConfirmedBy,
    rootsToDeletePublicField: roots,
    productsToDeletePublicField: products,
    privateRootWrites,
    privateProductWrites,
    conflicts,
  };
}

function hashPlan(plan: MigrationPlan): string {
  const sensitivePlan = {
    machines: plan.rootsToDeletePublicField
      .map((item) => ({
        machineId: item.machineId,
        uid: item.uid,
        privateWriteRequired: item.privateWriteRequired,
      }))
      .sort((a, b) => a.machineId.localeCompare(b.machineId)),
    products: plan.productsToDeletePublicField
      .map((item) => ({
        machineId: item.machineId,
        productId: item.productId,
        uid: item.uid,
        privateWriteRequired: item.privateWriteRequired,
      }))
      .sort((a, b) =>
        `${a.machineId}/${a.productId}`.localeCompare(
          `${b.machineId}/${b.productId}`,
        ),
      ),
  };

  return createHash("sha256")
    .update(JSON.stringify(sensitivePlan))
    .digest("hex");
}

function readArg(name: string): string | null {
  const prefix = `--${name}=`;
  const value =
    process.argv.slice(2).find((arg) => arg.startsWith(prefix));

  return value?.slice(prefix.length).trim() ?? null;
}

function assertRuntime(apply: boolean): void {
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      "Phase C production migration refuses Firestore Emulator.",
    );
  }

  const ambient =
    process.env.GCLOUD_PROJECT?.trim() ||
    process.env.GOOGLE_CLOUD_PROJECT?.trim();

  if (ambient && ambient !== PROJECT_ID) {
    throw new Error(
      `Ambient project mismatch. expected=${PROJECT_ID}`,
    );
  }

  if (!apply) {
    return;
  }

  if (readArg("project") !== PROJECT_ID) {
    throw new Error(
      `Apply requires --project=${PROJECT_ID}.`,
    );
  }

  if (readArg("confirm") !== APPLY_CONFIRMATION) {
    throw new Error(
      `Apply requires --confirm=${APPLY_CONFIRMATION}.`,
    );
  }

  const status = execFileSync(
    "git",
    ["status", "--porcelain"],
    {encoding: "utf8"},
  ).trim();

  if (status.length > 0) {
    throw new Error(
      "Production apply requires a clean Git worktree.",
    );
  }
}

async function applyPlan(
  plan: MigrationPlan,
  planSha256: string,
): Promise<void> {
  const expectedSha = readArg("expected-plan-sha256");

  if (
    expectedSha === null ||
    !/^[0-9a-f]{64}$/.test(expectedSha) ||
    expectedSha !== planSha256
  ) {
    throw new Error(
      "Live plan SHA-256 does not match --expected-plan-sha256.",
    );
  }

  if (plan.conflicts.length > 0) {
    throw new Error(
      "Phase C migration has conflicts. Apply refused.",
    );
  }

  const db = getFirestore();
  const batch = db.batch();
  const now = Timestamp.now();

  for (const item of plan.rootsToDeletePublicField) {
    if (item.privateWriteRequired) {
      batch.set(item.privateRef, {
        machineId: item.machineId,
        createdBy: item.uid,
        createdAt: item.publicCreatedAt ?? now,
        updatedAt: now,
        migratedAt: now,
        migrationRevision: "phase_c_public_identifier_v1",
      });
    }

    batch.update(item.publicRef, {
      createdBy: FieldValue.delete(),
    });
  }

  for (const item of plan.productsToDeletePublicField) {
    if (
      item.uid !== null &&
      item.privateRef !== null &&
      item.privateWriteRequired
    ) {
      batch.set(item.privateRef, {
        productId: item.productId,
        confirmedBy: item.uid,
        confirmedAt: item.publicConfirmedAt,
        createdAt: item.publicCreatedAt ?? now,
        updatedAt: now,
        migratedAt: now,
        migrationRevision: "phase_c_public_identifier_v1",
      });
    }

    batch.update(item.publicRef, {
      confirmedBy: FieldValue.delete(),
    });
  }

  await batch.commit();
}

async function main(): Promise<void> {
  initializeApp({
    credential: applicationDefault(),
    projectId: PROJECT_ID,
  });

  const apply = process.argv.includes("--apply");
  assertRuntime(apply);

  const plan = await buildPlan();
  const planSha256 = hashPlan(plan);

  const plannedWrites =
    plan.rootsToDeletePublicField.length +
    plan.productsToDeletePublicField.length +
    plan.privateRootWrites +
    plan.privateProductWrites;

  const summary = {
    project: PROJECT_ID,
    mode: apply ? "PRODUCTION APPLY" : "PRODUCTION DRY RUN",
    machineCount: plan.machineCount,
    productCount: plan.productCount,
    rootsWithPublicCreatedBy:
      plan.rootsWithPublicCreatedBy,
    productsWithPublicConfirmedBy:
      plan.productsWithPublicConfirmedBy,
    privateRootWrites: plan.privateRootWrites,
    privateProductWrites: plan.privateProductWrites,
    publicRootFieldDeletes:
      plan.rootsToDeletePublicField.length,
    publicProductFieldDeletes:
      plan.productsToDeletePublicField.length,
    plannedWrites,
    conflictCount: plan.conflicts.length,
    conflicts: plan.conflicts,
    planSha256,
    uidValuesPrinted: false,
  };

  console.log(JSON.stringify(summary, null, 2));

  if (!apply) {
    return;
  }

  await applyPlan(plan, planSha256);

  console.log(JSON.stringify({
    operation: "PHASE_C_APPLY_COMPLETE",
    plannedWrites,
    deletes: 0,
  }, null, 2));
}

main().catch((error: unknown) => {
  console.error(
    error instanceof Error ? error.message : String(error),
  );
  process.exitCode = 1;
});
