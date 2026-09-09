import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import test from "node:test";
import {pathToFileURL} from "node:url";
import {runInNewContext} from "node:vm";

const firebaseConfig = JSON.parse(readFileSync("../firebase.json", "utf8"));
const html = readFileSync("../hosting/admin/index.html", "utf8");
const app = readFileSync("../hosting/admin/app.js", "utf8");
const styles = readFileSync("../hosting/admin/styles.css", "utf8");
const config = readFileSync("../hosting/admin/config.js", "utf8");
const queueHelperSource = readFileSync("../hosting/admin/queue.mjs", "utf8");
const detailHelperSource = readFileSync("../hosting/admin/detail.mjs", "utf8");
const mutationHelperSource = readFileSync("../hosting/admin/mutation.mjs", "utf8");
const deleteAccountConfig = readFileSync("../hosting/delete-account/config.js", "utf8");
const runbook = readFileSync("../docs/v2/P25_MODERATION_ADMIN_RUNBOOK.md", "utf8");
const existingRoutes = new Map(firebaseConfig.hosting.rewrites.map((rewrite: {source: string; destination: string}) => [rewrite.source, rewrite.destination]));

function readPublicWebConfig(source: string, globalName: string): unknown {
  const context: {window: Record<string, unknown>} = {window: {}};
  runInNewContext(source, context);
  return JSON.parse(JSON.stringify(context.window[globalName]));
}

test("admin route and static files coexist with existing Hosting pages", () => {
  assert.equal(existingRoutes.get("/admin"), "/admin/index.html");
  assert.equal(existingRoutes.get("/privacy"), "/privacy/index.html");
  assert.equal(existingRoutes.get("/delete-account"), "/delete-account/index.html");
  assert.equal(existingRoutes.get("/terms"), "/terms/index.html");
  assert.match(html, /<meta name="viewport"/);
  assert.match(html, /id="admin-shell" class="hidden"/);
  assert.match(html, /id="boot-view"/);
  assert.ok(styles.length > 0);
});

