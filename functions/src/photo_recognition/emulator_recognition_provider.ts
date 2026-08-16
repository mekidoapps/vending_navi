import type {
  RecognitionProvider,
  RecognitionProviderInput,
  RecognitionProviderOutput,
} from "./recognition_provider";

export const EMULATOR_RECOGNITION_PROVIDER_KEY =
  "emulator_photo_recognition_fixture";

export class EmulatorRecognitionProvider implements RecognitionProvider {
  readonly providerKey = EMULATOR_RECOGNITION_PROVIDER_KEY;

  async recognize(
    _input: RecognitionProviderInput,
  ): Promise<RecognitionProviderOutput> {
    return {
      machineManufacturerLabels: ["アサヒ"],
      productLabels: ["カルピス", "カルピスウォーター"],
      unresolvedLabels: [],
    };
  }
}

export function createEmulatorRecognitionProvider(): RecognitionProvider {
  return new EmulatorRecognitionProvider();
}
