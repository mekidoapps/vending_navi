import assert from "node:assert/strict";
import {createRequire} from "node:module";
import {resolve} from "node:path";
import test from "node:test";

const toolRequire = createRequire(__filename);
const tool = toolRequire("../../../tool/manage_moderation_admin.cjs") as {
  manageModerationAdmin(input: Record<string, unknown>): Promise<string>;
  resolveAdminModules(env: Record<string, string | undefined>): Record<string, unknown>;
  resolveFunctionsPackage(env: Record<string, string | undefined>): string;
  resolveProjectId(env: Record<string, string | undefined>): string;
};

type Claims = Record<string, unknown>;

function harness({exists = true, status = "active", statusFieldExists = true, transactionStatus, transactionStatusFieldExists, claims = {}}: {exists?: boolean; status?: unknown; statusFieldExists?: boolean; transactionStatus?: unknown; transactionStatusFieldExists?: boolean; claims?: Claims} = {}) {
  const writes: Array<{uid: string; claims: Claims}> = [];
  const revocations: string[] = [];
  const firestoreWrites: Claims[] = [];
  const account = {uid: "private-uid", email: "private@example.invalid", customClaims: claims};
  const auth = {
    async getUser() { return account; },
    async getUserByEmail() { return account; },
    async setCustomUserClaims(uid: string, nextClaims: Claims) { writes.push({uid, claims: nextClaims}); },
    async revokeRefreshTokens(uid: string) { revocations.push(uid); },
  };
  const initialData = () => exists ? {...(statusFieldExists ? {accountStatus: status} : {}), privateProfile: "secret"} : undefined;
  const transactionData = () => exists ? {...((transactionStatusFieldExists ?? statusFieldExists) ? {accountStatus: transactionStatus === undefined ? status : transactionStatus} : {}), privateProfile: "secret"} : undefined;
  const reference = {async get() { return {exists, data: initialData}; }};
  const firestore = {
    collection() { return {doc() { return reference; }}; },
    async runTransaction(callback: (transaction: {get(ref: unknown): Promise<unknown>; update(ref: unknown, value: Claims): void}) => Promise<unknown>) {
      return callback({
        async get() { return {exists, data: transactionData}; },
        update(_ref, value) { firestoreWrites.push(value); },
      });
    },
  };
  return {auth, firestore, writes, revocations, firestoreWrites};
}

