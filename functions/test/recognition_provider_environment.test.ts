import {strict as assert} from "node:assert";
import test from "node:test";

import {
  EMULATOR_RECOGNITION_PROVIDER_KEY,
} from "../src/photo_recognition/emulator_recognition_provider";
import type {
  RecognitionProvider,
} from "../src/photo_recognition/recognition_provider";
import {
  createRecognitionProviderForEnvironment,
} from "../src/photo_recognition/recognition_provider_environment";

test(
  "Functions Emulatorではproduction providerを生成せずfixtureを使う",
  async () => {
    let productionFactoryCalls = 0;

    const provider = createRecognitionProviderForEnvironment(
      {
        FUNCTIONS_EMULATOR: "true",
      },
      () => {
        productionFactoryCalls += 1;
        throw new Error(
          "Production provider must not be created in emulator.",
        );
      },
    );

    assert.equal(productionFactoryCalls, 0);
    assert.equal(
      provider.providerKey,
      EMULATOR_RECOGNITION_PROVIDER_KEY,
    );

    const result = await provider.recognize({
      imageBytes: Buffer.from([0xff, 0xd8, 0xff, 0xd9]),
      mimeType: "image/jpeg",
    });

    assert.deepEqual(
      result.machineManufacturerLabels,
      ["アサヒ"],
    );
    assert.deepEqual(
      result.productLabels,
      ["カルピス", "カルピスウォーター"],
    );
    assert.deepEqual(result.unresolvedLabels, []);
  },
);

test("Emulator外ではproduction provider factoryを使う", () => {
  const fakeProductionProvider: RecognitionProvider = {
    providerKey: "production_test_provider",
    async recognize() {
      return {
        machineManufacturerLabels: [],
        productLabels: [],
        unresolvedLabels: [],
      };
    },
  };

  let productionFactoryCalls = 0;

  const provider = createRecognitionProviderForEnvironment(
    {
      FUNCTIONS_EMULATOR: "false",
    },
    () => {
      productionFactoryCalls += 1;
      return fakeProductionProvider;
    },
  );

  assert.equal(productionFactoryCalls, 1);
  assert.equal(provider, fakeProductionProvider);
});
