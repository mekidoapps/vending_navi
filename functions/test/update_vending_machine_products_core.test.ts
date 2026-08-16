import assert from "node:assert/strict";
import test from "node:test";

import {
  UpdateVendingMachineProductsValidationError,
  buildProductUpdateDeduplicationId,
  collectReferencedProductIds,
  confirmedEvidenceForSource,
  isConfirmedEvidence,
  parseUpdateVendingMachineProductsInput,
} from "../src/update_vending_machine_products_core";

const REQUEST_ID = "123e4567-e89b-42d3-a456-426614174000";
const UPLOAD_ID = "f47ac10b-58cc-4372-a567-0e02b2c3d479";

test("all four product update operations are parsed", () => {
  const parsed = parseUpdateVendingMachineProductsInput({
    requestId: REQUEST_ID,
    machineId: "machine-001",
    operations: [
      {
        type: "addConfirmed",
        productId: "asahi_calpis",
        source: "manual",
      },
      {
        type: "deactivate",
        productId: "asahi_calpis_water",
      },
      {
        type: "setSoldOut",
        productId: "suntory_boss_black",
        soldOut: true,
      },
      {
        type: "confirmInferred",
        productId: "asahi_wonda_black",
      },
    ],
    temporaryPhotoUploadId: null,
  });

  assert.equal(parsed.machineId, "machine-001");
  assert.equal(parsed.operations.length, 4);
  assert.equal(parsed.temporaryPhotoUploadId, null);
});

test("photo source and temporary upload UUID are accepted", () => {
  const parsed = parseUpdateVendingMachineProductsInput({
    requestId: REQUEST_ID,
    machineId: "machine-001",
    operations: [
      {
        type: "addConfirmed",
        productId: "asahi_calpis",
        source: "photo",
      },
    ],
    temporaryPhotoUploadId: UPLOAD_ID,
  });

  assert.equal(parsed.temporaryPhotoUploadId, UPLOAD_ID);
  assert.deepEqual(parsed.operations[0], {
    type: "addConfirmed",
    productId: "asahi_calpis",
    source: "photo",
  });
});

test("unknown request and operation fields are rejected", () => {
  assert.throws(
    () => parseUpdateVendingMachineProductsInput({
      requestId: REQUEST_ID,
      machineId: "machine-001",
      operations: [
        {
          type: "deactivate",
          productId: "asahi_calpis",
        },
      ],
      temporaryPhotoUploadId: null,
      unexpected: true,
    }),
    UpdateVendingMachineProductsValidationError,
  );

  assert.throws(
    () => parseUpdateVendingMachineProductsInput({
      requestId: REQUEST_ID,
      machineId: "machine-001",
      operations: [
        {
          type: "deactivate",
          productId: "asahi_calpis",
          extra: true,
        },
      ],
      temporaryPhotoUploadId: null,
    }),
    UpdateVendingMachineProductsValidationError,
  );
});

test("empty operations and unsupported operation types are rejected", () => {
  assert.throws(
    () => parseUpdateVendingMachineProductsInput({
      requestId: REQUEST_ID,
      machineId: "machine-001",
      operations: [],
      temporaryPhotoUploadId: null,
    }),
    UpdateVendingMachineProductsValidationError,
  );

  assert.throws(
    () => parseUpdateVendingMachineProductsInput({
      requestId: REQUEST_ID,
      machineId: "machine-001",
      operations: [
        {
          type: "removeForever",
          productId: "asahi_calpis",
        },
      ],
      temporaryPhotoUploadId: null,
    }),
    UpdateVendingMachineProductsValidationError,
  );
});

