import {buildFormalPhotoStoragePath} from "./photo_recognition/photo_registration_finalization";

export interface PhotoPublicationMetadata {
  readonly publicData: Readonly<Record<string, unknown>>;
  readonly privateData: Readonly<Record<string, unknown>>;
}

export interface PhotoPublicationWriter {
  create(reference: unknown, data: Readonly<Record<string, unknown>>): void;
}

export function buildPhotoPublicationMetadata(input: {
  readonly machineId: string;
  readonly photoId: string;
  readonly uploadedBy: string;
  readonly uploadedAt: unknown;
  readonly recognitionProvider: string;
  readonly storagePath: string;
  readonly isPrimary: boolean;
}): PhotoPublicationMetadata {
  const expectedPath = buildFormalPhotoStoragePath(input.machineId, input.photoId);
  if (input.storagePath !== expectedPath) {
    throw new Error("Formal photo storage path does not match the v2 contract.");
  }
  return {
    publicData: {status: "active", createdAt: input.uploadedAt},
    privateData: {
      uploadedBy: input.uploadedBy,
      uploadedAt: input.uploadedAt,
      recognitionStatus: "completed",
      recognitionProvider: input.recognitionProvider,
      storagePath: input.storagePath,
      thumbnailPath: null,
      isPrimary: input.isPrimary,
    },
  };
}

/**
 * The caller supplies a Firestore transaction, so the pair is committed or
 * rolled back atomically. Private metadata is staged first to avoid a
 * public-only photo if a non-transactional writer is ever substituted.
 */
export function writePhotoPublicationMetadata(
  writer: PhotoPublicationWriter,
  publicReference: unknown,
  privateReference: unknown,
  metadata: PhotoPublicationMetadata,
): void {
  writer.create(privateReference, metadata.privateData);
  writer.create(publicReference, metadata.publicData);
}
