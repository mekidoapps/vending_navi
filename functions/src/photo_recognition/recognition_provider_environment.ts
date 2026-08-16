import type {RecognitionProvider} from "./recognition_provider";
import {
  createEmulatorRecognitionProvider,
} from "./emulator_recognition_provider";
import {
  createProductionVertexRecognitionProvider,
  resolveGoogleCloudProjectId,
} from "./vertex_recognition_provider";

export type ProductionRecognitionProviderFactory = (
  env: NodeJS.ProcessEnv,
) => RecognitionProvider;

export function createRecognitionProviderForEnvironment(
  env: NodeJS.ProcessEnv,
  productionFactory: ProductionRecognitionProviderFactory =
    createProductionProvider,
): RecognitionProvider {
  if (env.FUNCTIONS_EMULATOR === "true") {
    return createEmulatorRecognitionProvider();
  }

  return productionFactory(env);
}

function createProductionProvider(
  env: NodeJS.ProcessEnv,
): RecognitionProvider {
  return createProductionVertexRecognitionProvider(
    resolveGoogleCloudProjectId(env),
  );
}
