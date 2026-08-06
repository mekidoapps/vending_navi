import assert from "node:assert/strict";
import test from "node:test";

import {buildHealthPayload} from "../src/health_payload";

test("buildHealthPayload returns only the fixed safe fields", () => {
  assert.deepEqual(buildHealthPayload(), {
    ok: true,
    service: "vending-navi-v2-functions",
    mode: "emulator",
  });
});
