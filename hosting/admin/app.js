import {initializeApp} from "https://www.gstatic.com/firebasejs/11.10.0/firebase-app.js";
import {
  GoogleAuthProvider,
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signInWithPopup,
  signOut,
} from "https://www.gstatic.com/firebasejs/11.10.0/firebase-auth.js";
import {
  ReCaptchaEnterpriseProvider,
  getToken,
  initializeAppCheck,
} from "https://www.gstatic.com/firebasejs/11.10.0/firebase-app-check.js";
import {getFunctions, httpsCallable} from "https://www.gstatic.com/firebasejs/11.10.0/firebase-functions.js";
import {formatCreatedAt, mergeQueueItems, parseQueueResponse, sourceLabel, statusLabel, targetPresentation} from "./queue.mjs";
import {actionLabel, actionsForTarget, parseModerationPlan, parseTargetDetail, targetKey, validateReason} from "./detail.mjs";
import {buildMutationRequest, createPendingOperation, decodePendingOperation, encodePendingOperation, operationMatchesItem, parseMutationResult} from "./mutation.mjs";

const config = window.VENDING_NAVI_ADMIN_CONFIG;
const views = {
  boot: document.querySelector("#boot-view"),
  login: document.querySelector("#login-view"),
  denied: document.querySelector("#access-denied-view"),
  connectionError: document.querySelector("#connection-error-view"),
  admin: document.querySelector("#admin-shell"),
};
const setupError = document.querySelector("#setup-error");
const status = document.querySelector("#status");
const connectionErrorMessage = document.querySelector("#connection-error-message");
const queueElements = {
  refresh: document.querySelector("#refresh-queue"), loading: document.querySelector("#queue-loading"),
  empty: document.querySelector("#queue-empty"), error: document.querySelector("#queue-error"),
  errorMessage: document.querySelector("#queue-error-message"), retry: document.querySelector("#retry-queue"),
  items: document.querySelector("#queue-items"), pageLoading: document.querySelector("#queue-page-loading"),
  loadMore: document.querySelector("#load-more-queue"),
};
const adminViews = {
  queue: document.querySelector("#queue-view"), detail: document.querySelector("#detail-view"), plan: document.querySelector("#plan-view"),
  mutationConfirm: document.querySelector("#mutation-confirm-view"), mutationProgress: document.querySelector("#mutation-progress-view"),
  mutationError: document.querySelector("#mutation-error-view"),
};
const mutationElements = {
  actions: document.querySelector("#queue-mutation-actions"), mark: document.querySelector("#mark-in-review"),
  noAction: document.querySelector("#resolve-no-action"), rejected: document.querySelector("#resolve-rejected"),
  recovery: document.querySelector("#pending-recovery"), recoveryMessage: document.querySelector("#pending-recovery-message"),
  retry: document.querySelector("#retry-mutation"), prepareAction: document.querySelector("#prepare-action"),
  confirmSummary: document.querySelector("#mutation-confirm-summary"), confirmWarning: document.querySelector("#mutation-confirm-warning"),
  confirm: document.querySelector("#confirm-mutation"), errorMessage: document.querySelector("#mutation-error-message"),
  errorRetry: document.querySelector("#mutation-error-retry"),
};
const detailElements = {
  loading: document.querySelector("#detail-loading"), error: document.querySelector("#detail-error"),
  errorMessage: document.querySelector("#detail-error-message"), retry: document.querySelector("#retry-detail"),
  content: document.querySelector("#detail-content"), summary: document.querySelector("#detail-summary"),
  action: document.querySelector("#moderation-action"), reason: document.querySelector("#moderation-reason"),
  reasonError: document.querySelector("#reason-error"), preview: document.querySelector("#preview-plan"),
};
const planElements = {
  loading: document.querySelector("#plan-loading"), error: document.querySelector("#plan-error"),
  errorMessage: document.querySelector("#plan-error-message"), retry: document.querySelector("#retry-plan"),
  content: document.querySelector("#plan-content"), summary: document.querySelector("#plan-summary"),
  disallowed: document.querySelector("#plan-disallowed"), photoDelete: document.querySelector("#photo-delete-warning"),
  indexUpdate: document.querySelector("#index-update-warning"),
};
const emailSignInForm = document.querySelector("#email-sign-in-form");
const googleSignInButton = document.querySelector("#google-sign-in");
const retryAuthorizationButton = document.querySelector("#retry-authorization");
const adminSessionPrefix = "vendingNaviAdmin.";
const pendingOperationKey = `${adminSessionPrefix}pendingModerationOperation`;