test("invalid machine, product and upload IDs are rejected", () => {
  assert.throws(
    () => parseUpdateVendingMachineProductsInput({
      requestId: REQUEST_ID,
      machineId: "machines/001",
      operations: [
        {
          type: "deactivate",
          productId: "asahi_calpis",
        },
      ],
      temporaryPhotoUploadId: null,
    }),
    UpdateVendingMachineProductsValidationError,
  );

  assert.throws(
    () => parseUpdateVendingMachineProductsInput({
      requestId: REQUEST_ID,
      machineId: "machine-001",
      operations: [
        {
          type: "deactivate",
          productId: "INVALID PRODUCT",
        },
      ],
      temporaryPhotoUploadId: null,
    }),
    UpdateVendingMachineProductsValidationError,
  );

  assert.throws(
    () => parseUpdateVendingMachineProductsInput({
      requestId: REQUEST_ID,
      machineId: "machine-001",
      operations: [
        {
          type: "deactivate",
          productId: "asahi_calpis",
        },
      ],
      temporaryPhotoUploadId: "not-a-uuid",
    }),
    UpdateVendingMachineProductsValidationError,
  );
});

test("addConfirmed accepts only manual or photo source", () => {
  assert.throws(
    () => parseUpdateVendingMachineProductsInput({
      requestId: REQUEST_ID,
      machineId: "machine-001",
      operations: [
        {
          type: "addConfirmed",
          productId: "asahi_calpis",
          source: "ai",
        },
      ],
      temporaryPhotoUploadId: null,
    }),
    UpdateVendingMachineProductsValidationError,
  );
});

test("setSoldOut requires a boolean", () => {
  assert.throws(
    () => parseUpdateVendingMachineProductsInput({
      requestId: REQUEST_ID,
      machineId: "machine-001",
      operations: [
        {
          type: "setSoldOut",
          productId: "asahi_calpis",
          soldOut: "true",
        },
      ],
      temporaryPhotoUploadId: null,
    }),
    UpdateVendingMachineProductsValidationError,
  );
});

test("referenced Product IDs are deduplicated without changing operations", () => {
  const parsed = parseUpdateVendingMachineProductsInput({
    requestId: REQUEST_ID,
    machineId: "machine-001",
    operations: [
      {
        type: "addConfirmed",
        productId: "asahi_calpis",
        source: "manual",
      },
      {
        type: "setSoldOut",
        productId: "asahi_calpis",
        soldOut: true,
      },
      {
        type: "deactivate",
        productId: "asahi_calpis_water",
      },
    ],
    temporaryPhotoUploadId: null,
  });

  assert.deepEqual(
    collectReferencedProductIds(parsed.operations),
    ["asahi_calpis", "asahi_calpis_water"],
  );
  assert.equal(parsed.operations.length, 3);
});

test("dedupe ID is deterministic and scoped by user", () => {
  const first = buildProductUpdateDeduplicationId(
    "uid-a",
    REQUEST_ID,
  );
  const replay = buildProductUpdateDeduplicationId(
    "uid-a",
    REQUEST_ID,
  );
  const otherUser = buildProductUpdateDeduplicationId(
    "uid-b",
    REQUEST_ID,
  );

  assert.equal(first, replay);
  assert.notEqual(first, otherUser);
  assert.match(first, /^[0-9a-f]{64}$/);
});

test("confirmed evidence mapping never produces inferred evidence", () => {
  assert.equal(
    confirmedEvidenceForSource("manual"),
    "manual_confirmed",
  );
  assert.equal(
    confirmedEvidenceForSource("photo"),
    "photo_confirmed",
  );

  assert.equal(isConfirmedEvidence("manual_confirmed"), true);
  assert.equal(isConfirmedEvidence("photo_confirmed"), true);
  assert.equal(isConfirmedEvidence("manufacturer_inferred"), false);
});

test("manual add creates an active confirmed product", async () => {
  const {
    resolveProductUpdatePlan,
  } = await import("../src/update_vending_machine_products_core");

  const plan = resolveProductUpdatePlan(
    null,
    [
      {
        type: "addConfirmed",
        productId: "asahi_calpis",
        source: "manual",
      },
    ],
  );

  assert.deepEqual(plan.after, {
    productId: "asahi_calpis",
    evidenceType: "manual_confirmed",
    availability: "available",
    isActive: true,
  });
  assert.equal(plan.createsDocument, true);
  assert.equal(plan.changed, true);
});

