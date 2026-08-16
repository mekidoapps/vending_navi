import type {Firestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import type {
  PhotoRecognitionMasterCatalog,
} from "./master_catalog";
import {
  readPhotoRecognitionMasterCatalog,
} from "./master_catalog";
import {
  RecognitionRequestValidationError,
  parseRecognitionRequest,
} from "./recognition_contract";
import type {
  RecognitionProvider,
} from "./recognition_provider";
import type {
  RecognitionOperationStore,
} from "./recognition_operation_store";
import {
  FirestoreRecognitionOperationStore,
  RecognitionOperationInProgressError,
} from "./recognition_operation_store";
import {
  recognizePhotoWithMasterResolution,
} from "./recognition_service";
import {
  buildTemporaryPhotoBinding,
} from "./temporary_photo_binding";
import type {
  StorageDownloadBucketLike,
  TemporaryPhotoContent,
} from "./temporary_photo_content_adapter";
import {
  readValidatedTemporaryPhotoContent,
} from "./temporary_photo_content_adapter";

export interface RecognizePhotoDependencies {
  readonly provider: RecognitionProvider;
  readonly operationStore: RecognitionOperationStore;
  readonly loadCatalog: () => Promise<PhotoRecognitionMasterCatalog>;
  readonly loadPhoto: (
    uid: string,
    uploadId: string,
  ) => Promise<TemporaryPhotoContent>;
}

export async function runRecognizeVendingMachinePhoto(
  dependencies: RecognizePhotoDependencies,
  uid: string,
  rawInput: unknown,
) {
  const normalizedUid = uid.trim();
  if (normalizedUid.length === 0) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required.",
    );
  }

  let input;
  try {
    input = parseRecognitionRequest(rawInput);
  } catch (error: unknown) {
    if (error instanceof RecognitionRequestValidationError) {
      throw new HttpsError(
        "invalid-argument",
        error.message,
        {appCode: "invalid-recognition-request"},
      );
    }
    throw error;
  }

  let claim;
  try {
    claim = await dependencies.operationStore.claim(
      normalizedUid,
      input.recognitionRequestId,
      input.uploadId,
    );
  } catch (error: unknown) {
    if (error instanceof RecognitionOperationInProgressError) {
      throw new HttpsError(
        "aborted",
        "Photo recognition is already in progress.",
        {appCode: "recognition-in-progress"},
      );
    }
    throw error;
  }

  if (claim.kind === "replay") {
    return claim.result.response;
  }

  let loadedPhoto: TemporaryPhotoContent | null = null;
  const loadPhotoOnce = async (
    photoUid: string,
    uploadId: string,
  ): Promise<TemporaryPhotoContent> => {
    if (loadedPhoto === null) {
      loadedPhoto = await dependencies.loadPhoto(photoUid, uploadId);
    }
    return loadedPhoto;
  };

  const result = await recognizePhotoWithMasterResolution(
    {
      provider: dependencies.provider,
      loadCatalog: dependencies.loadCatalog,
      loadPhoto: loadPhotoOnce,
    },
    {
      uid: normalizedUid,
      uploadId: input.uploadId,
    },
  );

  const photoBinding =
    result.response.recognitionStatus === "completed" &&
    loadedPhoto !== null ?
      buildTemporaryPhotoBinding(loadedPhoto) :
      null;

  await dependencies.operationStore.complete(
    normalizedUid,
    input.recognitionRequestId,
    input.uploadId,
    {
      ...result,
      photoBinding,
    },
  );

  return result.response;
}

export async function recognizeVendingMachinePhotoForUser(
  firestore: Firestore,
  bucket: StorageDownloadBucketLike,
  provider: RecognitionProvider,
  uid: string,
  rawInput: unknown,
) {
  const operationStore =
    new FirestoreRecognitionOperationStore(firestore);

  return runRecognizeVendingMachinePhoto(
    {
      provider,
      operationStore,
      loadCatalog: () =>
        readPhotoRecognitionMasterCatalog(firestore),
      loadPhoto: (photoUid, uploadId) =>
        readValidatedTemporaryPhotoContent(
          bucket,
          photoUid,
          uploadId,
          new Date(),
        ),
    },
    uid,
    rawInput,
  );
}
