import {getApp, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {applyPublicPhotoMigration, planPublicPhotoMigration} from "../src/public_photo_migration";

const execute = process.argv.includes("--execute");
const dryRun = process.argv.includes("--dry-run") || !execute;
function app() { try { return getApp(); } catch { return initializeApp(); } }

async function main(): Promise<void> {
  app(); const db = getFirestore();
  let target = 0; let safe = 0; let planned = 0; let mismatch = 0; let invalid = 0;
  const machines = await db.collection("vending_machines").get();
  for (const machine of machines.docs) {
    const photos = await machine.ref.collection("photos").get();
    for (const photo of photos.docs) {
      target += 1;
      const plan = planPublicPhotoMigration(machine.id, photo.id, photo.data());
      if (plan.kind === "already-safe") { safe += 1; continue; }
      if (plan.kind === "manual-review") {
        if (plan.reason === "invalid-public-fields") invalid += 1; else mismatch += 1;
        console.log(JSON.stringify({path: photo.ref.path, reason: plan.reason}));
        continue;
      }
      planned += 1;
      const privateRef = db.collection("vending_machine_private").doc(machine.id).collection("photos").doc(photo.id);
      await applyPublicPhotoMigration(plan, {
        async readPrivateMetadata() {
          const snapshot = await privateRef.get();
          return snapshot.exists ? snapshot.data() : undefined;
        },
        async writePrivateMetadata(metadata) { await privateRef.set(metadata, {merge: true}); },
        async cleanupPublicFields(fields) {
          const cleanup: Record<string, unknown> = {};
          for (const field of fields) cleanup[field] = FieldValue.delete();
          await photo.ref.update(cleanup);
        },
      }, dryRun);
    }
  }
  console.log(JSON.stringify({mode: dryRun ? "dry-run" : "execute", targetPhotoCount: target, alreadySafeCount: safe, migrationRequiredCount: planned, formalPathMismatchCount: mismatch, invalidStatusOrCreatedAtCount: invalid}));
}
main().catch((error: unknown) => { console.error(error instanceof Error ? error.name : "MigrationError"); process.exitCode = 1; });