let auth;
let appCheck;
let authorizationProbe;
let getModerationTargetCallable;
let planModerationActionCallable;
let markModerationItemInReviewCallable;
let resolveModerationItemCallable;
let applyModerationQueueActionCallable;
let authorizationGeneration = 0;
let queueGeneration = 0;
let queueLoading = false;
let queueItems = [];
let nextQueueCursor = null;
let authorizedUid = null;
let selectedQueueItem = null;
let targetDetail = null;
let detailGeneration = 0;
let planGeneration = 0;
let pendingPlanInput = null;
let currentPlan = null;
let pendingOperation = null;
let preparedOperation = null;
let mutationLoading = false;
let mutationGeneration = 0;
let observedAuthUid = null;
const queueLimit = 25;

function hasRequiredConfiguration(value) {
  return value &&
    value.firebase &&
    value.firebase.apiKey &&
    value.firebase.authDomain &&
    value.firebase.projectId &&
    value.firebase.appId &&
    value.appCheckSiteKey &&
    !Object.values(value.firebase).some((entry) => String(entry).startsWith("REPLACE_")) &&
    !String(value.appCheckSiteKey).startsWith("REPLACE_");
}

function showView(name) {
  Object.entries(views).forEach(([viewName, element]) => {
    element.classList.toggle("hidden", viewName !== name);
  });
}

function showStatus(message, type = "") {
  status.textContent = message;
  status.className = `notice ${type}`.trim();
}

function hideStatus() {
  status.textContent = "";
  status.className = "notice hidden";
}

function setLoginBusy(busy) {
  emailSignInForm.querySelectorAll("button, input").forEach((element) => {
    element.disabled = busy;
  });
  googleSignInButton.disabled = busy;
}

function clearAdminState({clearPending = true} = {}) {
  authorizationGeneration += 1;
  queueGeneration += 1;
  queueLoading = false;
  queueItems = [];
  nextQueueCursor = null;
  authorizedUid = null;
  mutationGeneration += 1;
  mutationLoading = false;
  preparedOperation = null;
  currentPlan = null;
  if (clearPending) {
    pendingOperation = null;
    sessionStorage.removeItem(pendingOperationKey);
  }
  clearDetailState();
  queueElements.items.replaceChildren();
  setQueueState("clear");
  connectionErrorMessage.textContent = "";
  hideStatus();
  if (clearPending) {
    for (let index = sessionStorage.length - 1; index >= 0; index -= 1) {
      const key = sessionStorage.key(index);
      if (key?.startsWith(adminSessionPrefix)) sessionStorage.removeItem(key);
    }
  }
}

function showAdminView(name) {
  Object.entries(adminViews).forEach(([viewName, element]) => element.classList.toggle("hidden", viewName !== name));
}

function clearDetailState() {
  detailGeneration += 1;
  planGeneration += 1;
  selectedQueueItem = null;
  targetDetail = null;
  pendingPlanInput = null;
  currentPlan = null;
  preparedOperation = null;
  detailElements.summary.replaceChildren();
  planElements.summary.replaceChildren();
  detailElements.action.replaceChildren();
  detailElements.reason.value = "";
  detailElements.reasonError.classList.add("hidden");
  detailElements.content.classList.add("hidden");
  detailElements.error.classList.add("hidden");
  planElements.content.classList.add("hidden");
  planElements.error.classList.add("hidden");
  planElements.disallowed.classList.add("hidden");
  planElements.photoDelete.classList.add("hidden");
  planElements.indexUpdate.classList.add("hidden");
  mutationElements.recovery.classList.add("hidden");
  showAdminView("queue");
}

