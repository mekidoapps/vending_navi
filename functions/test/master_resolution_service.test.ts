import {strict as assert} from "node:assert";
import {test} from "node:test";

import type {
  PhotoRecognitionMasterCatalog,
} from "../src/photo_recognition/master_catalog";
import {
  resolveRecognitionLabelsAgainstCatalog,
} from "../src/photo_recognition/master_resolution_service";

const catalog: PhotoRecognitionMasterCatalog = {
  manufacturers: [
    {
      id: "asahi",
      name: "アサヒ",
      searchKeywords: ["アサヒ飲料", "asahi"],
      isActive: true,
    },
    {
      id: "otsuka",
      name: "大塚製薬",
      searchKeywords: ["大塚", "otsuka"],
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
      id: "asahi_oishii_mizu",
      name: "おいしい水",
      searchKeywords: ["おいしい水 天然水", "アサヒ おいしい水"],
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

test("recognized labels resolve to existing master IDs", () => {
  assert.deepEqual(
    resolveRecognitionLabelsAgainstCatalog(
      {
        machineManufacturerLabels: ["Asahi"],
        productLabels: [
          "十六茶",
          "POCARI SWEAT",
          "アサヒ おいしい水",
        ],
        unresolvedLabels: [],
      },
      catalog,
    ),
    {
      manufacturerCandidateIds: ["asahi"],
      productCandidateIds: [
        "asahi_jurokucha",
        "otsuka_pocari_sweat",
        "asahi_oishii_mizu",
      ],
      unresolvedLabels: [],
    },
  );
});

test("mixed-brand products do not change the machine brand candidate", () => {
  const result = resolveRecognitionLabelsAgainstCatalog(
    {
      machineManufacturerLabels: ["Asahi"],
      productLabels: ["十六茶", "POCARI SWEAT"],
      unresolvedLabels: [],
    },
    catalog,
  );

  assert.deepEqual(result.manufacturerCandidateIds, ["asahi"]);
  assert.deepEqual(
    result.productCandidateIds,
    ["asahi_jurokucha", "otsuka_pocari_sweat"],
  );
});

test("master-missing products remain unresolved for user confirmation", () => {
  assert.deepEqual(
    resolveRecognitionLabelsAgainstCatalog(
      {
        machineManufacturerLabels: ["Asahi"],
        productLabels: [
          "WILKINSON LEMON",
          "ドデカミン ストロング",
        ],
        unresolvedLabels: [],
      },
      catalog,
    ),
    {
      manufacturerCandidateIds: ["asahi"],
      productCandidateIds: [],
      unresolvedLabels: [
        "WILKINSON LEMON",
        "ドデカミン ストロング",
      ],
    },
  );
});

test("provider unresolved labels are preserved and deduplicated", () => {
  assert.deepEqual(
    resolveRecognitionLabelsAgainstCatalog(
      {
        machineManufacturerLabels: ["Unknown Machine Brand"],
        productLabels: ["Unknown Product"],
        unresolvedLabels: [
          "blurred label",
          "blurred label",
          " ",
        ],
      },
      catalog,
    ),
    {
      manufacturerCandidateIds: [],
      productCandidateIds: [],
      unresolvedLabels: [
        "blurred label",
        "Unknown Machine Brand",
        "Unknown Product",
      ],
    },
  );
});
