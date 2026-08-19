import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

const PUBLIC_OPERATIONS = [
  "createVendingMachine",
  "recognizeVendingMachinePhoto",
  "updateVendingMachineProducts",
  "addVendingMachinePhoto",
  "submitMachineCorrection",
  "submitMachineReport",
] as const;

test("all public v2 mutation callables are rate limited", () => {
  const source = readFileSync(
    "src/index.ts",
    "utf8",
  );

  const callCount =
    source.match(/await enforceOperationRateLimit\(/g)?.length ?? 0;

  assert.equal(callCount, PUBLIC_OPERATIONS.length);

  for (const operation of PUBLIC_OPERATIONS) {
    assert.match(
      source,
      new RegExp(
        `enforceOperationRateLimit\\([\\s\\S]*?` +
        `"${operation}"`,
      ),
      `${operation} must use the shared operation rate limiter`,
    );
  }
});
