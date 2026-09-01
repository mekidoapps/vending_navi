import {createHash} from "node:crypto";
import {execFileSync} from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import {
  applicationDefault,
  initializeApp,
} from "firebase-admin/app";
import {
  type DocumentData,
  type DocumentReference,
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";

const PROJECT_ID = "vendingnavi";
const EXPECTED_MACHINE_COUNT = 42;
const EXPECTED_AFFECTED_MACHINE_COUNT = 7;
const APPLY_CONFIRMATION =
  "PHASE_C1_LEGACY_PUBLIC_ACTOR_FIELDS";

const FIELDS = [
  "createdByName",
  "updatedBy",
  "updatedByName",
] as const;

type ActorField = typeof FIELDS[number];

interface MigrationItem {
  readonly machineId: string;
  readonly publicRef: DocumentReference;
  readonly privateRef: DocumentReference;
  readonly values: Record<ActorField, unknown>;
  readonly privateWriteRequired: boolean;
}

interface Plan {
  readonly machineCount: number;
  readonly affectedMachineCount: number;
  readonly fieldCounts: Record<ActorField, number>;
  readonly existingPrivateMetadataCount: number;
  readonly items: readonly MigrationItem[];
  readonly privateWrites: number;
  readonly conflicts: readonly string[];
  readonly state: "pre-migration" | "post-migration" | "invalid";
}

function hasOwn(
  data: DocumentData,
  key: string,
): boolean {
  return Object.prototype.hasOwnProperty.call(
    data,
    key,
  );
}

function readArg(name: string): string | null {
  const prefix = `--${name}=`;

  const arg = process.argv
    .slice(2)
    .find((value) =>
      value.startsWith(prefix),
    );

  return arg?.slice(prefix.length).trim() ?? null;
}

function sameValue(
  left: unknown,
  right: unknown,
): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}

function classifyState(
  affectedMachineCount: number,
  fieldCounts: Record<ActorField, number>,
): Plan["state"] {
  const preMigration =
    affectedMachineCount ===
      EXPECTED_AFFECTED_MACHINE_COUNT &&
    FIELDS.every(
      (field) =>
        fieldCounts[field] ===
        EXPECTED_AFFECTED_MACHINE_COUNT,
    );

  if (preMigration) {
    return "pre-migration";
  }

  const postMigration =
    affectedMachineCount === 0 &&
    FIELDS.every(
      (field) => fieldCounts[field] === 0,
    );

  if (postMigration) {
    return "post-migration";
  }

  return "invalid";
}