function setQueueState(state) {
  queueElements.loading.classList.toggle("hidden", state !== "loading");
  queueElements.empty.classList.toggle("hidden", state !== "empty");
  queueElements.error.classList.toggle("hidden", state !== "error");
  queueElements.pageLoading.classList.toggle("hidden", state !== "page-loading");
  queueElements.refresh.disabled = queueLoading;
  queueElements.loadMore.disabled = queueLoading;
  queueElements.loadMore.classList.toggle("hidden", queueLoading || nextQueueCursor === null || state === "error");
}

function addDetail(list, label, value) {
  const term = document.createElement("dt");
  term.textContent = label;
  const detail = document.createElement("dd");
  detail.textContent = value;
  list.append(term, detail);
}

function renderQueue() {
  queueElements.items.replaceChildren();
  for (const item of queueItems) {
    const card = document.createElement("article");
    card.className = "queue-item";
    const select = document.createElement("button");
    select.type = "button";
    select.className = "queue-item-select";
    select.setAttribute("aria-label", `${sourceLabel(item.source)}の対象情報を確認`);
    const heading = document.createElement("div");
    heading.className = "queue-item-heading";
    const title = document.createElement("h3");
    title.textContent = sourceLabel(item.source);
    const state = document.createElement("span");
    state.className = `queue-status${item.status === "resolutionPending" ? " resolution-pending" : ""}`;
    state.textContent = statusLabel(item.status);
    heading.append(title, state);
    const details = document.createElement("dl");
    details.className = "queue-detail";
    const target = targetPresentation(item.target);
    addDetail(details, "対象", target.label);
    addDetail(details, "対象ID", target.identifier);
    addDetail(details, "内容", item.categoryOrReason ?? "記載なし");
    addDetail(details, "受信日時", formatCreatedAt(item.createdAt));
    select.append(heading, details);
    select.addEventListener("click", () => selectQueueItem(item));
    card.append(select);
    queueElements.items.append(card);
  }
}

function setDetailState(state) {
  detailElements.loading.classList.toggle("hidden", state !== "loading");
  detailElements.error.classList.toggle("hidden", state !== "error");
  detailElements.content.classList.toggle("hidden", state !== "success");
}

function setPlanState(state) {
  planElements.loading.classList.toggle("hidden", state !== "loading");
  planElements.error.classList.toggle("hidden", state !== "error");
  planElements.content.classList.toggle("hidden", state !== "success");
}

function selectQueueItem(item) {
  selectedQueueItem = item;
  targetDetail = null;
  pendingPlanInput = null;
  currentPlan = null;
  planGeneration += 1;
  showAdminView("detail");
  void loadTargetDetail();
}

function renderTargetDetail(detail) {
  detailElements.summary.replaceChildren();
  const queueTarget = targetPresentation(selectedQueueItem.target);
  addDetail(detailElements.summary, "受付種別", sourceLabel(selectedQueueItem.source));
  addDetail(detailElements.summary, "受付状態", statusLabel(selectedQueueItem.status));
  addDetail(detailElements.summary, "対象", queueTarget.label);
  addDetail(detailElements.summary, "対象ID", queueTarget.identifier);
  addDetail(detailElements.summary, "受付内容", selectedQueueItem.categoryOrReason ?? "記載なし");
  addDetail(detailElements.summary, "受付日時", formatCreatedAt(selectedQueueItem.createdAt));
  addDetail(detailElements.summary, "現在の状態", detail.currentStatus);
  if (detail.publicStatus !== null) addDetail(detailElements.summary, "公開状態", detail.publicStatus);
  if (detail.target.targetType === "photo") addDetail(detailElements.summary, "非公開管理情報", detail.hasPrivateMetadata ? "あり" : "なし");
  if (detail.indexIsActive !== null) addDetail(detailElements.summary, "検索インデックス", detail.indexIsActive ? "有効" : "無効");
  detailElements.action.replaceChildren();
  for (const action of actionsForTarget(detail.target.targetType)) {
    const option = document.createElement("option");
    option.value = action;
    option.textContent = actionLabel(action);
    detailElements.action.append(option);
  }
  const canResolve = selectedQueueItem.status === "new" || selectedQueueItem.status === "inReview";
  const pending = selectedQueueItem.status === "resolutionPending";
  mutationElements.actions.classList.toggle("hidden", !canResolve);
  mutationElements.mark.classList.toggle("hidden", selectedQueueItem.status !== "new");
  mutationElements.noAction.disabled = !canResolve;
  mutationElements.rejected.disabled = !canResolve;
  detailElements.action.disabled = pending;
  detailElements.reason.disabled = pending;
  detailElements.preview.disabled = pending;
  const canRecover = pendingOperation !== null && operationMatchesItem(pendingOperation, selectedQueueItem) &&
    (!pending || (pendingOperation.operationType === "apply" && pendingOperation.action === "deleted"));
  mutationElements.recovery.classList.toggle("hidden", !canRecover);
  if (canRecover) mutationElements.recoveryMessage.textContent = pending ? "写真の削除処理を再開できます。" : "中断した処理を同じ受付番号で再開できます。";
}

