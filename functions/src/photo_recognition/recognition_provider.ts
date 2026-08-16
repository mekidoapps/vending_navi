export interface RecognitionProviderOutput {
  readonly machineManufacturerLabels: readonly string[];
  readonly productLabels: readonly string[];
  readonly unresolvedLabels: readonly string[];
}

export interface RecognitionProviderInput {
  readonly imageBytes: Buffer;
  readonly mimeType: "image/jpeg";
}

export interface RecognitionProvider {
  readonly providerKey: string;

  recognize(
    input: RecognitionProviderInput,
  ): Promise<RecognitionProviderOutput>;
}

export class RecognitionProviderFailure extends Error {
  constructor(message = "Photo recognition provider failed.") {
    super(message);
    this.name = "RecognitionProviderFailure";
  }
}