test("admin authentication uses the canonical web Auth and App Check pattern", () => {
  assert.match(app, /initializeApp\(config\.firebase\)/);
  assert.match(app, /getAuth\(app\)/);
  assert.match(app, /onAuthStateChanged\(auth/);
  assert.match(app, /signInWithEmailAndPassword\(/);
  assert.match(app, /signInWithPopup\(auth, new GoogleAuthProvider\(\)\)/);
  assert.match(app, /initializeAppCheck\(app/);
  assert.match(app, /new ReCaptchaEnterpriseProvider\(config\.appCheckSiteKey\)/);
  assert.match(app, /isTokenAutoRefreshEnabled:\s*true/);
  assert.match(app, /await getToken\(appCheck, true\)/);
  assert.match(app, /getFunctions\(app, "us-central1"\)/);
  assert.match(config, /projectId:\s*"vendingnavi"/);
  assert.deepEqual(
    readPublicWebConfig(config, "VENDING_NAVI_ADMIN_CONFIG"),
    readPublicWebConfig(deleteAccountConfig, "VENDING_NAVI_DELETE_ACCOUNT_CONFIG"),
  );
  assert.doesNotMatch(config, /PRIVATE KEY|client_secret|refresh_token|serviceAccount/i);
});

test("authorization probe and formal queue load remain separate and fail closed", () => {
  assert.match(app, /httpsCallable\(functions, "listModerationQueue"\)/);
  assert.match(app, /await authorizationProbe\(\{limit: 1\}\)/);
  assert.match(app, /authorizedUid = user\.uid;[\s\S]*showView\("admin"\);[\s\S]*await loadQueue\(\{reset: true\}\)/);
  assert.match(app, /const request = cursor === null \? \{limit: queueLimit\} : \{limit: queueLimit, cursor\}/);
  assert.match(app, /functions\/permission-denied/);
  assert.match(app, /showView\("denied"\)/);
  assert.doesNotMatch(app, /innerHTML/);
  assert.doesNotMatch(app, /httpsCallable\(functions, "applyModerationAction"\)/);
  assert.doesNotMatch(app, /firebase-firestore|firebase-storage|firebase-admin/);
});

type QueueHelper = {
  parseQueueResponse(value: unknown): {items: Array<{source: string; id: string; status: string; target: Record<string, string>}>; nextCursor: string | null};
  mergeQueueItems(existing: Array<{source: string; id: string}>, incoming: Array<{source: string; id: string}>, reset: boolean): Array<{source: string; id: string}>;
  sourceLabel(source: string): string;
  statusLabel(status: string): string | undefined;
  targetPresentation(target: Record<string, string>): {label: string; identifier: string};
  formatCreatedAt(value: unknown): string;
};

async function loadQueueHelper(): Promise<QueueHelper> {
  const dynamicImport = new Function("specifier", "return import(specifier)") as (specifier: string) => Promise<QueueHelper>;
  return dynamicImport(pathToFileURL(resolve("../hosting/admin/queue.mjs")).href);
}

type DetailHelper = {
  parseTargetDetail(value: unknown): {target: Record<string, string>; currentStatus: string; publicStatus: string | null; hasPrivateMetadata: boolean; indexIsActive: boolean | null};
  actionsForTarget(targetType: string): string[];
  actionLabel(action: string): string | undefined;
  targetKey(target: Record<string, string>): string;
  validateReason(value: unknown): string | null;
  parseModerationPlan(value: unknown): {allowed: boolean; targetType: string; action: string; currentStatus: string; nextStatus: string | null; requiresStorageDelete: boolean; affectsIndex: boolean; requiresPrivateAudit: boolean};
};

async function loadDetailHelper(): Promise<DetailHelper> {
  const dynamicImport = new Function("specifier", "return import(specifier)") as (specifier: string) => Promise<DetailHelper>;
  return dynamicImport(pathToFileURL(resolve("../hosting/admin/detail.mjs")).href);
}

test("target detail parser accepts each safe target and drops unexpected private fields", async () => {
  const helper = await loadDetailHelper();
  const fixtures = [
    {target: {targetType: "machine", machineId: "m1"}, currentStatus: "active", publicStatus: null, hasPrivateMetadata: false, indexIsActive: null},
    {target: {targetType: "product", machineId: "m1", productId: "p1"}, currentStatus: "active", publicStatus: null, hasPrivateMetadata: false, indexIsActive: true},
    {target: {targetType: "user", targetUserId: "target-user"}, currentStatus: "restricted", publicStatus: null, hasPrivateMetadata: false, indexIsActive: null},
    {target: {targetType: "photo", machineId: "m1", photoId: "photo1"}, currentStatus: "active", publicStatus: "active", hasPrivateMetadata: true, indexIsActive: null},
  ];
  for (const fixture of fixtures) {
    const parsed = helper.parseTargetDetail({...fixture, email: "private", uploadedBy: "private", storagePath: "private"});
    assert.deepEqual(Object.keys(parsed).sort(), ["currentStatus", "hasPrivateMetadata", "indexIsActive", "publicStatus", "target"]);
    assert.deepEqual(parsed.target, fixture.target);
  }
  assert.throws(() => helper.parseTargetDetail({target: {targetType: "machine", machineId: "m1"}, currentStatus: "active"}), /invalid-target-detail/);
  assert.throws(() => helper.parseTargetDetail({...fixtures[0], hasPrivateMetadata: "yes"}), /invalid-target-detail/);
});

test("target-specific actions and reason validation stay within the server contract", async () => {
  const helper = await loadDetailHelper();
  assert.deepEqual(helper.actionsForTarget("machine"), ["underReview", "hidden", "removed", "merged"]);
  assert.deepEqual(helper.actionsForTarget("product"), ["inactive"]);
  assert.deepEqual(helper.actionsForTarget("user"), ["restricted", "suspended", "active"]);
  assert.deepEqual(helper.actionsForTarget("photo"), ["hidden", "deleted"]);
  assert.deepEqual(helper.actionsForTarget("unknown"), []);
  assert.equal(helper.validateReason("  確認済み  "), "確認済み");
  assert.equal(helper.validateReason(""), null);
  assert.equal(helper.validateReason(" ".repeat(4)), null);
  assert.equal(helper.validateReason("あ".repeat(500)), "あ".repeat(500));
  assert.equal(helper.validateReason("あ".repeat(501)), null);
});

test("plan parser accepts safe allowed/disallowed previews and rejects malformed plans", async () => {
  const helper = await loadDetailHelper();
  const allowed = helper.parseModerationPlan({allowed: true, targetType: "photo", action: "deleted", currentStatus: "active", nextStatus: "deleted", requiresStorageDelete: true, affectsIndex: false, requiresPrivateAudit: true, moderatorUid: "private"});
  assert.deepEqual(allowed, {allowed: true, targetType: "photo", action: "deleted", currentStatus: "active", nextStatus: "deleted", requiresStorageDelete: true, affectsIndex: false, requiresPrivateAudit: true});
  const disallowed = helper.parseModerationPlan({allowed: false, targetType: "machine", action: "hidden", currentStatus: "active", nextStatus: null, requiresStorageDelete: false, affectsIndex: false, requiresPrivateAudit: false});
  assert.equal(disallowed.allowed, false);
  assert.equal(disallowed.nextStatus, null);
  assert.throws(() => helper.parseModerationPlan({...allowed, action: "invented"}), /invalid-moderation-plan/);
  assert.throws(() => helper.parseModerationPlan({...allowed, affectsIndex: "yes"}), /invalid-moderation-plan/);
});

test("detail and plan UI use only read callables with stale-response and privacy guards", () => {
  assert.match(app, /httpsCallable\(functions, "getModerationTarget"\)/);
  assert.match(app, /getModerationTargetCallable\(\{target: selectedQueueItem\.target\}\)/);
  assert.match(app, /httpsCallable\(functions, "planModerationAction"\)/);
  assert.match(app, /planModerationActionCallable\(\{target: selectedQueueItem\.target, action\}\)/);
  assert.doesNotMatch(app, /planModerationActionCallable\(\{[^}]*reason/);
  assert.match(app, /generation !== detailGeneration/);
  assert.match(app, /generation !== planGeneration/);
  assert.match(app, /queueItemKey\(selectedQueueItem\) !== selectedKey/);
  assert.match(app, /targetKey\(parsed\.target\) !== expectedTargetKey/);
  assert.match(app, /clearDetailState\(\)/);
  assert.match(app, /photo-delete-warning/);
  assert.match(html, /正式写真を削除します。/);
  assert.match(html, /現在の状態ではこの操作を実行できません。/);
  assert.match(app, /detail\.textContent = value/);
  assert.doesNotMatch(app, /localStorage|indexedDB|innerHTML|JSON\.stringify/);
  assert.doesNotMatch(app, /sessionStorage\.setItem\([^,]+,\s*(?:currentPlan|targetDetail|selectedQueueItem|detailElements\.reason)/);
  assert.doesNotMatch(detailHelperSource, /email|displayName|actorUid|uploadedBy|submittedBy|moderatorUid|storagePath|token|claims/);
  assert.doesNotMatch(app, /httpsCallable\(functions, "applyModerationAction"\)/);
  assert.doesNotMatch(app, /firebase-firestore|getFirestore|getDocs|firebase-storage|firebase-admin/);
});

type MutationHelper = {
  queueRefFromItem(item: {source: string; id: string}): {sourceType: string; itemId: string};
  createPendingOperation(input: Record<string, unknown>): Record<string, unknown>;
  buildMutationRequest(operation: Record<string, unknown>): Record<string, unknown>;
  encodePendingOperation(operation: Record<string, unknown>): string;
  decodePendingOperation(value: string): Record<string, unknown> | null;
  parseMutationResult(value: unknown, operation: Record<string, unknown>): {status: string};
  operationMatchesItem(operation: Record<string, unknown>, item: {source: string; id: string}): boolean;
};

async function loadMutationHelper(): Promise<MutationHelper> {
  const dynamicImport = new Function("specifier", "return import(specifier)") as (specifier: string) => Promise<MutationHelper>;
  return dynamicImport(pathToFileURL(resolve("../hosting/admin/mutation.mjs")).href);
}

test("queue mutation requests use only queueRef, operation values and UUID requestId", async () => {
  const helper = await loadMutationHelper();
  const item = {source: "report", id: "report-1"};
  const ids = ["550e8400-e29b-41d4-a716-446655440001", "550e8400-e29b-41d4-a716-446655440002", "550e8400-e29b-41d4-a716-446655440003"];
  const mark = helper.createPendingOperation({item, operationType: "mark", requestId: ids[0]});
  const noAction = helper.createPendingOperation({item, operationType: "resolve", resolution: "noAction", reason: " 措置不要 ", requestId: ids[1]});
  const rejected = helper.createPendingOperation({item, operationType: "resolve", resolution: "rejected", reason: " 対象外 ", requestId: ids[2]});
  const apply = helper.createPendingOperation({item, operationType: "apply", action: "hidden", reason: " 非表示 ", requestId: ids[2]});
  assert.deepEqual(helper.buildMutationRequest(mark), {queueRef: {sourceType: "report", itemId: "report-1"}, requestId: ids[0]});
  assert.deepEqual(helper.buildMutationRequest(noAction), {queueRef: {sourceType: "report", itemId: "report-1"}, requestId: ids[1], resolution: "noAction", reason: "措置不要"});
  assert.deepEqual(helper.buildMutationRequest(rejected), {queueRef: {sourceType: "report", itemId: "report-1"}, requestId: ids[2], resolution: "rejected", reason: "対象外"});
  assert.deepEqual(helper.buildMutationRequest(apply), {queueRef: {sourceType: "report", itemId: "report-1"}, requestId: ids[2], action: "hidden", reason: "非表示"});
  assert.throws(() => helper.createPendingOperation({item, operationType: "mark", requestId: "not-uuid"}), /invalid-pending-operation/);
});

test("pending retry state persists only the safe allowlist and retains the same requestId", async () => {
  const helper = await loadMutationHelper();
  const requestId = "550e8400-e29b-41d4-a716-446655440004";
  const operation = helper.createPendingOperation({item: {source: "correction", id: "correction-1"}, operationType: "apply", action: "deleted", reason: "削除", requestId});
  const encoded = helper.encodePendingOperation(operation);
  const decoded = helper.decodePendingOperation(encoded);
  assert.deepEqual(decoded, operation);
  assert.equal(decoded?.requestId, requestId);
  assert.deepEqual(Object.keys(decoded ?? {}).sort(), ["action", "operationType", "queueRef", "reason", "requestId", "state"]);
  assert.deepEqual(Object.keys((decoded?.queueRef as Record<string, unknown>) ?? {}).sort(), ["itemId", "sourceType"]);
  assert.equal(helper.operationMatchesItem(operation, {source: "correction", id: "correction-1"}), true);
  assert.equal(helper.decodePendingOperation(JSON.stringify({...operation, uid: "private"})), null);
  assert.equal(helper.decodePendingOperation("not-json"), null);
});

test("safe mutation results accept mark, resolve, action and completed replay shapes", async () => {
  const helper = await loadMutationHelper();
  const item = {source: "report", id: "item-1"};
  const requestId = "550e8400-e29b-41d4-a716-446655440005";
  const mark = helper.createPendingOperation({item, operationType: "mark", requestId});
  const resolve = helper.createPendingOperation({item, operationType: "resolve", resolution: "rejected", reason: "却下", requestId});
  const apply = helper.createPendingOperation({item, operationType: "apply", action: "deleted", reason: "削除", requestId});
  assert.deepEqual(helper.parseMutationResult({sourceType: "report", itemId: "item-1", status: "inReview", changed: false, target: {private: true}}, mark), {status: "inReview"});
  assert.deepEqual(helper.parseMutationResult({sourceType: "report", itemId: "item-1", status: "resolved", resolution: "rejected", target: {private: true}}, resolve), {status: "resolved"});
  assert.deepEqual(helper.parseMutationResult({ok: true, sourceType: "report", itemId: "item-1", status: "resolved", resolution: "actionTaken", action: "deleted", storagePath: "private"}, apply), {status: "resolved"});
  assert.throws(() => helper.parseMutationResult({sourceType: "report", itemId: "other", status: "inReview", changed: true}, mark), /invalid-mutation-result/);
});

test("mutation UI enforces preflight plan, duplicate prevention, safe retry and lifecycle refresh", () => {
  assert.match(app, /httpsCallable\(functions, "markModerationItemInReview"\)/);
  assert.match(app, /httpsCallable\(functions, "resolveModerationItem"\)/);
  assert.match(app, /httpsCallable\(functions, "applyModerationQueueAction"\)/);
  assert.doesNotMatch(app, /httpsCallable\(functions, "applyModerationAction"\)/);
  assert.match(app, /crypto\.randomUUID\(\)/);
  assert.match(app, /if \(mutationLoading \|\| selectedQueueItem === null/);
  assert.match(app, /planModerationActionCallable\(\{target: selectedQueueItem\.target, action: operation\.action\}\)/);
  assert.match(app, /const response = await callableForOperation\(operation\.operationType\)\(buildMutationRequest\(operation\)\)/);
  assert.match(app, /persistPendingOperation\(operation\)/);
  assert.match(app, /retryPendingMutation[\s\S]*runMutation\(pendingOperation\)/);
  assert.match(app, /await loadQueue\(\{reset: true\}\)/);
  assert.match(app, /operation\.operationType === "mark"/);
  assert.match(app, /selectedQueueItem\.status === "resolutionPending"/);
  assert.match(app, /pendingOperation\.action === "deleted"/);
  assert.match(app, /mutationGeneration/);
  assert.match(app, /generation !== mutationGeneration/);
  assert.match(app, /clearPendingOperation\(\)/);
  assert.match(app, /recoverPendingOperation\(\)/);
  assert.doesNotMatch(app, /recoverPendingOperation[\s\S]{0,300}runMutation/);
  assert.match(html, /確認を開始/);
  assert.match(html, /措置なしで完了/);
  assert.match(html, /通報・修正提案を却下/);
  assert.match(html, /確認して実行/);
  assert.match(html, /同じ処理を再試行/);
  assert.match(html, /aria-busy="true"/);
  assert.doesNotMatch(mutationHelperSource, /\buid\b|email|token|claim|actorUid|uploadedBy|moderatorUid|storagePath|Firestore|bucket/i);
});

test("safe queue parser accepts report/correction targets and visible statuses", async () => {
  const helper = await loadQueueHelper();
  const cursor = "opaque-server-cursor";
  const parsed = helper.parseQueueResponse({items: [
    {source: "report", id: "r1", target: {targetType: "photo", machineId: "m1", photoId: "p1"}, categoryOrReason: "不適切な写真", createdAt: {_seconds: 1780000000, _nanoseconds: 0}, status: "new"},
    {source: "correction", id: "c1", target: {targetType: "product", machineId: "m1", productId: "d1"}, categoryOrReason: "商品違い", createdAt: {seconds: 1780000001, nanoseconds: 0}, status: "inReview"},
    {source: "report", id: "r2", target: {targetType: "user", targetUserId: "safe-target"}, categoryOrReason: null, createdAt: {}, status: "resolutionPending"},
  ], nextCursor: cursor});
  assert.equal(parsed.nextCursor, cursor);
  assert.deepEqual(parsed.items.map((item) => item.status), ["new", "inReview", "resolutionPending"]);
  assert.equal(helper.sourceLabel(parsed.items[0].source), "通報");
  assert.equal(helper.sourceLabel(parsed.items[1].source), "修正提案");
  assert.deepEqual(parsed.items.map((item) => helper.statusLabel(item.status)), ["未対応", "確認中", "処理中"]);
  assert.equal(helper.targetPresentation(parsed.items[0].target).identifier, "m1 / p1");
  assert.equal(helper.targetPresentation(parsed.items[1].target).identifier, "m1 / d1");
  assert.equal(helper.targetPresentation(parsed.items[2].target).identifier, "非公開");
  assert.notEqual(helper.formatCreatedAt({_seconds: 1780000000, _nanoseconds: 0}), "日時不明");
  assert.equal(helper.formatCreatedAt({}), "日時不明");
  const firstPage = [{source: "report", id: "same"}, {source: "report", id: "first"}];
  const merged = helper.mergeQueueItems(firstPage, [{source: "report", id: "same"}, {source: "correction", id: "same"}], false);
  assert.deepEqual(merged.map((item) => `${item.source}:${item.id}`), ["report:same", "report:first", "correction:same"]);
});

test("safe queue parser drops malformed, resolved, unknown and private response data", async () => {
  const helper = await loadQueueHelper();
  const parsed = helper.parseQueueResponse({items: [
    {source: "report", id: "safe", target: {targetType: "machine", machineId: "m1", actorUid: "private"}, categoryOrReason: "確認", createdAt: {}, status: "new", moderatorUid: "private", storagePath: "private"},
    {source: "report", id: "resolved", target: {targetType: "machine", machineId: "m2"}, status: "resolved"},
    {source: "unknown", id: "unknown", target: {targetType: "machine", machineId: "m3"}, status: "new"},
    {source: "report", id: "bad", target: {targetType: "unknown", machineId: "m4"}, status: "new"},
  ], nextCursor: null});
  assert.equal(parsed.items.length, 1);
  assert.deepEqual(Object.keys(parsed.items[0]).sort(), ["categoryOrReason", "createdAt", "id", "source", "status", "target"]);
  assert.deepEqual(parsed.items[0].target, {targetType: "machine", machineId: "m1"});
  assert.throws(() => helper.parseQueueResponse({items: [{source: "unknown"}], nextCursor: null}), /invalid-queue-response/);
  assert.throws(() => helper.parseQueueResponse({items: [], nextCursor: {offset: 1}}), /invalid-queue-response/);
});

test("queue UI supports safe loading, empty, retry, refresh and opaque pagination", () => {
  for (const id of ["refresh-queue", "queue-loading", "queue-empty", "queue-error", "retry-queue", "queue-items", "queue-page-loading", "load-more-queue"]) assert.match(html, new RegExp(`id="${id}"`));
  assert.match(html, /現在、確認待ちの項目はありません。/);
  assert.match(app, /if \(queueLoading \|\| authorizedUid === null\) return/);
  assert.match(app, /queueItems = mergeQueueItems\(queueItems, parsed\.items, reset\)/);
  assert.match(queueHelperSource, /new Set\(merged\.map\(queueItemKey\)\)/);
  assert.match(app, /const generation = \+\+queueGeneration/);
  assert.match(app, /generation !== queueGeneration/);
  assert.match(app, /queueGeneration \+= 1/);
  assert.match(app, /queueElements\.items\.replaceChildren\(\)/);
  assert.match(app, /\.textContent =/);
  assert.doesNotMatch(app, /JSON\.stringify|localStorage|indexedDB|innerHTML|insertAdjacentHTML/);
  assert.doesNotMatch(queueHelperSource, /moderatorUid|submittedBy|uploadedBy|storagePath|displayName|email/);
});

test("logout clears admin state and error output remains privacy-safe", () => {
  assert.match(app, /clearAdminState\(\);\s*await signOut\(auth\)/);
  assert.match(app, /sessionStorage\.removeItem\(key\)/);
  assert.match(app, /passwordInput\.value = ""/);
  assert.doesNotMatch(app, /console\.(?:error|log|warn)/);
  assert.match(app, /const authUserChanged = observedAuthUid !== null && nextUid !== observedAuthUid/);
  assert.match(app, /clearAdminState\(\{clearPending: nextUid === null \|\| authUserChanged\}\)/);
  for (const forbidden of ["claim値", "accountStatus", "UID", "document path", "storagePath", "stack trace"]) {
    assert.equal(html.includes(forbidden), false);
  }
});

test("admin route receives basic scoped security headers without changing existing routes", () => {
  for (const source of ["/admin", "/admin/**"]) {
    const adminHeaders = firebaseConfig.hosting.headers.find((entry: {source: string}) => entry.source === source);
    assert.ok(adminHeaders);
    const values = new Map(adminHeaders.headers.map((header: {key: string; value: string}) => [header.key, header.value]));
    assert.equal(values.get("X-Content-Type-Options"), "nosniff");
    assert.equal(values.get("Referrer-Policy"), "no-referrer");
    assert.equal(values.get("Permissions-Policy"), "camera=(), microphone=(), geolocation=()");
    assert.equal(values.get("X-Frame-Options"), "DENY");
    const csp = values.get("Content-Security-Policy");
    if (typeof csp !== "string") assert.fail("Admin CSP header is required.");
    assert.match(csp, /default-src 'none'/);
    assert.match(csp, /frame-ancestors 'none'/);
    assert.match(csp, /script-src 'self' https:\/\/www\.gstatic\.com https:\/\/www\.google\.com https:\/\/www\.recaptcha\.net/);
    assert.match(csp, /connect-src 'self'[^;]*https:\/\/identitytoolkit\.googleapis\.com[^;]*https:\/\/securetoken\.googleapis\.com[^;]*https:\/\/firebaseappcheck\.googleapis\.com[^;]*https:\/\/us-central1-vendingnavi\.cloudfunctions\.net/);
    assert.match(csp, /frame-src[^;]*https:\/\/accounts\.google\.com[^;]*https:\/\/vendingnavi\.firebaseapp\.com[^;]*https:\/\/www\.google\.com[^;]*https:\/\/www\.recaptcha\.net/);
    assert.doesNotMatch(csp, /unsafe-inline|unsafe-eval|(?:^|\s)\*(?:\s|;|$)/);
  }
  assert.ok(firebaseConfig.hosting.headers.some((entry: {source: string; headers: Array<{key: string; value: string}>}) => entry.source === "**" && entry.headers.some((header) => header.key === "Cache-Control" && header.value === "no-store")));
});

test("admin hardening keeps static rendering and approved callable boundaries", () => {
  assert.doesNotMatch(html, /<script(?![^>]+src=)/);
  assert.doesNotMatch(html, /style=/);
  assert.doesNotMatch(app, /innerHTML|insertAdjacentHTML|document\.write|\beval\s*\(|new Function|console\.(?:log|warn|error)/);
  for (const callable of ["listModerationQueue", "getModerationTarget", "planModerationAction", "markModerationItemInReview", "resolveModerationItem", "applyModerationQueueAction"]) {
    assert.match(app, new RegExp(`httpsCallable\\(functions, "${callable}"\\)`));
  }
  assert.doesNotMatch(app, /httpsCallable\(functions, "applyModerationAction"\)/);
  assert.doesNotMatch(app, /getFirestore|\bcollection\s*\(|\bdoc\s*\(|getDoc|getDocs|writeBatch|runTransaction|firebase-firestore|firebase-storage|firebase-admin/);
  assert.doesNotMatch(app, /appCheckDebugToken|connectFunctionsEmulator|fetch\s*\(/);
});

test("moderation admin runbook fixes bootstrap, revocation, rollback and smoke contracts", () => {
  for (const text of ["管理者の初期登録", "admin: true", "accountStatus", "refresh token", "管理者権限の失効", "正式写真の削除", "resolutionPending", "同一requestId", "Hosting rollback", "一般ユーザー拒否", "管理者read-only確認", "最小mutation確認", "WAIVED"]) assert.match(runbook, new RegExp(text));
  assert.match(runbook, /正式な運用スクリプトは存在しない/);
  assert.match(runbook, /Hostingだけを戻す/);
  assert.match(runbook, /Functions、indexes、Rules、Storage、Productionデータは同時にrollbackしない/);
  assert.match(runbook, /UID、メールアドレス、token、secret、credential、Firestore\/Storage pathを残さない/);
  assert.doesNotMatch(runbook, /PRIVATE KEY|client_secret|refresh_token|serviceAccount/i);
});
