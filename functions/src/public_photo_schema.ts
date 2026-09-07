export const PUBLIC_PHOTO_FIELDS = new Set(["status", "createdAt"]);
const PUBLIC_PHOTO_STATUSES = new Set(["active", "inactive"]);

export interface PublicPhotoInspection {
  readonly safe: boolean;
  readonly fields: readonly string[];
  readonly invalid: boolean;
  readonly invalidStatus: boolean;
  readonly invalidCreatedAt: boolean;
  readonly formalPathMismatch: boolean;
}

export function formalPhotoPath(machineId: string, photoId: string): string {
  return `vending_machines/${machineId}/${photoId}/original.jpg`;
}

export function inspectPublicPhoto(
  machineId: string,
  photoId: string,
  data: Record<string, unknown>,
): PublicPhotoInspection {
  const fields = Object.keys(data).filter((field) => !PUBLIC_PHOTO_FIELDS.has(field));
  const invalidStatus = typeof data.status !== "string" || !PUBLIC_PHOTO_STATUSES.has(data.status);
  const invalidCreatedAt = !isValidCreatedAt(data.createdAt);
  const path = typeof data.storagePath === "string" ? data.storagePath : null;
  return {
    safe: fields.length === 0 && !invalidStatus && !invalidCreatedAt,
    fields,
    invalid: invalidStatus || invalidCreatedAt,
    invalidStatus,
    invalidCreatedAt,
    formalPathMismatch: path !== null && path !== formalPhotoPath(machineId, photoId),
  };
}

export function auditLogEntry(
  path: string,
  inspection: PublicPhotoInspection,
): Record<string, unknown> {
  return {
    path,
    fields: inspection.fields,
    invalidStatus: inspection.invalidStatus,
    invalidCreatedAt: inspection.invalidCreatedAt,
    formalPathMismatch: inspection.formalPathMismatch,
  };
}

function isValidCreatedAt(value: unknown): boolean {
  if (value instanceof Date) return !Number.isNaN(value.getTime());
  if (typeof value === "string") return value.trim().length > 0;
  if (typeof value === "number") return Number.isFinite(value);
  return typeof value === "object" && value !== null &&
    typeof (value as {toDate?: unknown}).toDate === "function";
}
