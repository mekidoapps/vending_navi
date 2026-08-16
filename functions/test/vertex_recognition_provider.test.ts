import {strict as assert} from "node:assert";
import {test} from "node:test";

import {
  VERTEX_RECOGNITION_MODEL,
  VERTEX_RECOGNITION_PROVIDER_KEY,
  VertexRecognitionProvider,
  parseVertexRecognitionOutput,
  resolveGoogleCloudProjectId,
} from "../src/photo_recognition/vertex_recognition_provider";
import type {
  VertexTextGenerator,
} from "../src/photo_recognition/vertex_recognition_provider";
import {
  RecognitionProviderFailure,
} from "../src/photo_recognition/recognition_provider";

class FakeGenerator implements VertexTextGenerator {
  readonly calls: Parameters<VertexTextGenerator["generate"]>[0][] = [];

  constructor(private readonly responseText: string | undefined) {}

  async generate(
    input: Parameters<VertexTextGenerator["generate"]>[0],
  ): Promise<string | undefined> {
    this.calls.push(input);
    return this.responseText;
  }
}

test("provider sends JPEG bytes to the fixed MVP model", async () => {
  const generator = new FakeGenerator(
    JSON.stringify({
      machineManufacturerLabels: ["Asahi"],
      productLabels: ["十六茶", "POCARI SWEAT"],
      unresolvedLabels: [],
    }),
  );
  const provider = new VertexRecognitionProvider(generator);
  const bytes = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);

  const result = await provider.recognize({
    imageBytes: bytes,
    mimeType: "image/jpeg",
  });

  assert.equal(provider.providerKey, VERTEX_RECOGNITION_PROVIDER_KEY);
  assert.equal(generator.calls.length, 1);
  assert.equal(generator.calls[0].model, VERTEX_RECOGNITION_MODEL);
  assert.equal(generator.calls[0].mimeType, "image/jpeg");
  assert.equal(
    generator.calls[0].imageBase64,
    bytes.toString("base64"),
  );
  assert.deepEqual(result, {
    machineManufacturerLabels: ["Asahi"],
    productLabels: ["十六茶", "POCARI SWEAT"],
    unresolvedLabels: [],
  });
});

test("provider output parser trims and deduplicates labels", () => {
  assert.deepEqual(
    parseVertexRecognitionOutput(
      JSON.stringify({
        machineManufacturerLabels: [" Asahi ", "Asahi"],
        productLabels: ["十六茶", " 十六茶 "],
        unresolvedLabels: [" blurred ", "blurred"],
      }),
    ),
    {
      machineManufacturerLabels: ["Asahi"],
      productLabels: ["十六茶"],
      unresolvedLabels: ["blurred"],
    },
  );
});

test("provider output parser rejects malformed JSON", () => {
  assert.throws(
    () => parseVertexRecognitionOutput("{not-json"),
    RecognitionProviderFailure,
  );
});

test("provider output parser rejects unexpected fields", () => {
  assert.throws(
    () =>
      parseVertexRecognitionOutput(
        JSON.stringify({
          machineManufacturerLabels: [],
          productLabels: [],
          unresolvedLabels: [],
          confidence: 0.99,
        }),
      ),
    RecognitionProviderFailure,
  );
});

test("provider output parser rejects non-string labels", () => {
  assert.throws(
    () =>
      parseVertexRecognitionOutput(
        JSON.stringify({
          machineManufacturerLabels: ["Asahi"],
          productLabels: ["十六茶", 123],
          unresolvedLabels: [],
        }),
      ),
    RecognitionProviderFailure,
  );
});

test("provider converts generator errors to safe provider failure", async () => {
  const generator: VertexTextGenerator = {
    async generate() {
      throw new Error("private Vertex error detail");
    },
  };
  const provider = new VertexRecognitionProvider(generator);

  await assert.rejects(
    () =>
      provider.recognize({
        imageBytes: Buffer.from([0xff, 0xd8]),
        mimeType: "image/jpeg",
      }),
    (error: unknown) => {
      assert.ok(error instanceof RecognitionProviderFailure);
      assert.equal(
        error.message.includes("private Vertex error detail"),
        false,
      );
      return true;
    },
  );
});

test("project ID prefers GCLOUD_PROJECT then GOOGLE_CLOUD_PROJECT", () => {
  assert.equal(
    resolveGoogleCloudProjectId({
      GCLOUD_PROJECT: " vendingnavi ",
      GOOGLE_CLOUD_PROJECT: "fallback-project",
    }),
    "vendingnavi",
  );

  assert.equal(
    resolveGoogleCloudProjectId({
      GOOGLE_CLOUD_PROJECT: " fallback-project ",
    }),
    "fallback-project",
  );

  assert.equal(resolveGoogleCloudProjectId({}), "");
});
