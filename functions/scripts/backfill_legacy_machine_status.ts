import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

const MIGRATION_REVISION = "p9-07-legacy-machine-status-v1";
const BATCH_SIZE = 400;

interface Options {
  readonly projectId: string;
  readonly apply: boolean;
  readonly allowProduction: boolean;
  readonly confirmProject: string | null;
}

async function main(): Promise<void> {
  const options = parseOptions(process.argv.slice(2));

  const emulatorHost =
    process.env.FIRESTORE_EMULATOR_HOST?.trim() ?? "";

  const isEmulator = emulatorHost.length > 0;

  if (options.apply && !isEmulator) {
    if (!options.allowProduction) {
      throw new Error(
        "Production apply requires --allow-production.",
      );
    }

    if (options.confirmProject !== options.projectId) {
      throw new Error(
        "Production apply requires " +
          `--confirm-project=${options.projectId}.`,
      );
    }
  }

  if (
    options.apply &&
    isEmulator &&
    options.confirmProject !== null &&
    options.confirmProject !== options.projectId
  ) {
    throw new Error(
      "--confirm-project does not match --project.",
    );
  }

  if (getApps().length === 0) {
    initializeApp({
      projectId: options.projectId,
    });
  }

  const firestore = getFirestore();

  const snapshot = await firestore
    .collection("vending_machines")
    .get();

  const candidates = [];
  let legacyCount = 0;
  let alreadyActiveCount = 0;
  let explicitOtherStatusCount = 0;

  for (const document of snapshot.docs) {
    const data = document.data();

    if (!isLegacyDocument(data.schemaVersion)) {
      continue;
    }

    legacyCount += 1;

    const status = normalizedString(data.status);

    if (status === "active") {
      alreadyActiveCount += 1;
      continue;
    }

    if (status !== null) {
      explicitOtherStatusCount += 1;

      console.log(
        [
          "SKIP_EXPLICIT_STATUS",
          `machineId=${document.id}`,
          `status=${status}`,
        ].join(" "),
      );

      continue;
    }

    candidates.push(document.ref);

    console.log(
      [
        options.apply ? "APPLY_CANDIDATE" : "DRY_RUN_CANDIDATE",
        `machineId=${document.id}`,
      ].join(" "),
    );
  }

  let updatedCount = 0;

  if (options.apply) {
    for (
      let offset = 0;
      offset < candidates.length;
      offset += BATCH_SIZE
    ) {
      const batch = firestore.batch();

      const chunk = candidates.slice(
        offset,
        offset + BATCH_SIZE,
      );

      for (const reference of chunk) {
        batch.update(reference, {
          status: "active",
        });
      }

      await batch.commit();
      updatedCount += chunk.length;
    }
  }

  console.log(
    [
      "LEGACY_STATUS_BACKFILL",
      `revision=${MIGRATION_REVISION}`,
      `mode=${options.apply ? "apply" : "dry-run"}`,
      `project=${options.projectId}`,
      `environment=${isEmulator ? "emulator" : "production"}`,
      `scanned=${snapshot.size}`,
      `legacy=${legacyCount}`,
      `candidates=${candidates.length}`,
      `alreadyActive=${alreadyActiveCount}`,
      `explicitOtherStatus=${explicitOtherStatusCount}`,
      `updated=${updatedCount}`,
    ].join(" "),
  );
}

function parseOptions(args: readonly string[]): Options {
  const projectArgument = args.find(
    (value) => value.startsWith("--project="),
  );

  if (projectArgument === undefined) {
    throw new Error(
      "Required argument: --project=<firebase-project-id>",
    );
  }

  const projectId =
    projectArgument.slice("--project=".length).trim();

  if (projectId.length === 0) {
    throw new Error("--project must not be empty.");
  }

  const confirmArgument = args.find(
    (value) => value.startsWith("--confirm-project="),
  );

  const confirmProject =
    confirmArgument === undefined
      ? null
      : confirmArgument
          .slice("--confirm-project=".length)
          .trim();

  return {
    projectId,
    apply: args.includes("--apply"),
    allowProduction: args.includes("--allow-production"),
    confirmProject,
  };
}

function isLegacyDocument(schemaVersion: unknown): boolean {
  if (typeof schemaVersion === "number") {
    return Number.isFinite(schemaVersion) &&
      schemaVersion < 2;
  }

  if (typeof schemaVersion === "string") {
    const parsed = Number.parseInt(
      schemaVersion.trim(),
      10,
    );

    return Number.isNaN(parsed) || parsed < 2;
  }

  return true;
}

function normalizedString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const normalized = value.trim();

  return normalized.length === 0
    ? null
    : normalized;
}

void main().catch((error: unknown) => {
  console.error(
    "Legacy vending-machine status backfill failed.",
    error instanceof Error
      ? error.message
      : "UnknownError",
  );

  process.exitCode = 1;
});