async function buildPlan(): Promise<Plan> {
  const db = getFirestore();

  const machines =
    await db.collection("vending_machines").get();

  const fieldCounts:
    Record<ActorField, number> = {
      createdByName: 0,
      updatedBy: 0,
      updatedByName: 0,
    };

  const items: MigrationItem[] = [];
  const conflicts: string[] = [];

  let privateWrites = 0;
  let existingPrivateMetadataCount = 0;

  for (const machineDoc of machines.docs) {
    const publicData = machineDoc.data();

    const presentFields =
      FIELDS.filter((field) =>
        hasOwn(publicData, field),
      );

    for (const field of presentFields) {
      fieldCounts[field] += 1;
    }

    const privateRef = db
      .collection("vending_machine_private")
      .doc(machineDoc.id);

    const privateSnapshot =
      await privateRef.get();

    const existingMetadata =
      privateSnapshot.data()
        ?.legacyPublicActorMetadata;

    if (
      typeof existingMetadata === "object" &&
      existingMetadata !== null &&
      !Array.isArray(existingMetadata)
    ) {
      existingPrivateMetadataCount += 1;
    }

    if (presentFields.length === 0) {
      continue;
    }

    if (!privateSnapshot.exists) {
      conflicts.push(
        `machine:${machineDoc.id}: private root is missing`,
      );
      continue;
    }

    const values =
      Object.fromEntries(
        FIELDS.map((field) => [
          field,
          publicData[field],
        ]),
      ) as Record<ActorField, unknown>;

    let privateWriteRequired = true;

    if (
      typeof existingMetadata === "object" &&
      existingMetadata !== null &&
      !Array.isArray(existingMetadata)
    ) {
      const metadata =
        existingMetadata as
          Record<string, unknown>;

      const matches =
        FIELDS.every(
          (field) =>
            sameValue(
              metadata[field],
              values[field],
            ),
        );

      if (!matches) {
        conflicts.push(
          `machine:${machineDoc.id}: existing private legacy metadata conflicts`,
        );
      } else {
        privateWriteRequired = false;
      }
    }

    if (privateWriteRequired) {
      privateWrites += 1;
    }

    items.push({
      machineId: machineDoc.id,
      publicRef: machineDoc.ref,
      privateRef,
      values,
      privateWriteRequired,
    });
  }

  const state = classifyState(
    items.length,
    fieldCounts,
  );

  if (
    machines.size !== EXPECTED_MACHINE_COUNT
  ) {
    conflicts.push(
      `machine count changed: expected=${EXPECTED_MACHINE_COUNT} actual=${machines.size}`,
    );
  }

  if (state === "invalid") {
    conflicts.push(
      "public legacy actor-field state is partial or unexpected",
    );
  }

  if (
    state === "post-migration" &&
    existingPrivateMetadataCount !==
      EXPECTED_AFFECTED_MACHINE_COUNT
  ) {
    conflicts.push(
      `post-migration private metadata count mismatch: expected=${EXPECTED_AFFECTED_MACHINE_COUNT} actual=${existingPrivateMetadataCount}`,
    );
  }

  return {
    machineCount: machines.size,
    affectedMachineCount: items.length,
    fieldCounts,
    existingPrivateMetadataCount,
    items,
    privateWrites,
    conflicts,
    state,
  };
}

function hashPlan(plan: Plan): string {
  const sensitive = plan.items
    .map((item) => ({
      machineId: item.machineId,
      values: item.values,
      privateWriteRequired:
        item.privateWriteRequired,
    }))
    .sort((a, b) =>
      a.machineId.localeCompare(
        b.machineId,
      ),
    );

  return createHash("sha256")
    .update(JSON.stringify(sensitive))
    .digest("hex");
}