async function loadTargetDetail() {
  if (selectedQueueItem === null || authorizedUid === null) return;
  const generation = ++detailGeneration;
  const selectedKey = queueItemKey(selectedQueueItem);
  const expectedTargetKey = targetKey(selectedQueueItem.target);
  const expectedUid = authorizedUid;
  currentPlan = null;
  pendingPlanInput = null;
  planGeneration += 1;
  setDetailState("loading");
  try {
    await getToken(appCheck);
    const response = await getModerationTargetCallable({target: selectedQueueItem.target});
    const parsed = parseTargetDetail(response.data);
    if (generation !== detailGeneration || authorizedUid !== expectedUid || auth.currentUser?.uid !== expectedUid ||
        selectedQueueItem === null || queueItemKey(selectedQueueItem) !== selectedKey || targetKey(parsed.target) !== expectedTargetKey) return;
    targetDetail = parsed;
    renderTargetDetail(parsed);
    setDetailState("success");
  } catch (error) {
    if (generation !== detailGeneration || authorizedUid !== expectedUid || selectedQueueItem === null || queueItemKey(selectedQueueItem) !== selectedKey) return;
    const code = safeErrorCode(error);
    if (await handleQueueAuthorizationFailure(code)) return;
    detailElements.errorMessage.textContent = code === "functions/not-found" || code === "functions/failed-precondition" ?
      "対象が見つからないか、既に変更されています。管理キューを更新してください。" : "対象情報を読み込めませんでした。";
    setDetailState("error");
  }
}

function renderPlan(plan, reason) {
  planElements.summary.replaceChildren();
  const target = targetPresentation(selectedQueueItem.target);
  addDetail(planElements.summary, "対象", `${target.label} / ${target.identifier}`);
  addDetail(planElements.summary, "対応", actionLabel(plan.action));
  addDetail(planElements.summary, "変更前", plan.currentStatus);
  addDetail(planElements.summary, "変更後", plan.nextStatus ?? "変更なし");
  addDetail(planElements.summary, "対応理由", reason);
  planElements.disallowed.classList.toggle("hidden", plan.allowed);
  planElements.photoDelete.classList.toggle("hidden", !(plan.action === "deleted" && plan.requiresStorageDelete));
  planElements.indexUpdate.classList.toggle("hidden", !plan.affectsIndex);
  mutationElements.prepareAction.classList.toggle("hidden", !plan.allowed);
}

