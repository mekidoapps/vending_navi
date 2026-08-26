import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

import {resolveMasterEmulatorConfig} from "./master_emulator_config";

const EXPECTED_MANUFACTURERS = 7;
const EXPECTED_PRODUCTS = 96;
const EXPECTED_PRESETS = 33;

async function main(): Promise<void> {
  const config = resolveMasterEmulatorConfig();

  initializeApp({
    projectId: config.projectId,
  });

  const firestore = getFirestore();

  const [manufacturerSnapshot, productSnapshot] = await Promise.all([
    firestore.collection("manufacturers").get(),
    firestore.collection("products").get(),
  ]);

  assertEqual(
    manufacturerSnapshot.size,
    EXPECTED_MANUFACTURERS,
    "manufacturer count",
  );

  assertEqual(
    productSnapshot.size,
    EXPECTED_PRODUCTS,
    "product count",
  );

  const products = new Map(
    productSnapshot.docs.map((document) => [
      document.id,
      document.data(),
    ]),
  );

  let presetTotal = 0;

  for (const manufacturerDocument of manufacturerSnapshot.docs) {
    const manufacturerId = manufacturerDocument.id;
    const data = manufacturerDocument.data();
    const rawPresetProductIds = data.presetProductIds;

    if (!Array.isArray(rawPresetProductIds)) {
      throw new Error(
        `${manufacturerId}: presetProductIds must be an array.`,
      );
    }

    const seen = new Set<string>();

    for (const value of rawPresetProductIds) {
      if (typeof value !== "string" || value.trim().length === 0) {
        throw new Error(
          `${manufacturerId}: invalid preset Product ID.`,
        );
      }

      const productId = value.trim();

      if (!seen.add(productId)) {
        throw new Error(
          `${manufacturerId}: duplicate preset Product ID ${productId}.`,
        );
      }

      const product = products.get(productId);

      if (product === undefined) {
        throw new Error(
          `${manufacturerId}: preset product ${productId} does not exist.`,
        );
      }

      if (product.manufacturerId !== manufacturerId) {
        throw new Error(
          `${manufacturerId}: preset product ${productId} belongs to ` +
            `${String(product.manufacturerId)}.`,
        );
      }

      if (product.isActive !== true) {
        throw new Error(
          `${manufacturerId}: preset product ${productId} is inactive.`,
        );
      }

      presetTotal += 1;
    }
  }

  assertEqual(
    presetTotal,
    EXPECTED_PRESETS,
    "preset product count",
  );

  console.log(
    [
      "P11_MASTER_FIXTURE_COUNTS_OK",
      `project=${config.projectId}`,
      `manufacturers=${manufacturerSnapshot.size}`,
      `products=${productSnapshot.size}`,
      `presets=${presetTotal}`,
    ].join(" "),
  );
}

function assertEqual(
  actual: number,
  expected: number,
  label: string,
): void {
  if (actual !== expected) {
    throw new Error(
      `${label}: expected=${expected} actual=${actual}`,
    );
  }
}

void main().catch((error: unknown) => {
  console.error(
    "P11 master fixture count verification failed.",
    error,
  );
  process.exitCode = 1;
});