function assertRuntime(
  apply: boolean,
): void {
  if (
    process.env.FIRESTORE_EMULATOR_HOST
  ) {
    throw new Error(
      "Phase C.1 production migration refuses Firestore Emulator.",
    );
  }

  if (
    readArg("project") !== PROJECT_ID
  ) {
    throw new Error(
      `Requires --project=${PROJECT_ID}.`,
    );
  }

  const ambient =
    process.env.GCLOUD_PROJECT?.trim() ||
    process.env
      .GOOGLE_CLOUD_PROJECT?.trim();

  if (
    ambient &&
    ambient !== PROJECT_ID
  ) {
    throw new Error(
      `Ambient project mismatch. expected=${PROJECT_ID}`,
    );
  }

  if (!apply) {
    return;
  }

  if (
    readArg("confirm") !==
      APPLY_CONFIRMATION
  ) {
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

function writeBackup(
  plan: Plan,
  planSha256: string,
): {
  backupPath: string;
  backupSha256: string;
} {
  if (
    plan.state !== "pre-migration" ||
    plan.conflicts.length > 0
  ) {
    throw new Error(
      "Backup requires a clean pre-migration plan.",
    );
  }

  const sourceCommit = execFileSync(
    "git",
    ["rev-parse", "HEAD"],
    {encoding: "utf8"},
  ).trim();

  const backup = {
    format:
      "VendingNavi Phase C.1 public actor backup v1",
    project: PROJECT_ID,
    sourceCommit,
    planSha256,
    backedUpAt:
      new Date().toISOString(),
    machines: plan.items.map(
      (item) => ({
        machineId: item.machineId,
        values: item.values,
      }),
    ),
  };

  const bytes = Buffer.from(
    JSON.stringify(
      backup,
      null,
      2,
    ) + "\n",
    "utf8",
  );

  const backupPath = path.join(
    os.homedir(),
    "vending_phase_c1_public_actor_backup.json",
  );

  fs.writeFileSync(
    backupPath,
    bytes,
    {mode: 0o600},
  );

  const backupSha256 =
    createHash("sha256")
      .update(bytes)
      .digest("hex");

  return {
    backupPath,
    backupSha256,
  };
}

async function applyPlan(
  plan: Plan,
  planSha256: string,
): Promise<void> {
  if (
    plan.state !== "pre-migration"
  ) {
    throw new Error(
      "Apply requires pre-migration state.",
    );
  }

  if (plan.conflicts.length > 0) {
    throw new Error(
      "Phase C.1 migration has conflicts. Apply refused.",
    );
  }

  const expectedPlanSha =
    readArg("expected-plan-sha256");

  if (
    expectedPlanSha === null ||
    !/^[0-9a-f]{64}$/.test(
      expectedPlanSha,
    ) ||
    expectedPlanSha !== planSha256
  ) {
    throw new Error(
      "Live plan SHA-256 does not match --expected-plan-sha256.",
    );
  }

  const db = getFirestore();
  const batch = db.batch();
  const now = Timestamp.now();

  for (const item of plan.items) {
    if (
      item.privateWriteRequired
    ) {
      batch.set(
        item.privateRef,
        {
          legacyPublicActorMetadata: {
            ...item.values,
            migratedAt: now,
            migrationRevision:
              "phase_c1_legacy_public_actor_v1",
          },
          updatedAt: now,
        },
        {merge: true},
      );
    }

    batch.update(
      item.publicRef,
      {
        createdByName:
          FieldValue.delete(),
        updatedBy:
          FieldValue.delete(),
        updatedByName:
          FieldValue.delete(),
      },
    );
  }

  await batch.commit();
}

async function main(): Promise<void> {
  initializeApp({
    credential: applicationDefault(),
    projectId: PROJECT_ID,
  });

  const apply =
    process.argv.includes("--apply");

  const backup =
    process.argv.includes("--backup");

  assertRuntime(apply);

  const plan = await buildPlan();
  const planSha256 = hashPlan(plan);

  const publicDocumentWrites =
    plan.items.length;

  const publicFieldDeletes =
    Object.values(
      plan.fieldCounts,
    ).reduce(
      (sum, value) =>
        sum + value,
      0,
    );

  const plannedWrites =
    publicDocumentWrites +
    plan.privateWrites;

  const summary = {
    project: PROJECT_ID,
    mode:
      apply
        ? "PRODUCTION APPLY"
        : "PRODUCTION DRY RUN",
    state: plan.state,

    machineCount:
      plan.machineCount,

    affectedMachineCount:
      plan.affectedMachineCount,

    fieldCounts:
      plan.fieldCounts,

    existingPrivateMetadataCount:
      plan.existingPrivateMetadataCount,

    privateWrites:
      plan.privateWrites,

    publicDocumentWrites,
    publicFieldDeletes,
    plannedWrites,

    conflictCount:
      plan.conflicts.length,

    conflicts:
      plan.conflicts,

    planSha256,
    valuesPrinted: false,
  };

  console.log(
    JSON.stringify(
      summary,
      null,
      2,
    ),
  );

  if (backup) {
    const backupResult =
      writeBackup(
        plan,
        planSha256,
      );

    console.log(
      JSON.stringify({
        operation:
          "PHASE_C1_BACKUP_COMPLETE",
        ...backupResult,
        valuesPrinted: false,
      }, null, 2),
    );
  }

  if (!apply) {
    return;
  }

  await applyPlan(
    plan,
    planSha256,
  );

  console.log(
    JSON.stringify({
      operation:
        "PHASE_C1_APPLY_COMPLETE",
      plannedWrites,
      publicFieldDeletes,
    }, null, 2),
  );
}

main().catch(
  (error: unknown) => {
    console.error(
      error instanceof Error
        ? error.message
        : String(error),
    );

    process.exitCode = 1;
  },
);
