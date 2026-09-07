import {getApp, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";

const PRODUCTION_BUCKET_NAME = "vendingnavi.firebasestorage.app";

function app() {
  try {
    return getApp();
  } catch {
    return initializeApp();
  }
}

function isFormalOriginalObjectPath(path: string, machineId: string): boolean {
  const escapedMachineId = machineId.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp(
    `^vending_machines/${escapedMachineId}/[^/]+/original\\.jpg$`,
  ).test(path);
}

async function main(): Promise<void> {
  const adminApp = app();
  const db = getFirestore();
  const bucket = getStorage(adminApp).bucket(PRODUCTION_BUCKET_NAME);

  let machinesWithFormalObjects = 0;
  let formalOriginalObjectCount = 0;
  let nonFormalObjectCount = 0;

  const machines = await db.collection("vending_machines").get();
  for (const machine of machines.docs) {
    const [files] = await bucket.getFiles({
      prefix: `vending_machines/${machine.id}/`,
    });
    if (files.length > 0) machinesWithFormalObjects += 1;
    for (const file of files) {
      if (isFormalOriginalObjectPath(file.name, machine.id)) {
        formalOriginalObjectCount += 1;
      } else {
        nonFormalObjectCount += 1;
      }
    }
  }

  console.log(JSON.stringify({
    effectiveProjectId:
      adminApp.options.projectId ??
      process.env.GOOGLE_CLOUD_PROJECT ??
      process.env.GCLOUD_PROJECT ??
      null,
    firestoreEmulatorDetected:
      typeof process.env.FIRESTORE_EMULATOR_HOST === "string" &&
      process.env.FIRESTORE_EMULATOR_HOST.length > 0,
    storageEmulatorDetected:
      typeof process.env.FIREBASE_STORAGE_EMULATOR_HOST === "string" &&
      process.env.FIREBASE_STORAGE_EMULATOR_HOST.length > 0,
    vendingMachineCount: machines.size,
    machinesWithFormalObjectsCount: machinesWithFormalObjects,
    formalOriginalObjectCount,
    nonFormalObjectCount,
  }));
}

function effectiveProjectId(): string | null {
  try {
    return app().options.projectId ??
      process.env.GOOGLE_CLOUD_PROJECT ??
      process.env.GCLOUD_PROJECT ??
      null;
  } catch {
    return process.env.GOOGLE_CLOUD_PROJECT ?? process.env.GCLOUD_PROJECT ?? null;
  }
}

function safeErrorCode(error: unknown): string | null {
  if (typeof error === "object" && error !== null && "code" in error) {
    const code = (error as {code?: unknown}).code;
    return typeof code === "string" || typeof code === "number" ? String(code) : null;
  }
  return null;
}

function safeErrorMessage(code: string | null): string {
  if (code === "403" || code === "storage/unauthorized") {
    return "Storage監査へのアクセスが許可されませんでした。";
  }
  if (code === "404" || code === "storage/bucket-not-found") {
    return "指定したStorage bucketを確認できませんでした。";
  }
  return "Storage監査リクエストに失敗しました。";
}

main().catch((error: unknown) => {
  const errorCode = safeErrorCode(error);
  console.error(JSON.stringify({
    errorName: error instanceof Error ? error.name : "AuditError",
    errorCode,
    safeErrorMessage: safeErrorMessage(errorCode),
    effectiveProjectId: effectiveProjectId(),
    emulatorDetected:
      (typeof process.env.FIRESTORE_EMULATOR_HOST === "string" &&
        process.env.FIRESTORE_EMULATOR_HOST.length > 0) ||
      (typeof process.env.FIREBASE_STORAGE_EMULATOR_HOST === "string" &&
        process.env.FIREBASE_STORAGE_EMULATOR_HOST.length > 0),
    effectiveBucketName: PRODUCTION_BUCKET_NAME,
  }));
  process.exitCode = 1;
});
