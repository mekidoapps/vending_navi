import {inspectPublicPhoto} from "./public_photo_schema";

export type PublicPhotoMigrationPlan =
  | {readonly kind: "already-safe"}
  | {readonly kind: "manual-review"; readonly reason: "invalid-public-fields" | "formal-path-mismatch"}
  | {
    readonly kind: "migrate";
    readonly privateMetadata: Readonly<Record<string, unknown>>;
    readonly publicCleanupFields: readonly string[];
  };

export interface PublicPhotoMigrationAdapter {
  readPrivateMetadata(): Promise<Record<string, unknown> | undefined>;
  writePrivateMetadata(metadata: Readonly<Record<string, unknown>>): Promise<void>;
  cleanupPublicFields(fields: readonly string[]): Promise<void>;
}

export function planPublicPhotoMigration(
  machineId: string,
  photoId: string,
  data: Record<string, unknown>,
): PublicPhotoMigrationPlan {
  const inspection = inspectPublicPhoto(machineId, photoId, data);
  if (inspection.invalid) return {kind: "manual-review", reason: "invalid-public-fields"};
  if (inspection.formalPathMismatch) return {kind: "manual-review", reason: "formal-path-mismatch"};
  if (inspection.fields.length === 0) return {kind: "already-safe"};

  const privateMetadata: Record<string, unknown> = {};
  for (const field of inspection.fields) privateMetadata[field] = data[field];
  return {
    kind: "migrate",
    privateMetadata,
    publicCleanupFields: inspection.fields,
  };
}

export function mergePrivateMetadata(
  existing: Record<string, unknown> | undefined,
  incoming: Readonly<Record<string, unknown>>,
): Record<string, unknown> {
  return {...incoming, ...existing};
}

export async function applyPublicPhotoMigration(
  plan: PublicPhotoMigrationPlan,
  adapter: PublicPhotoMigrationAdapter,
  dryRun: boolean,
): Promise<"already-safe" | "manual-review" | "planned" | "migrated"> {
  if (plan.kind === "already-safe") return "already-safe";
  if (plan.kind === "manual-review") return "manual-review";
  if (dryRun) return "planned";

  const existing = await adapter.readPrivateMetadata();
  const merged = mergePrivateMetadata(existing, plan.privateMetadata);
  await adapter.writePrivateMetadata(merged);
  await adapter.cleanupPublicFields(plan.publicCleanupFields);
  return "migrated";
}