async function previewPlan() {
  if (selectedQueueItem === null || targetDetail === null || authorizedUid === null) return;
  const reason = validateReason(detailElements.reason.value);
  detailElements.reasonError.classList.toggle("hidden", reason !== null);
  if (reason === null) return;
  const action = detailElements.action.value;
  if (!actionsForTarget(targetDetail.target.targetType).includes(action)) return;
  const generation = ++planGeneration;
  const selectedKey = queueItemKey(selectedQueueItem);
  const expectedUid = authorizedUid;
  pendingPlanInput = {action, reason};
  showAdminView("plan");
  setPlanState("loading");
  try {
    await getToken(appCheck);
    const response = await planModerationActionCallable({target: selectedQueueItem.target, action});
    const parsed = parseModerationPlan(response.data);
    if (generation !== planGeneration || authorizedUid !== expectedUid || auth.currentUser?.uid !== expectedUid ||
        selectedQueueItem === null || queueItemKey(selectedQueueItem) !== selectedKey || pendingPlanInput?.action !== action ||
        parsed.targetType !== targetDetail.target.targetType || parsed.action !== action) return;
    currentPlan = {plan: parsed, reason, selectedKey, detailGeneration};
    renderPlan(parsed, reason);
    setPlanState("success");
  } catch (error) {
    if (generation !== planGeneration || authorizedUid !== expectedUid || selectedQueueItem === null || queueItemKey(selectedQueueItem) !== selectedKey) return;
    const code = safeErrorCode(error);
    if (await handleQueueAuthorizationFailure(code)) return;
    planElements.errorMessage.textContent = code === "functions/failed-precondition" ?
      "現在の状態では実行できません。対象情報を再読み込みしてください。" :
      code === "functions/not-found" ? "対象が見つからないか、既に変更されています。" : "変更内容を確認できませんでした。";
    setPlanState("error");
  }
}

function persistPendingOperation(operation) {
  pendingOperation = operation;
  sessionStorage.setItem(pendingOperationKey, encodePendingOperation(operation));
}

function clearPendingOperation() {
  pendingOperation = null;
  sessionStorage.removeItem(pendingOperationKey);
}

function readPendingOperation() {
  const parsed = decodePendingOperation(sessionStorage.getItem(pendingOperationKey));
  if (parsed === null) sessionStorage.removeItem(pendingOperationKey);
  pendingOperation = parsed;
}

function prepareMutation(operationType, value = null) {
  if (selectedQueueItem === null || targetDetail === null || mutationLoading) return;
  let reason = null;
  let action;
  let resolution;
  if (operationType !== "mark") {
    reason = validateReason(detailElements.reason.value);
    detailElements.reasonError.classList.toggle("hidden", reason !== null);
    if (reason === null) return;
  }
  if (operationType === "apply") {
    action = value;
    if (currentPlan === null || !currentPlan.plan.allowed || currentPlan.plan.action !== action ||
        currentPlan.reason !== reason || currentPlan.selectedKey !== queueItemKey(selectedQueueItem) ||
        currentPlan.detailGeneration !== detailGeneration) {
      showStatus("変更内容をもう一度確認してください。", "error");
      showAdminView("detail");
      return;
    }
  } else if (operationType === "resolve") {
    resolution = value;
  }
  preparedOperation = {operationType, action, resolution, reason, returnView: operationType === "apply" ? "plan" : "detail"};
  renderMutationConfirmation();
  showAdminView("mutationConfirm");
}

function renderMutationConfirmation() {
  mutationElements.confirmSummary.replaceChildren();
  const target = targetPresentation(selectedQueueItem.target);
  addDetail(mutationElements.confirmSummary, "受付種別", sourceLabel(selectedQueueItem.source));
  addDetail(mutationElements.confirmSummary, "対象", `${target.label} / ${target.identifier}`);
  if (preparedOperation.operationType === "mark") {
    addDetail(mutationElements.confirmSummary, "対応", "確認を開始");
    addDetail(mutationElements.confirmSummary, "変更後", "確認中");
  } else if (preparedOperation.operationType === "resolve") {
    addDetail(mutationElements.confirmSummary, "対応", preparedOperation.resolution === "noAction" ? "措置なしで完了" : "通報・修正提案を却下");
    addDetail(mutationElements.confirmSummary, "対応理由", preparedOperation.reason);
  } else {
    addDetail(mutationElements.confirmSummary, "対応", actionLabel(preparedOperation.action));
    addDetail(mutationElements.confirmSummary, "変更前", currentPlan.plan.currentStatus);
    addDetail(mutationElements.confirmSummary, "変更後", currentPlan.plan.nextStatus ?? "変更なし");
    addDetail(mutationElements.confirmSummary, "対応理由", preparedOperation.reason);
  }
  const photoDelete = preparedOperation.operationType === "apply" && preparedOperation.action === "deleted" && currentPlan?.plan.requiresStorageDelete === true;
  mutationElements.confirmWarning.textContent = photoDelete ? "正式写真を削除します。完了まで同じ操作を再試行する場合があります。" : "";
  mutationElements.confirmWarning.classList.toggle("hidden", !photoDelete);
}

