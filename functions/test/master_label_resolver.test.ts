import {strict as assert} from "node:assert";
import {test} from "node:test";

import {
  MasterLabelRecord,
  normalizeMasterLabel,
  resolveMasterLabels,
} from "../src/photo_recognition/master_label_resolver";

const manufacturers: readonly MasterLabelRecord[] = [
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
];

const products: readonly MasterLabelRecord[] = [
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
  {
    id: "inactive_product",
    name: "非公開商品",
    searchKeywords: ["inactive"],
    isActive: false,
  },
];

test("normalizeMasterLabel normalizes safe representation variants", () => {
  assert.equal(
    normalizeMasterLabel("  ＰＯＣＡＲＩ　ＳＷＥＡＴ  "),
    "pocari sweat",
  );
  assert.equal(
    normalizeMasterLabel("お〜い おちゃ"),
    "オ～イ オチャ",
  );
  assert.equal(
    normalizeMasterLabel("A — B"),
    "a-b",
  );
});

test("manufacturer label resolves through an explicit search keyword", () => {
  assert.deepEqual(
    resolveMasterLabels(["Asahi"], manufacturers),
    {
      resolvedIds: ["asahi"],
      unresolvedLabels: [],
    },
  );
});

test("product labels resolve by name or explicit search keyword", () => {
  assert.deepEqual(
    resolveMasterLabels(
      [
        "十六茶",
        "POCARI SWEAT",
        "アサヒ おいしい水",
      ],
      products,
    ),
    {
      resolvedIds: [
        "asahi_jurokucha",
        "otsuka_pocari_sweat",
        "asahi_oishii_mizu",
      ],
      unresolvedLabels: [],
    },
  );
});

test("mixed manufacturer products remain independent from machine brand", () => {
  const manufacturerResult = resolveMasterLabels(["Asahi"], manufacturers);
  const productResult = resolveMasterLabels(
    ["十六茶", "POCARI SWEAT"],
    products,
  );

  assert.deepEqual(manufacturerResult.resolvedIds, ["asahi"]);
  assert.deepEqual(
    productResult.resolvedIds,
    ["asahi_jurokucha", "otsuka_pocari_sweat"],
  );
});

test("unknown product remains unresolved instead of using fuzzy guessing", () => {
  assert.deepEqual(
    resolveMasterLabels(["ドデカミン ストロング"], products),
    {
      resolvedIds: [],
      unresolvedLabels: ["ドデカミン ストロング"],
    },
  );
});

test("similar but different product name does not fuzzy-match", () => {
  const records: readonly MasterLabelRecord[] = [
    {
      id: "dodekamin_strong",
      name: "ドデカミン ストロング",
      searchKeywords: [],
      isActive: true,
    },
  ];

  assert.deepEqual(
    resolveMasterLabels(["デカビタC ストロング"], records),
    {
      resolvedIds: [],
      unresolvedLabels: ["デカビタC ストロング"],
    },
  );
});

test("ambiguous normalized label remains unresolved", () => {
  const records: readonly MasterLabelRecord[] = [
    {
      id: "black_a",
      name: "商品A",
      searchKeywords: ["BLACK"],
      isActive: true,
    },
    {
      id: "black_b",
      name: "商品B",
      searchKeywords: ["black"],
      isActive: true,
    },
  ];

  assert.deepEqual(
    resolveMasterLabels(["BLACK"], records),
    {
      resolvedIds: [],
      unresolvedLabels: ["BLACK"],
    },
  );
});

test("inactive records cannot be resolved", () => {
  assert.deepEqual(
    resolveMasterLabels(["inactive"], products),
    {
      resolvedIds: [],
      unresolvedLabels: ["inactive"],
    },
  );
});

test("duplicate labels and IDs are deduplicated while preserving order", () => {
  assert.deepEqual(
    resolveMasterLabels(
      ["POCARI SWEAT", "pocari sweat", "十六茶", "十六茶"],
      products,
    ),
    {
      resolvedIds: ["otsuka_pocari_sweat", "asahi_jurokucha"],
      unresolvedLabels: [],
    },
  );
});

test("empty AI labels are ignored", () => {
  assert.deepEqual(
    resolveMasterLabels(["", "   "], products),
    {
      resolvedIds: [],
      unresolvedLabels: [],
    },
  );
});
