import assert from "node:assert/strict";
import {createRequire} from "node:module";
import test from "node:test";

const toolRequire = createRequire(__filename);
const tool = toolRequire("../../../tool/manage_moderation_admin.cjs") as {
  manageModerationAdmin(input: Record<string, unknown>): Promise<string>;
  resolveProjectId(env: Record<string, string | undefined>): string;
};

type Claims = Record<string, unknown>;

function harness({exists = true, status = "active", claims = {}}: {exists?: boolean; status?: string; claims?: Claims} = {}) {
  const writes: Array<{uid: string; claims: Claims}> = [];
  const revocations: string[] = [];
  const account = {uid: "private-uid", email: "private@example.invalid", customClaims: claims};
  const auth = {
    async getUser() { return account; },
    async getUserByEmail() { return account; },
    async setCustomUserClaims(uid: string, nextClaims: Claims) { writes.push({uid, claims: nextClaims}); },
    async revokeRefreshTokens(uid: string) { revocations.push(uid); },
  };
  const firestore = {collection() { return {doc() { return {async get() { return {exists, data: () => exists ? {accountStatus: status, privateProfile: "secret"} : undefined}; }}; }}; }};
  return {auth, firestore, writes, revocations};
}

async function run(operation: string, h = harness(), confirm = async () => true) {
  const output = await tool.manageModerationAdmin({operation, target: "private-uid", projectId: "vendingnavi", auth: h.auth, firestore: h.firestore, confirm});
  return {output, ...h};
}

async function rejectsCode(action: () => Promise<unknown>, code: string) {
  await assert.rejects(action, (error: unknown) => error instanceof Error && error.message === code);
}

test("project guard rejects missing, conflicting, and wrong projects", async () => {
  assert.throws(() => tool.resolveProjectId({}), /project-unresolved/);
  assert.throws(() => tool.resolveProjectId({GOOGLE_CLOUD_PROJECT: "other"}), /wrong-project/);
  assert.throws(() => tool.resolveProjectId({GOOGLE_CLOUD_PROJECT: "vendingnavi", GCLOUD_PROJECT: "other"}), /wrong-project/);
  await rejectsCode(() => tool.manageModerationAdmin({operation: "status", target: "x", projectId: "other", auth: {}, firestore: {}}), "wrong-project");
});

test("missing Auth account is rejected without leaking the target", async () => {
  const h = harness();
  h.auth.getUser = async () => { throw new Error("private-uid"); };
  await rejectsCode(() => run("status", h), "account-not-found");
});

test("status is read-only and returns only the safe summary", async () => {
  const result = await run("status", harness({claims: {admin: true, billing: "kept"}}));
  assert.equal(result.writes.length, 0);
  assert.equal(result.revocations.length, 0);
  assert.match(result.output, /Account resolved: yes/);
  assert.match(result.output, /Admin claim: enabled/);
  assert.doesNotMatch(result.output, /private-uid|private@example|billing|secret|id-token-value/i);
});

test("status reports a missing users document without writing", async () => {
  const result = await run("status", harness({exists: false}));
  assert.match(result.output, /User document: missing/);
  assert.match(result.output, /Account status: unknown/);
  assert.equal(result.writes.length, 0);
});

test("grant rejects missing, restricted, and suspended user state", async () => {
  await rejectsCode(() => run("grant", harness({exists: false})), "user-document-missing");
  await rejectsCode(() => run("grant", harness({status: "restricted"})), "account-not-active");
  await rejectsCode(() => run("grant", harness({status: "suspended"})), "account-not-active");
});

test("grant preserves other claims and only adds admin true", async () => {
  const result = await run("grant", harness({claims: {billing: true, role: "operator"}}));
  assert.deepEqual(result.writes, [{uid: "private-uid", claims: {billing: true, role: "operator", admin: true}}]);
  assert.equal(result.revocations.length, 0);
  assert.match(result.output, /Changed: yes/);
});

test("declined grant confirmation causes no writes", async () => {
  const result = await run("grant", harness(), async () => false);
  assert.equal(result.writes.length, 0);
  assert.equal(result.revocations.length, 0);
  assert.match(result.output, /Changed: no/);
});

test("repeated grant is a safe no-op", async () => {
  const result = await run("grant", harness({claims: {admin: true, other: 1}}));
  assert.equal(result.writes.length, 0);
  assert.match(result.output, /Changed: no/);
});

test("revoke removes only admin, preserves claims, and revokes refresh tokens", async () => {
  const result = await run("revoke", harness({status: "restricted", claims: {admin: true, billing: true, role: "operator"}}));
  assert.deepEqual(result.writes, [{uid: "private-uid", claims: {billing: true, role: "operator"}}]);
  assert.deepEqual(result.revocations, ["private-uid"]);
  assert.match(result.output, /Refresh tokens revoked: yes/);
});

test("declined revoke and repeated revoke are safe no-ops", async () => {
  const declined = await run("revoke", harness({claims: {admin: true}}), async () => false);
  assert.equal(declined.writes.length, 0);
  assert.equal(declined.revocations.length, 0);
  const repeated = await run("revoke", harness({claims: {other: true}}));
  assert.equal(repeated.writes.length, 0);
  assert.equal(repeated.revocations.length, 0);
});

test("safe output never includes UID, email, token, provider, or all claims", async () => {
  for (const operation of ["status", "grant", "revoke"]) {
    const claims = operation === "revoke" ? {admin: true, secretClaim: "private"} : {secretClaim: "private"};
    const {output} = await run(operation, harness({claims}));
    assert.doesNotMatch(output, /private-uid|private@example|secretClaim|provider|token value|\{"/i);
  }
});
