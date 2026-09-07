import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

const RATE_LIMITED_CONTENT_OPERATIONS = [
  "createVendingMachine",
  "recognizeVendingMachinePhoto",
  "updateVendingMachineProducts",
  "addVendingMachinePhoto",
  "submitMachineCorrection",
  "submitMachineReport",
] as const;

test("all content mutation callables are rate limited", () => {
  const source = readFileSync(
    "src/index.ts",
    "utf8",
  );

  const callCount =
    source.match(/await enforceOperationRateLimit\(/g)?.length ?? 0;

  assert.ok(callCount >= RATE_LIMITED_CONTENT_OPERATIONS.length);

  for (const operation of RATE_LIMITED_CONTENT_OPERATIONS) {
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

test("content block mode uses the same protected callable policy as block actions", () => {
  const source = readFileSync("src/index.ts", "utf8");
  const marker = "export const resolveContentBlockMode = onCall(";
  const start = source.indexOf(marker);

  assert.notEqual(start, -1, "resolveContentBlockMode Callable must exist.");
  const block = source.slice(start, source.indexOf("export const unblockContentSource", start));
  assert.match(block, /enforceAppCheck:\s*enforceAppCheckForRuntime/);
  assert.match(block, /request\.auth === undefined/);
  assert.match(block, /"resolveContentBlockMode"/);
  assert.match(block, /resolveContentBlockModeForUser\(adminFirestore\(\), request\.data\)/);
  assert.doesNotMatch(block, /assertUgcTermsAccepted\(/);
});


test(
  "deleteAccount intentionally uses recent auth instead of content rate limiting",
  () => {
    const source = readFileSync(
      "src/index.ts",
      "utf8",
    );

    const marker =
      "export const deleteAccount = onCall(";

    const index =
      source.indexOf(marker);

    assert.notEqual(
      index,
      -1,
      "deleteAccount Callable must exist.",
    );

    const block =
      source.slice(index);

    assert.match(
      block,
      /enforceAppCheck:\s*enforceAppCheckForRuntime/,
      "deleteAccount must enforce the shared App Check policy.",
    );

    assert.match(
      block,
      /assertRecentAuthentication\(/,
      "deleteAccount must require recent authentication.",
    );

    assert.doesNotMatch(
      block,
      /enforceOperationRateLimit\(/,
      "deleteAccount must remain retryable after partial cleanup.",
    );
  },
);
