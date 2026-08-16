import type {
  MasterLabelResolution,
} from "./master_label_resolver";
import {resolveMasterLabels} from "./master_label_resolver";
import type {
  PhotoRecognitionMasterCatalog,
} from "./master_catalog";

export interface RecognitionLabelInput {
  readonly machineManufacturerLabels: readonly string[];
  readonly productLabels: readonly string[];
  readonly unresolvedLabels: readonly string[];
}

export interface RecognitionMasterResolution {
  readonly manufacturerCandidateIds: readonly string[];
  readonly productCandidateIds: readonly string[];
  readonly unresolvedLabels: readonly string[];
}

export function resolveRecognitionLabelsAgainstCatalog(
  input: RecognitionLabelInput,
  catalog: PhotoRecognitionMasterCatalog,
): RecognitionMasterResolution {
  const manufacturerResolution = resolveMasterLabels(
    input.machineManufacturerLabels,
    catalog.manufacturers,
  );
  const productResolution = resolveMasterLabels(
    input.productLabels,
    catalog.products,
  );

  return {
    manufacturerCandidateIds: manufacturerResolution.resolvedIds,
    productCandidateIds: productResolution.resolvedIds,
    unresolvedLabels: mergeUnresolvedLabels(
      input.unresolvedLabels,
      manufacturerResolution,
      productResolution,
    ),
  };
}

function mergeUnresolvedLabels(
  providerUnresolvedLabels: readonly string[],
  manufacturerResolution: MasterLabelResolution,
  productResolution: MasterLabelResolution,
): readonly string[] {
  const result: string[] = [];
  const seen = new Set<string>();

  for (const label of [
    ...providerUnresolvedLabels,
    ...manufacturerResolution.unresolvedLabels,
    ...productResolution.unresolvedLabels,
  ]) {
    const normalized = label.trim();
    if (normalized.length === 0 || seen.has(normalized)) {
      continue;
    }

    seen.add(normalized);
    result.push(normalized);
  }

  return result;
}