function callableForOperation(operationType) {
  if (operationType === "mark") return markModerationItemInReviewCallable;
  if (operationType === "resolve") return resolveModerationItemCallable;
  return applyModerationQueueActionCallable;
}

function retryableMutationError(code) {
  return code === "" || code === "functions/internal" || code === "functions/unavailable" || code === "functions/resource-exhausted";
}

async function runMutation(operation) {
  if (mutationLoading || selectedQueueItem === null || authorizedUid === null || !operationMatchesItem(operation, selectedQueueItem)) return;
  const generation = ++mutationGeneration;
  const selectedKey = queueItemKey(selectedQueueItem);
  const expectedUid = authorizedUid;
  mutationLoading = true;
  mutationElements.confirm.disabled = true;
  showAdminView("mutationProgress");
  persistPendingOperation(operation);
  try {
    await getToken(appCheck);
    if (operation.operationType === "apply") {
      const planResponse = await planModerationActionCallable({target: selectedQueueItem.target, action: operation.action});
      const freshPlan = parseModerationPlan(planResponse.data);
      if (!freshPlan.allowed || freshPlan.targetType !== targetDetail?.target.targetType || freshPlan.action !== operation.action) {
        const staleError = new Error("stale-plan");
        staleError.code = "functions/failed-precondition";
        throw staleError;
      }
    }
    const response = await callableForOperation(operation.operationType)(buildMutationRequest(operation));
    parseMutationResult(response.data, operation);
    if (generation !== mutationGeneration || authorizedUid !== expectedUid || auth.currentUser?.uid !== expectedUid ||
        selectedQueueItem === null || queueItemKey(selectedQueueItem) !== selectedKey) return;
    mutationLoading = false;
    mutationElements.confirm.disabled = false;
    clearPendingOperation();
    preparedOperation = null;
    const reselect = operation.operationType === "mark" ? operation.queueRef : null;
    await loadQueue({reset: true});
    if (reselect !== null) {
      const item = queueItems.find((candidate) => candidate.source === reselect.sourceType && candidate.id === reselect.itemId);
      if (item) selectQueueItem(item);
    }
    showStatus(operation.operationType === "mark" ? "確認を開始しました。" : "対応を完了しました。", "success");
  } catch (error) {
    if (generation !== mutationGeneration || authorizedUid !== expectedUid || selectedQueueItem === null || queueItemKey(selectedQueueItem) !== selectedKey) return;
    mutationLoading = false;
    mutationElements.confirm.disabled = false;
    const code = safeErrorCode(error);
    if (await handleQueueAuthorizationFailure(code)) return;
    if (code === "functions/not-found" || code === "functions/failed-precondition" || code === "functions/invalid-argument") {
      clearPendingOperation();
      preparedOperation = null;
      await loadQueue({reset: true});
      showStatus("この項目は既に変更されています。管理キューを再読み込みしました。", "error");
      return;
    }
    mutationElements.errorMessage.textContent = operation.operationType === "apply" && operation.action === "deleted" ?
      "削除処理を完了できませんでした。同じ処理を再試行できます。" :
      retryableMutationError(code) ? "処理を完了できませんでした。同じ処理を再試行できます。" : "処理を完了できませんでした。管理キューを再読み込みしてください。";
    mutationElements.errorRetry.classList.toggle("hidden", !retryableMutationError(code));
    if (!retryableMutationError(code)) clearPendingOperation();
    showAdminView("mutationError");
  }
}

function startPreparedMutation() {
  if (preparedOperation === null || selectedQueueItem === null || mutationLoading) return;
  const operation = createPendingOperation({
    item: selectedQueueItem, operationType: preparedOperation.operationType, action: preparedOperation.action,
    resolution: preparedOperation.resolution, reason: preparedOperation.reason, requestId: crypto.randomUUID(),
  });
  void runMutation(operation);
}

function retryPendingMutation() {
  if (pendingOperation === null || selectedQueueItem === null || !operationMatchesItem(pendingOperation, selectedQueueItem)) return;
  void runMutation(pendingOperation);
}