test("photo add produces photo-confirmed candidate state", async () => {
  const {
    resolveProductUpdatePlan,
  } = await import("../src/update_vending_machine_products_core");

  const plan = resolveProductUpdatePlan(
    null,
    [
      {
        type: "addConfirmed",
        productId: "asahi_calpis",
        source: "photo",
      },
    ],
  );

  assert.equal(plan.after.evidenceType, "photo_confirmed");
});

test("confirmed product is never downgraded by another confirmation", async () => {
  const {
    resolveProductUpdatePlan,
  } = await import("../src/update_vending_machine_products_core");

  const plan = resolveProductUpdatePlan(
    {
      productId: "asahi_calpis",
      evidenceType: "manual_confirmed",
      availability: "soldOut",
      isActive: true,
    },
    [
      {
        type: "addConfirmed",
        productId: "asahi_calpis",
        source: "photo",
      },
    ],
  );

  assert.deepEqual(plan.after, {
    productId: "asahi_calpis",
    evidenceType: "manual_confirmed",
    availability: "soldOut",
    isActive: true,
  });
  assert.equal(plan.changed, false);
});

test("confirmInferred upgrades evidence and availability", async () => {
  const {
    resolveProductUpdatePlan,
  } = await import("../src/update_vending_machine_products_core");

  const plan = resolveProductUpdatePlan(
    {
      productId: "asahi_calpis",
      evidenceType: "manufacturer_inferred",
      availability: "unknown",
      isActive: true,
    },
    [
      {
        type: "confirmInferred",
        productId: "asahi_calpis",
      },
    ],
  );

  assert.deepEqual(plan.after, {
    productId: "asahi_calpis",
    evidenceType: "manual_confirmed",
    availability: "available",
    isActive: true,
  });
});

test("deactivate uses logical deletion and preserves evidence", async () => {
  const {
    resolveProductUpdatePlan,
  } = await import("../src/update_vending_machine_products_core");

  const plan = resolveProductUpdatePlan(
    {
      productId: "asahi_calpis",
      evidenceType: "photo_confirmed",
      availability: "available",
      isActive: true,
    },
    [
      {
        type: "deactivate",
        productId: "asahi_calpis",
      },
    ],
  );

  assert.equal(plan.after.isActive, false);
  assert.equal(plan.after.evidenceType, "photo_confirmed");
  assert.equal(plan.createsDocument, false);
});

test("addConfirmed plus soldOut is order independent", async () => {
  const {
    resolveProductUpdatePlan,
  } = await import("../src/update_vending_machine_products_core");

  const add = {
    type: "addConfirmed" as const,
    productId: "asahi_calpis",
    source: "manual" as const,
  };

  const soldOut = {
    type: "setSoldOut" as const,
    productId: "asahi_calpis",
    soldOut: true,
  };

  const first = resolveProductUpdatePlan(
    null,
    [add, soldOut],
  );
  const second = resolveProductUpdatePlan(
    null,
    [soldOut, add],
  );

  assert.deepEqual(first.after, second.after);
  assert.equal(first.after.availability, "soldOut");
  assert.equal(first.after.evidenceType, "manual_confirmed");
});

test("confirmInferred plus soldOut is order independent", async () => {
  const {
    resolveProductUpdatePlan,
  } = await import("../src/update_vending_machine_products_core");

  const current = {
    productId: "asahi_calpis",
    evidenceType: "manufacturer_inferred" as const,
    availability: "unknown" as const,
    isActive: true,
  };

  const confirm = {
    type: "confirmInferred" as const,
    productId: "asahi_calpis",
  };

  const soldOut = {
    type: "setSoldOut" as const,
    productId: "asahi_calpis",
    soldOut: true,
  };

  const first = resolveProductUpdatePlan(
    current,
    [confirm, soldOut],
  );
  const second = resolveProductUpdatePlan(
    current,
    [soldOut, confirm],
  );

  assert.deepEqual(first.after, second.after);
  assert.equal(first.after.evidenceType, "manual_confirmed");
  assert.equal(first.after.availability, "soldOut");
});

