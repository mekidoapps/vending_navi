import {getApp, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {auditLogEntry, inspectPublicPhoto} from "../src/public_photo_schema";

function app() { try { return getApp(); } catch { return initializeApp(); } }

async function main(): Promise<void> {
  const adminApp = app();
  const db = getFirestore();
  let scanned = 0; let safe = 0; let unsafe = 0; let pathMismatch = 0; let invalidStatus = 0; let invalidCreatedAt = 0;
  const machines = await db.collection("vending_machines").get();
  const rootPhotoFieldNames = new Set<string>();
  let machinesWithImageUrl = 0;
  let machinesWithPrimaryPhotoId = 0;
  let machinesWithBothPhotoFields = 0;
  let activeMachinesWithImageUrl = 0;
  let activeMachinesWithPrimaryPhotoId = 0;
  for (const machine of machines.docs) {
    const machineData = machine.data();
    for (const fieldName of Object.keys(machineData)) {
      if (/photo|image/i.test(fieldName)) rootPhotoFieldNames.add(fieldName);
    }
    const hasImageUrl = typeof machineData.imageUrl === "string" &&
      machineData.imageUrl.trim().length > 0;
    const hasPrimaryPhotoId = typeof machineData.primaryPhotoId === "string" &&
      machineData.primaryPhotoId.trim().length > 0;
    const isActive = machineData.status === "active";
    if (hasImageUrl) machinesWithImageUrl += 1;
    if (hasPrimaryPhotoId) machinesWithPrimaryPhotoId += 1;
    if (hasImageUrl && hasPrimaryPhotoId) machinesWithBothPhotoFields += 1;
    if (isActive && hasImageUrl) activeMachinesWithImageUrl += 1;
    if (isActive && hasPrimaryPhotoId) activeMachinesWithPrimaryPhotoId += 1;
  }
  const collectionGroupPhotos = await db.collectionGroup("photos").get();
  let vendingMachinePhotoCollectionGroupCount = 0;
  for (const photo of collectionGroupPhotos.docs) {
    if (photo.ref.parent.parent?.parent.id === "vending_machines") {
      vendingMachinePhotoCollectionGroupCount += 1;
    }
  }
  let machinesWithPhotoSubcollection = 0;
  for (const machine of machines.docs) {
    const photos = await machine.ref.collection("photos").get();
    if (!photos.empty) machinesWithPhotoSubcollection += 1;
    for (const photo of photos.docs) {
      scanned += 1;
      const data = photo.data();
      const inspection = inspectPublicPhoto(machine.id, photo.id, data);
      if (inspection.invalidStatus) invalidStatus += 1;
      if (inspection.invalidCreatedAt) invalidCreatedAt += 1;
      if (inspection.formalPathMismatch) pathMismatch += 1;
      if (inspection.safe) safe += 1; else { unsafe += 1; console.log(JSON.stringify(auditLogEntry(photo.ref.path, inspection))); }
    }
  }
  console.log(JSON.stringify({
    effectiveProjectId: adminApp.options.projectId ?? process.env.GOOGLE_CLOUD_PROJECT ?? process.env.GCLOUD_PROJECT ?? null,
    emulatorDetected: typeof process.env.FIRESTORE_EMULATOR_HOST === "string" && process.env.FIRESTORE_EMULATOR_HOST.length > 0,
    vendingMachineCount: machines.size,
    vendingMachinePhotoFieldNames: [...rootPhotoFieldNames].sort(),
    machinesWithImageUrlCount: machinesWithImageUrl,
    machinesWithPrimaryPhotoIdCount: machinesWithPrimaryPhotoId,
    machinesWithBothPhotoFieldsCount: machinesWithBothPhotoFields,
    activeMachinesWithImageUrlCount: activeMachinesWithImageUrl,
    activeMachinesWithPrimaryPhotoIdCount: activeMachinesWithPrimaryPhotoId,
    machinesWithPhotoSubcollectionCount: machinesWithPhotoSubcollection,
    photoCollectionGroupCount: collectionGroupPhotos.size,
    vendingMachinePhotoCollectionGroupCount,
    scannedPhotoCount: scanned, safePhotoCount: safe, unsafePhotoCount: unsafe,
    formalPathMismatchCount: pathMismatch, invalidStatusCount: invalidStatus, invalidCreatedAtCount: invalidCreatedAt,
  }));
}
main().catch((error: unknown) => { console.error(error instanceof Error ? error.name : "AuditError"); process.exitCode = 1; });