function recoverPendingOperation() {
  if (pendingOperation === null) return;
  const item = queueItems.find((candidate) => operationMatchesItem(pendingOperation, candidate));
  if (!item) {
    clearPendingOperation();
    return;
  }
  selectQueueItem(item);
}

async function handleQueueAuthorizationFailure(code) {
  if (code === "functions/permission-denied") {
    clearAdminState();
    showView("denied");
    return true;
  }
  if (code === "functions/unauthenticated") {
    clearAdminState();
    await signOut(auth);
    showStatus("セッションが切れました。再ログインしてください。", "error");
    return true;
  }
  return false;
}

async function loadQueue({reset}) {
  if (queueLoading || authorizedUid === null) return;
  const cursor = reset ? null : nextQueueCursor;
  if (!reset && cursor === null) return;
  const generation = ++queueGeneration;
  const expectedUid = authorizedUid;
  queueLoading = true;
  if (reset) {
    clearDetailState();
    queueItems = [];
    nextQueueCursor = null;
    queueElements.items.replaceChildren();
    setQueueState("loading");
  } else {
    setQueueState("page-loading");
  }
  try {
    await getToken(appCheck);
    const request = cursor === null ? {limit: queueLimit} : {limit: queueLimit, cursor};
    const response = await authorizationProbe(request);
    const parsed = parseQueueResponse(response.data);
    if (generation !== queueGeneration || authorizedUid !== expectedUid || auth.currentUser?.uid !== expectedUid) return;
    queueItems = mergeQueueItems(queueItems, parsed.items, reset);
    nextQueueCursor = parsed.nextCursor;
    renderQueue();
    queueLoading = false;
    setQueueState(queueItems.length === 0 && nextQueueCursor === null ? "empty" : "ready");
    if (reset) recoverPendingOperation();
  } catch (error) {
    if (generation !== queueGeneration || authorizedUid !== expectedUid) return;
    queueLoading = false;
    const code = safeErrorCode(error);
    if (await handleQueueAuthorizationFailure(code)) return;
    queueElements.errorMessage.textContent = code === "functions/resource-exhausted" ? "操作回数が上限に達しました。時間をおいてください。" : "管理キューを読み込めませんでした。";
    setQueueState("error");
  }
}

function showSetupError() {
  showView("boot");
  views.boot.classList.add("hidden");
  setupError.textContent = "管理画面の設定を確認できませんでした。";
  setupError.classList.remove("hidden");
  document.querySelectorAll("button, input").forEach((element) => {
    element.disabled = true;
  });
}

function safeErrorCode(error) {
  return typeof error?.code === "string" ? error.code : "";
}

async function authorizeCurrentUser(user) {
  const generation = ++authorizationGeneration;
  showView("boot");
  hideStatus();
  try {
    await getToken(appCheck, true);
    await authorizationProbe({limit: 1});
    if (generation !== authorizationGeneration || auth.currentUser?.uid !== user.uid) {
      return;
    }
    authorizedUid = user.uid;
    readPendingOperation();
    showView("admin");
    await loadQueue({reset: true});
  } catch (error) {
    if (generation !== authorizationGeneration) {
      return;
    }
    const code = safeErrorCode(error);
    if (code === "functions/permission-denied") {
      showView("denied");
      return;
    }
    if (code === "functions/unauthenticated") {
      await signOut(auth);
      showStatus("セッションが切れました。再ログインしてください。", "error");
      return;
    }
    if (code === "functions/resource-exhausted") {
      connectionErrorMessage.textContent = "操作回数が上限に達しました。時間をおいてください。";
    } else if (code === "functions/unavailable") {
      connectionErrorMessage.textContent = "一時的に利用できません。";
    } else {
      connectionErrorMessage.textContent = "接続または処理を確認できませんでした。";
    }
    showView("connectionError");
  }
}

async function logout() {
  clearAdminState();
  await signOut(auth);
}

