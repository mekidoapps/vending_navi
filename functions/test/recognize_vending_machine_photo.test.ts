import {strict as assert} from "node:assert";
import {createHash} from "node:crypto";
import {test} from "node:test";

import type {
  PhotoRecognitionMasterCatalog,
} from "../src/photo_recognition/master_catalog";
import type {
  RecognitionProvider,
  RecognitionProviderOutput,
} from "../src/photo_recognition/recognition_provider";
import type {
  RecognitionOperationClaim,
  RecognitionOperationStore,
  StoredRecognitionResult,
} from "../src/photo_recognition/recognition_operation_store";
import {
  runRecognizeVendingMachinePhoto,
} from "../src/photo_recognition/recognize_vending_machine_photo";
import type {
  TemporaryPhotoContent,
} from "../src/photo_recognition/temporary_photo_content_adapter";

const REQUEST_ID = "550e8400-e29b-41d4-a716-446655440000";
const UPLOAD_ID = "123e4567-e89b-42d3-a456-426614174000";

const PHOTO: TemporaryPhotoContent = {
  objectPath:
    `machine_uploads/user-1/${UPLOAD_ID}/original.jpg`,
  contentType: "image/jpeg",
  bytes: Buffer.from([0xff, 0xd8, 0xff, 0xd9]),
};

const CATALOG: PhotoRecognitionMasterCatalog = {
  manufacturers: [
    {
      id: "asahi",
      name: "アサヒ",
      searchKeywords: ["asahi"],
      isActive: true,
    },
  ],
  products: [
    {
      id: "otsuka_pocari_sweat",
      name: "ポカリスエット",
      searchKeywords: ["pocari sweat"],
      isActive: true,
    },
  ],
};

class FakeStore implements RecognitionOperationStore {
  readonly completed: StoredRecognitionResult[] = [];

  constructor(
    private readonly claimResult: RecognitionOperationClaim,
  ) {}

  async claim(): Promise<RecognitionOperationClaim> {
    return this.claimResult;
  }

  async complete(
    _uid: string,
    _requestId: string,
    _uploadId: string,
    result: StoredRecognitionResult,
  ): Promise<void> {
    this.completed.push(result);
  }
}

class FakeProvider implements RecognitionProvider {
  readonly providerKey = "fake_provider";
  calls = 0;

  async recognize(): Promise<RecognitionProviderOutput> {
    this.calls += 1;
    return {
      machineManufacturerLabels: ["Asahi"],
      productLabels: ["POCARI SWEAT"],
      unresolvedLabels: [],
    };
  }
}

test("claimed request runs recognition and persists normalized result", async () => {
  const store = new FakeStore({kind: "claimed"});
  const provider = new FakeProvider();

  const response = await runRecognizeVendingMachinePhoto(
    {
      provider,
      operationStore: store,
      loadCatalog: async () => CATALOG,
      loadPhoto: async () => PHOTO,
    },
    "user-1",
    {
      recognitionRequestId: REQUEST_ID,
      uploadId: UPLOAD_ID,
    },
  );

  assert.deepEqual(response, {
    manufacturerCandidates: [{manufacturerId: "asahi"}],
    productCandidates: [{productId: "otsuka_pocari_sweat"}],
    unresolvedLabels: [],
    recognitionStatus: "completed",
  });
  assert.equal(provider.calls, 1);
  assert.equal(store.completed.length, 1);
  assert.equal(
    store.completed[0].providerKey,
    "fake_provider",
  );
  assert.deepEqual(store.completed[0].photoBinding, {
    objectPath: PHOTO.objectPath,
    contentSha256: createHash("sha256")
      .update(PHOTO.bytes)
      .digest("hex"),
    sizeBytes: PHOTO.bytes.length,
  });
});

test("replayed request returns stored response without new AI call", async () => {
  const replay: StoredRecognitionResult = {
    providerKey: "vertex_gemini_3_5_flash_lite",
    response: {
      manufacturerCandidates: [{manufacturerId: "asahi"}],
      productCandidates: [],
      unresolvedLabels: ["unknown product"],
      recognitionStatus: "completed",
    },
  };
  const store = new FakeStore({
    kind: "replay",
    result: replay,
  });
  const provider = new FakeProvider();
  let photoReads = 0;

  const response = await runRecognizeVendingMachinePhoto(
    {
      provider,
      operationStore: store,
      loadCatalog: async () => CATALOG,
      loadPhoto: async () => {
        photoReads += 1;
        return PHOTO;
      },
    },
    "user-1",
    {
      recognitionRequestId: REQUEST_ID,
      uploadId: UPLOAD_ID,
    },
  );

  assert.deepEqual(response, replay.response);
  assert.equal(provider.calls, 0);
  assert.equal(photoReads, 0);
  assert.equal(store.completed.length, 0);
});

test("provider failure is persisted without photo-confirmed binding", async () => {
  const store = new FakeStore({kind: "claimed"});
  const provider: RecognitionProvider = {
    providerKey: "fake_failure",
    async recognize(): Promise<RecognitionProviderOutput> {
      throw new Error("simulated provider failure");
    },
  };

  const response = await runRecognizeVendingMachinePhoto(
    {
      provider,
      operationStore: store,
      loadCatalog: async () => CATALOG,
      loadPhoto: async () => PHOTO,
    },
    "user-1",
    {
      recognitionRequestId: REQUEST_ID,
      uploadId: UPLOAD_ID,
    },
  );

  assert.equal(response.recognitionStatus, "failed");
  assert.equal(store.completed.length, 1);
  assert.equal(
    store.completed[0].response.recognitionStatus,
    "failed",
  );
  assert.equal(store.completed[0].photoBinding, null);
});
