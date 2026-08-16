import type {
  PhotoRecognitionMasterCatalog,
} from "./master_catalog";
import {
  resolveRecognitionLabelsAgainstCatalog,
} from "./master_resolution_service";
import type {
  RecognizeVendingMachinePhotoResponse,
} from "./recognition_contract";
import type {
  RecognitionProvider,
} from "./recognition_provider";
import type {
  TemporaryPhotoContent,
} from "./temporary_photo_content_adapter";

export interface RecognitionServiceDependencies {
  readonly provider: RecognitionProvider;
  readonly loadCatalog: () => Promise<PhotoRecognitionMasterCatalog>;
  readonly loadPhoto: (
    uid: string,
    uploadId: string,
  ) => Promise<TemporaryPhotoContent>;
}

export interface RecognitionServiceInput {
  readonly uid: string;
  readonly uploadId: string;
}

export interface RecognitionServiceResult {
  readonly providerKey: string;
  readonly response: RecognizeVendingMachinePhotoResponse;
}

export async function recognizePhotoWithMasterResolution(
  dependencies: RecognitionServiceDependencies,
  input: RecognitionServiceInput,
): Promise<RecognitionServiceResult> {
  const uid = input.uid.trim();
  if (uid.length === 0) {
    throw new Error("Recognition service requires a non-empty uid.");
  }

  try {
    const [photo, catalog] = await Promise.all([
      dependencies.loadPhoto(uid, input.uploadId),
      dependencies.loadCatalog(),
    ]);

    const providerOutput = await dependencies.provider.recognize({
      imageBytes: photo.bytes,
      mimeType: photo.contentType,
    });

    const resolution = resolveRecognitionLabelsAgainstCatalog(
      providerOutput,
      catalog,
    );

    return {
      providerKey: dependencies.provider.providerKey,
      response: {
        manufacturerCandidates: resolution.manufacturerCandidateIds.map(
          (manufacturerId) => ({manufacturerId}),
        ),
        productCandidates: resolution.productCandidateIds.map(
          (productId) => ({productId}),
        ),
        unresolvedLabels: resolution.unresolvedLabels,
        recognitionStatus: "completed",
      },
    };
  } catch {
    // Phase 7 contract: photo/provider/master-resolution failure must not make
    // the whole registration flow unusable. The caller can continue manually.
    return {
      providerKey: dependencies.provider.providerKey,
      response: {
        manufacturerCandidates: [],
        productCandidates: [],
        unresolvedLabels: [],
        recognitionStatus: "failed",
      },
    };
  }
}