test("soldOut cannot be changed on inferred product without confirmation", async () => {
  const {
    UpdateVendingMachineProductsValidationError,
    resolveProductUpdatePlan,
  } = await import("../src/update_vending_machine_products_core");

  assert.throws(
    () => resolveProductUpdatePlan(
      {
        productId: "asahi_calpis",
        evidenceType: "manufacturer_inferred",
        availability: "unknown",
        isActive: true,
      },
      [
        {
          type: "setSoldOut",
          productId: "asahi_calpis",
          soldOut: true,
        },
      ],
    ),
    UpdateVendingMachineProductsValidationError,
  );
});

test("deactivate cannot be combined with another operation", async () => {
  const {
    UpdateVendingMachineProductsValidationError,
    resolveProductUpdatePlan,
  } = await import("../src/update_vending_machine_products_core");

  assert.throws(
    () => resolveProductUpdatePlan(
      {
        productId: "asahi_calpis",
        evidenceType: "manual_confirmed",
        availability: "available",
        isActive: true,
      },
      [
        {
          type: "deactivate",
          productId: "asahi_calpis",
        },
        {
          type: "setSoldOut",
          productId: "asahi_calpis",
          soldOut: true,
        },
      ],
    ),
    UpdateVendingMachineProductsValidationError,
  );
});

test("addConfirmed and confirmInferred cannot be combined", async () => {
  const {
    UpdateVendingMachineProductsValidationError,
    resolveProductUpdatePlan,
  } = await import("../src/update_vending_machine_products_core");

  assert.throws(
    () => resolveProductUpdatePlan(
      {
        productId: "asahi_calpis",
        evidenceType: "manufacturer_inferred",
        availability: "unknown",
        isActive: true,
      },
      [
        {
          type: "addConfirmed",
          productId: "asahi_calpis",
          source: "manual",
        },
        {
          type: "confirmInferred",
          productId: "asahi_calpis",
        },
      ],
    ),
    UpdateVendingMachineProductsValidationError,
  );
});

test("duplicate operation types are rejected", async () => {
  const {
    UpdateVendingMachineProductsValidationError,
    resolveProductUpdatePlan,
  } = await import("../src/update_vending_machine_products_core");

  assert.throws(
    () => resolveProductUpdatePlan(
      null,
      [
        {
          type: "addConfirmed",
          productId: "asahi_calpis",
          source: "manual",
        },
        {
          type: "addConfirmed",
          productId: "asahi_calpis",
          source: "manual",
        },
      ],
    ),
    UpdateVendingMachineProductsValidationError,
  );
});

test("photo-sourced product IDs are collected for later server verification", async () => {
  const {
    collectPhotoSourcedProductIds,
  } = await import("../src/update_vending_machine_products_core");

  assert.deepEqual(
    collectPhotoSourcedProductIds([
      {
        type: "addConfirmed",
        productId: "asahi_calpis",
        source: "photo",
      },
      {
        type: "addConfirmed",
        productId: "asahi_calpis_water",
        source: "manual",
      },
      {
        type: "setSoldOut",
        productId: "asahi_calpis",
        soldOut: true,
      },
    ]),
    ["asahi_calpis"],
  );
});

test("operations are grouped deterministically by Product ID", async () => {
  const {
    groupProductUpdateOperations,
  } = await import("../src/update_vending_machine_products_core");

  const grouped = groupProductUpdateOperations([
    {
      type: "setSoldOut",
      productId: "asahi_calpis_water",
      soldOut: false,
    },
    {
      type: "addConfirmed",
      productId: "asahi_calpis",
      source: "manual",
    },
    {
      type: "setSoldOut",
      productId: "asahi_calpis",
      soldOut: true,
    },
  ]);

  assert.deepEqual(
    [...grouped.keys()],
    ["asahi_calpis", "asahi_calpis_water"],
  );
  assert.equal(grouped.get("asahi_calpis")?.length, 2);
});
