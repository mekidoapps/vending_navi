import type {DocumentData, Firestore} from "firebase-admin/firestore";

import type {MasterLabelRecord} from "./master_label_resolver";

export type MasterCollectionKind = "manufacturer" | "product";

export interface PhotoRecognitionMasterCatalog {
  readonly manufacturers: readonly MasterLabelRecord[];
  readonly products: readonly MasterLabelRecord[];
}

export class PhotoRecognitionMasterDataError extends Error {
  constructor(
    readonly kind: MasterCollectionKind,
    readonly documentId: string,
    message: string,
  ) {
    super(message);
    this.name = "PhotoRecognitionMasterDataError";
  }
}

export async function readPhotoRecognitionMasterCatalog(
  firestore: Firestore,
): Promise<PhotoRecognitionMasterCatalog> {
  const [manufacturerSnapshot, productSnapshot] = await Promise.all([
    firestore
      .collection("manufacturers")
      .where("isActive", "==", true)
      .get(),
    firestore
      .collection("products")
      .where("isActive", "==", true)
      .get(),
  ]);

  return {
    manufacturers: manufacturerSnapshot.docs.map((document) =>
      parseActiveMasterDocument(
        "manufacturer",
        document.id,
        document.data(),
      ),
    ),
    products: productSnapshot.docs.map((document) =>
      parseActiveMasterDocument(
        "product",
        document.id,
        document.data(),
      ),
    ),
  };
}

export function parseActiveMasterDocument(
  kind: MasterCollectionKind,
  documentId: string,
  data: DocumentData,
): MasterLabelRecord {
  const normalizedId = documentId.trim();
  if (normalizedId.length === 0) {
    throw new PhotoRecognitionMasterDataError(
      kind,
      documentId,
      `${kind} master document ID must not be empty.`,
    );
  }

  const name =
    typeof data.name === "string" ?
      data.name.trim() :
      "";
  if (name.length === 0) {
    throw new PhotoRecognitionMasterDataError(
      kind,
      normalizedId,
      `${kind} master name is missing.`,
    );
  }

  if (data.isActive !== true) {
    throw new PhotoRecognitionMasterDataError(
      kind,
      normalizedId,
      `${kind} master must be active.`,
    );
  }

  const searchKeywords = Array.isArray(data.searchKeywords) ?
    data.searchKeywords
      .filter(
        (value: unknown): value is string =>
          typeof value === "string" && value.trim().length > 0,
      )
      .map((value: string) => value.trim()) :
    [];

  return {
    id: normalizedId,
    name,
    searchKeywords: [...new Set(searchKeywords)],
    isActive: true,
  };
}