if (!hasRequiredConfiguration(config)) {
  showSetupError();
} else {
  const app = initializeApp(config.firebase);
  appCheck = initializeAppCheck(app, {
    provider: new ReCaptchaEnterpriseProvider(config.appCheckSiteKey),
    isTokenAutoRefreshEnabled: true,
  });
  auth = getAuth(app);
  const functions = getFunctions(app, "us-central1");
  authorizationProbe = httpsCallable(functions, "listModerationQueue");
  getModerationTargetCallable = httpsCallable(functions, "getModerationTarget");
  planModerationActionCallable = httpsCallable(functions, "planModerationAction");
  markModerationItemInReviewCallable = httpsCallable(functions, "markModerationItemInReview");
  resolveModerationItemCallable = httpsCallable(functions, "resolveModerationItem");
  applyModerationQueueActionCallable = httpsCallable(functions, "applyModerationQueueAction");

  onAuthStateChanged(auth, async (user) => {
    const nextUid = user?.uid ?? null;
    const authUserChanged = observedAuthUid !== null && nextUid !== observedAuthUid;
    clearAdminState({clearPending: nextUid === null || authUserChanged});
    observedAuthUid = nextUid;
    if (user === null) {
      showView("login");
      return;
    }
    await authorizeCurrentUser(user);
  });

  emailSignInForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    setLoginBusy(true);
    hideStatus();
    const email = document.querySelector("#email").value;
    const passwordInput = document.querySelector("#password");
    try {
      await signInWithEmailAndPassword(auth, email, passwordInput.value);
    } catch {
      showStatus("ログインできませんでした。入力内容を確認してください。", "error");
    } finally {
      passwordInput.value = "";
      setLoginBusy(false);
    }
  });

  googleSignInButton.addEventListener("click", async () => {
    setLoginBusy(true);
    hideStatus();
    try {
      await signInWithPopup(auth, new GoogleAuthProvider());
    } catch {
      showStatus("ログインできませんでした。時間をおいて再試行してください。", "error");
    } finally {
      setLoginBusy(false);
    }
  });

  document.querySelector("#admin-sign-out").addEventListener("click", logout);
  document.querySelector("#denied-sign-out").addEventListener("click", logout);
  document.querySelector("#error-sign-out").addEventListener("click", logout);
  queueElements.refresh.addEventListener("click", () => loadQueue({reset: true}));
  queueElements.retry.addEventListener("click", () => loadQueue({reset: queueItems.length === 0}));
  queueElements.loadMore.addEventListener("click", () => loadQueue({reset: false}));
  document.querySelector("#detail-back").addEventListener("click", clearDetailState);
  detailElements.retry.addEventListener("click", () => loadTargetDetail());
  detailElements.preview.addEventListener("click", previewPlan);
  document.querySelector("#plan-back").addEventListener("click", () => {
    planGeneration += 1;
    pendingPlanInput = null;
    setPlanState("clear");
    showAdminView("detail");
  });
  planElements.retry.addEventListener("click", previewPlan);
  mutationElements.mark.addEventListener("click", () => prepareMutation("mark"));
  mutationElements.noAction.addEventListener("click", () => prepareMutation("resolve", "noAction"));
  mutationElements.rejected.addEventListener("click", () => prepareMutation("resolve", "rejected"));
  mutationElements.prepareAction.addEventListener("click", () => prepareMutation("apply", currentPlan?.plan.action));
  mutationElements.confirm.addEventListener("click", startPreparedMutation);
  document.querySelector("#cancel-mutation").addEventListener("click", () => {
    preparedOperation = null;
    showAdminView("detail");
  });
  document.querySelector("#mutation-confirm-back").addEventListener("click", () => {
    const returnView = preparedOperation?.returnView === "plan" ? "plan" : "detail";
    preparedOperation = null;
    showAdminView(returnView);
  });
  mutationElements.retry.addEventListener("click", retryPendingMutation);
  mutationElements.errorRetry.addEventListener("click", retryPendingMutation);
  document.querySelector("#mutation-error-refresh").addEventListener("click", () => loadQueue({reset: true}));
  retryAuthorizationButton.addEventListener("click", async () => {
    const user = auth.currentUser;
    if (user === null) {
      showView("login");
      return;
    }
    await authorizeCurrentUser(user);
  });
}