async function run(operation: string, h = harness(), confirm: (message: string) => Promise<boolean> = async () => true) {
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

test("firebase-admin package exports resolve from the validated functions package boundary", () => {
  const functionsRoot = resolve(__dirname, "../..");
  const packagePath = tool.resolveFunctionsPackage({VENDING_NAVI_FUNCTIONS_ROOT: functionsRoot});
  assert.equal(packagePath.endsWith("package.json"), true);
  const modules = tool.resolveAdminModules({VENDING_NAVI_FUNCTIONS_ROOT: functionsRoot});
  assert.equal(typeof modules.app, "object");
  assert.equal(typeof modules.auth, "object");
  assert.equal(typeof modules.firestore, "object");
});

test("invalid or unavailable dependency roots fail closed with safe errors", () => {
  assert.throws(() => tool.resolveFunctionsPackage({VENDING_NAVI_FUNCTIONS_ROOT: "relative/functions"}), /functions-root-invalid/);
  assert.throws(() => tool.resolveFunctionsPackage({VENDING_NAVI_FUNCTIONS_ROOT: resolve(__dirname, "missing-functions-root")}), /functions-dependencies-unavailable/);
});

test("tool source uses createRequire package exports without node_modules subpath hardcodes", () => {
  const source = require("node:fs").readFileSync(resolve(__dirname, "../../../tool/manage_moderation_admin.cjs"), "utf8");
  assert.match(source, /createRequire\(resolveFunctionsPackage\(env\)\)/);
  for (const packageExport of ["firebase-admin/app", "firebase-admin/auth", "firebase-admin/firestore"]) assert.match(source, new RegExp(`requireFromFunctions\\(\"${packageExport}\"\\)`));
  assert.doesNotMatch(source, /node_modules[\\/]firebase-admin/);
  assert.doesNotMatch(source, /npm (?:install|ci)/);
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

test("normalize-active writes only a missing accountStatus and preserves other fields", async () => {
  let preview = "";
  const result = await run("normalize-active", harness({statusFieldExists: false}), async (message) => { preview = message; return true; });
  for (const expected of ["DRY RUN / PREVIEW", "Project: vendingnavi", "Account: resolved existing account", "accountStatus field: missing", "missing → active", "Other fields: unchanged", "one resolved account only"]) assert.match(preview, new RegExp(expected));
  assert.doesNotMatch(preview, /private-uid|private@example|privateProfile|secret/);
  assert.deepEqual(result.firestoreWrites, [{accountStatus: "active"}]);
  assert.equal(result.writes.length, 0);
  assert.equal(result.revocations.length, 0);
  assert.match(result.output, /Normalization: completed/);
  assert.match(result.output, /Other fields: preserved/);
  assert.doesNotMatch(result.output, /private-uid|private@example|privateProfile|secret/);
});

test("normalize-active is a safe no-op when status is already active", async () => {
  const result = await run("normalize-active", harness({status: "active"}));
  assert.equal(result.firestoreWrites.length, 0);
  assert.match(result.output, /Normalization: not needed/);
});

test("normalize-active rejects restricted, suspended, null, blank, unknown, and non-string states", async () => {
  for (const status of ["restricted", "suspended", null, "", "legacy", 7, false, {value: "active"}]) {
    await rejectsCode(() => run("normalize-active", harness({status})), "account-status-not-normalizable");
  }
});

test("normalize-active rejects missing Auth accounts and user documents", async () => {
  const missingAuth = harness({statusFieldExists: false});
  missingAuth.auth.getUser = async () => { throw new Error("missing"); };
  await rejectsCode(() => run("normalize-active", missingAuth), "account-not-found");
  await rejectsCode(() => run("normalize-active", harness({exists: false, statusFieldExists: false})), "user-document-missing");
});

test("normalize-active confirmation rejection performs no mutation", async () => {
  const result = await run("normalize-active", harness({statusFieldExists: false}), async () => false);
  assert.equal(result.firestoreWrites.length, 0);
  assert.equal(result.writes.length, 0);
  assert.equal(result.revocations.length, 0);
  assert.match(result.output, /Normalization: cancelled/);
});

test("normalize-active transaction reread rejects newly restricted state", async () => {
  const h = harness({statusFieldExists: false, transactionStatusFieldExists: true, transactionStatus: "restricted"});
  await rejectsCode(() => run("normalize-active", h), "account-status-not-normalizable");
  assert.equal(h.firestoreWrites.length, 0);
});

test("normalize-active transaction reread treats newly active state as a safe no-op", async () => {
  const result = await run("normalize-active", harness({statusFieldExists: false, transactionStatusFieldExists: true, transactionStatus: "active"}));
  assert.equal(result.firestoreWrites.length, 0);
  assert.match(result.output, /Normalization: not needed/);
});

test("wrong project blocks normalize-active before account or Firestore access", async () => {
  await rejectsCode(() => tool.manageModerationAdmin({operation: "normalize-active", target: "private-uid", projectId: "other", auth: {}, firestore: {}}), "wrong-project");
});

test("grant preserves other claims and only adds admin true", async () => {
  let preview = "";
  let confirmationReached = false;
  const result = await run("grant", harness({claims: {billing: true, role: "operator"}}), async (message) => {
    preview = message;
    confirmationReached = true;
    return true;
  });
  assert.equal(confirmationReached, true);
  for (const expected of ["Operation: GRANT MODERATION ADMIN", "Project: vendingnavi", "Account: resolved existing account", "Account status: active", "Current admin claim: disabled", "Planned change: admin false/absent → true", "Other claims: preserved"]) assert.match(preview, new RegExp(expected));
  assert.doesNotMatch(preview, /private-uid|private@example|billing|role|operator|token|provider|credential/i);
  assert.deepEqual(result.writes, [{uid: "private-uid", claims: {billing: true, role: "operator", admin: true}}]);
  assert.equal(result.revocations.length, 0);
  assert.match(result.output, /Changed: yes/);
});

test("declined grant confirmation causes no writes", async () => {
  let previewObserved = false;
  const result = await run("grant", harness(), async (message) => {
    previewObserved = /Planned change: admin false\/absent → true/.test(message);
    return false;
  });
  assert.equal(previewObserved, true);
  assert.equal(result.writes.length, 0);
  assert.equal(result.revocations.length, 0);
  assert.match(result.output, /Changed: no/);
});

test("repeated grant is a safe no-op", async () => {
  let confirmationCalled = false;
  const result = await run("grant", harness({claims: {admin: true, other: 1}}), async () => {
    confirmationCalled = true;
    return true;
  });
  assert.equal(confirmationCalled, false);
  assert.equal(result.writes.length, 0);
  assert.match(result.output, /Admin claim: enabled/);
  assert.doesNotMatch(result.output, /Current admin claim: disabled|admin false\/absent → true/);
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
