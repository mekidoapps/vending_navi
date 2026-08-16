import {strict as assert} from "node:assert";
import {test} from "node:test";

import type {
  PhotoRecognitionMasterCatalog,
} from "../src/photo_recognition/master_catalog";
import type {
  RecognitionProvider,
  RecognitionProviderInput,
  RecognitionProviderOutput,
} from "../src/photo_recognition/recognition_provider";
import {
  recognizePhotoWithMasterResolution,
} from "../src/photo_recognition/recognition_service";
import type {
  TemporaryPhotoContent,
} from "../src/photo_recognition/temporary_photo_content_adapter";

const PHOTO: TemporaryPhotoContent = {
  objectPath:
    "machine_uploads/user-123/123e4567-e89b-42d3-a456-426614174000/original.jpg",
  contentType: "image/jpeg",
  bytes: Buffer.from([0xff, 0xd8, 0xff, 0xd9]),
};

const catalog: PhotoRecognitionMasterCatalog = {
  manufacturers: [
    {
      id: "asahi",
      name: "アサヒ",
      searchKeywords: ["アサヒ飲料", "asahi"],
      isActive: true,
    },
  ],
  products: [
    {
      id: "asahi_jurokucha",
      name: "十六茶",
      searchKeywords: ["16茶", "じゅうろくちゃ"],
      isActive: true,
    },
    {
      id: "otsuka_pocari_sweat",
      name: "ポカリスエット",
      searchKeywords: ["ポカリ", "pocari sweat", "pocari"],
      isActive: true,
    },
  ],
};

class FakeRecognitionProvider implements RecognitionProvider {
  readonly providerKey = "fake_vertex";
  readonly receivedInputs: RecognitionProviderInput[] = [];

  constructor(
    private readonly output: RecognitionProviderOutput,
  ) {}

  async recognize(
    input: RecognitionProviderInput,
  ): Promise<RecognitionProviderOutput> {
    this.receivedInputs.push(input);
    return this.output;
  }
}

class ThrowingRecognitionProvider implements RecognitionProvider {
  readonly providerKey = "fake_vertex_failure";

  async recognize(): Promise<RecognitionProviderOutput> {
    throw new Error("simulated provider outage");
  }
}

function loadPhoto(): Promise<TemporaryPhotoContent> {
  return Promise.resolve(PHOTO);
}

test("recognition service passes only validated photo bytes to provider", async () => {
  const provider = new FakeRecognitionProvider({
    machineManufacturerLabels: ["Asahi"],
    productLabels: ["十六茶", "POCARI SWEAT"],
    unresolvedLabels: [],
  });

  const result = await recognizePhotoWithMasterResolution(
    {
      provider,
      loadCatalog: async () => catalog,
      loadPhoto,
    },
    {
      uid: "user-123",
      uploadId: "123e4567-e89b-42d3-a456-426614174000",
    },
  );

  assert.equal(provider.receivedInputs.length, 1);
  assert.deepEqual(provider.receivedInputs[0], {
    imageBytes: PHOTO.bytes,
    mimeType: "image/jpeg",
  });

  assert.deepEqual(result, {
    providerKey: "fake_vertex",
    response: {
      manufacturerCandidates: [{manufacturerId: "asahi"}],
      productCandidates: [
        {productId: "asahi_jurokucha"},
        {productId: "otsuka_pocari_sweat"},
      ],
      unresolvedLabels: [],
      recognitionStatus: "completed",
    },
  });
});

test("recognition service preserves master-missing labels as unresolved", async () => {
  const result = await recognizePhotoWithMasterResolution(
    {
      provider: new FakeRecognitionProvider({
        machineManufacturerLabels: ["Asahi"],
        productLabels: ["WILKINSON LEMON", "POCARI SWEAT"],
        unresolvedLabels: ["blurred lower row"],
      }),
      loadCatalog: async () => catalog,
      loadPhoto,
    },
    {
      uid: "user-123",
      uploadId: "123e4567-e89b-42d3-a456-426614174000",
    },
  );

  assert.deepEqual(result.response, {
    manufacturerCandidates: [{manufacturerId: "asahi"}],
    productCandidates: [{productId: "otsuka_pocari_sweat"}],
    unresolvedLabels: ["blurred lower row", "WILKINSON LEMON"],
    recognitionStatus: "completed",
  });
});

test("empty but valid provider result is completed, not failed", async () => {
  const result = await recognizePhotoWithMasterResolution(
    {
      provider: new FakeRecognitionProvider({
        machineManufacturerLabels: [],
        productLabels: [],
        unresolvedLabels: [],
      }),
      loadCatalog: async () => catalog,
      loadPhoto,
    },
    {
      uid: "user-123",
      uploadId: "123e4567-e89b-42d3-a456-426614174000",
    },
  );

  assert.equal(result.response.recognitionStatus, "completed");
  assert.deepEqual(result.response.manufacturerCandidates, []);
  assert.deepEqual(result.response.productCandidates, []);
});

test("provider failure returns safe failed response instead of throwing", async () => {
  const result = await recognizePhotoWithMasterResolution(
    {
      provider: new ThrowingRecognitionProvider(),
      loadCatalog: async () => catalog,
      loadPhoto,
    },
    {
      uid: "user-123",
      uploadId: "123e4567-e89b-42d3-a456-426614174000",
    },
  );

  assert.deepEqual(result, {
    providerKey: "fake_vertex_failure",
    response: {
      manufacturerCandidates: [],
      productCandidates: [],
      unresolvedLabels: [],
      recognitionStatus: "failed",
    },
  });
});

test("master reader failure returns safe failed response", async () => {
  const result = await recognizePhotoWithMasterResolution(
    {
      provider: new FakeRecognitionProvider({
        machineManufacturerLabels: ["Asahi"],
        productLabels: ["十六茶"],
        unresolvedLabels: [],
      }),
      loadCatalog: async () => {
        throw new Error("simulated Firestore failure");
      },
      loadPhoto,
    },
    {
      uid: "user-123",
      uploadId: "123e4567-e89b-42d3-a456-426614174000",
    },
  );

  assert.equal(result.response.recognitionStatus, "failed");
});

test("temporary photo load failure returns safe failed response", async () => {
  const provider = new FakeRecognitionProvider({
    machineManufacturerLabels: ["Asahi"],
    productLabels: ["十六茶"],
    unresolvedLabels: [],
  });

  const result = await recognizePhotoWithMasterResolution(
    {
      provider,
      loadCatalog: async () => catalog,
      loadPhoto: async () => {
        throw new Error("invalid temporary photo");
      },
    },
    {
      uid: "user-123",
      uploadId: "123e4567-e89b-42d3-a456-426614174000",
    },
  );

  assert.equal(result.response.recognitionStatus, "failed");
  assert.equal(provider.receivedInputs.length, 0);
});
