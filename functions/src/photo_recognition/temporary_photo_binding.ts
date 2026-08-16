import {createHash} from "node:crypto";

import type {
  TemporaryPhotoContent,
} from "./temporary_photo_content_adapter";

export interface TemporaryPhotoBinding {
  readonly objectPath: string;
  readonly contentSha256: string;
  readonly sizeBytes: number;
}

/**
 * Binds a recognition result to the exact JPEG bytes that were sent to the
 * recognition provider. The final photo-registration step can re-read the
 * temporary object and require the same SHA-256 before treating AI candidates
 * as photo-confirmed evidence.
 */
export function buildTemporaryPhotoBinding(
  photo: TemporaryPhotoContent,
): TemporaryPhotoBinding {
  if (photo.bytes.length <= 0) {
    throw new Error("Temporary photo binding requires non-empty bytes.");
  }

  return {
    objectPath: photo.objectPath,
    contentSha256: createHash("sha256")
      .update(photo.bytes)
      .digest("hex"),
    sizeBytes: photo.bytes.length,
  };
}
