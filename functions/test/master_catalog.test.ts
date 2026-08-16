import {strict as assert} from "node:assert";
import {test} from "node:test";

import {
  PhotoRecognitionMasterDataError,
  parseActiveMasterDocument,
} from "../src/photo_recognition/master_catalog";

test("active manufacturer master is parsed for recognition lookup", () => {
  assert.deepEqual(
    parseActiveMasterDocument(
      "manufacturer",
      "asahi",
      {
        name: " アサヒ ",
        searchKeywords: [
          "アサヒ飲料",
          "asahi",
          "asahi",
          "",
          42,
        ],
        isActive: true,
      },
    ),
    {
      id: "asahi",
      name: "アサヒ",
      searchKeywords: ["アサヒ飲料", "asahi"],
      isActive: true,
    },
  );
});

test("active product master is parsed without requiring unrelated fields", () => {
  assert.deepEqual(
    parseActiveMasterDocument(
      "product",
      "otsuka_pocari_sweat",
      {
        name: "ポカリスエット",
        manufacturerId: "otsuka",
        searchKeywords: ["ポカリ", "pocari sweat"],
        genreIds: ["sports_drink"],
        isActive: true,
      },
    ),
    {
      id: "otsuka_pocari_sweat",
      name: "ポカリスエット",
      searchKeywords: ["ポカリ", "pocari sweat"],
      isActive: true,
    },
  );
});

test("malformed active master fails instead of being silently accepted", () => {
  assert.throws(
    () =>
      parseActiveMasterDocument(
        "product",
        "broken_product",
        {
          name: "   ",
          searchKeywords: [],
          isActive: true,
        },
      ),
    (error: unknown) => {
      assert.ok(error instanceof PhotoRecognitionMasterDataError);
      assert.equal(error.kind, "product");
      assert.equal(error.documentId, "broken_product");
      return true;
    },
  );
});

test("inactive document cannot enter an active recognition catalog", () => {
  assert.throws(
    () =>
      parseActiveMasterDocument(
        "manufacturer",
        "inactive",
        {
          name: "Inactive",
          searchKeywords: [],
          isActive: false,
        },
      ),
    PhotoRecognitionMasterDataError,
  );
});
