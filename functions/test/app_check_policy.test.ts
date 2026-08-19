import assert from "node:assert/strict";
import test from "node:test";

import {shouldEnforceAppCheck} from "../src/app_check_policy";

test("production runtime enforces App Check", () => {
  assert.equal(
    shouldEnforceAppCheck({}),
    true,
  );
});

test("Functions Emulator disables App Check enforcement", () => {
  assert.equal(
    shouldEnforceAppCheck({
      FUNCTIONS_EMULATOR: "true",
    }),
    false,
  );
});

test("only explicit emulator=true disables enforcement", () => {
  assert.equal(
    shouldEnforceAppCheck({
      FUNCTIONS_EMULATOR: "false",
    }),
    true,
  );

  assert.equal(
    shouldEnforceAppCheck({
      FUNCTIONS_EMULATOR: "TRUE",
    }),
    true,
  );
});
