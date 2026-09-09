import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

const moderationCallables = [
  "listModerationQueue",
  "getModerationTarget",
  "planModerationAction",
  "applyModerationAction",
  "markModerationItemInReview",
  "resolveModerationItem",
  "applyModerationQueueAction",
] as const;

test("release verification inventories every Phase 22-C moderation callable", () => {
  const verifier = readFileSync("../tool/verify_firebase_release_config.sh", "utf8");
  const source = readFileSync("src/index.ts", "utf8");

  for (const callable of moderationCallables) {
    assert.match(source, new RegExp(`export const ${callable}\\s*=`));
    assert.match(verifier, new RegExp(`"${callable}"`));
  }
});

test("production deploy wrapper retains its narrow safety guards", () => {
  const wrapper = readFileSync("../tool/deploy_firebase_production.sh", "utf8");

  assert.match(wrapper, /\[\[ -z "\$\(git status --short\)" \]\]/);
  assert.match(wrapper, /VENDING_NAVI_RELEASE_SHA/);
  assert.match(wrapper, /VENDING_NAVI_DEPLOY_PROJECT/);
  assert.match(wrapper, /"functions:v2"/);
  assert.match(wrapper, /firebase deploy/);
  assert.match(wrapper, /--only "\$deploy_scope"/);
});
