#!/usr/bin/env node
"use strict";

const EXPECTED_PROJECT_ID = "vendingnavi";

class AdminBootstrapError extends Error {
  constructor(code) {
    super(code);
    this.name = "AdminBootstrapError";
    this.code = code;
  }
}

function resolveProjectId(env) {
  const firebaseConfig = env.FIREBASE_CONFIG;
  let configuredProject = null;
  if (firebaseConfig) {
    try {
      configuredProject = JSON.parse(firebaseConfig).projectId ?? null;
    } catch {
      throw new AdminBootstrapError("project-unresolved");
    }
  }
  const candidates = [env.GOOGLE_CLOUD_PROJECT, env.GCLOUD_PROJECT, configuredProject].filter(Boolean);
  if (candidates.length === 0) throw new AdminBootstrapError("project-unresolved");
  if (new Set(candidates).size !== 1 || candidates[0] !== EXPECTED_PROJECT_ID) {
    throw new AdminBootstrapError("wrong-project");
  }
  return candidates[0];
}

function safeSummary({operation, accountResolved, documentExists, adminEnabled, accountStatus, changed, tokenRevoked}) {
  return [
    `Operation: ${operation.toUpperCase()}`,
    `Project: ${EXPECTED_PROJECT_ID}`,
    `Account resolved: ${accountResolved ? "yes" : "no"}`,
    `User document: ${documentExists ? "exists" : "missing"}`,
    `Admin claim: ${adminEnabled ? "enabled" : "disabled"}`,
    `Account status: ${accountStatus}`,
    `Changed: ${changed ? "yes" : "no"}`,
    `Refresh tokens revoked: ${tokenRevoked ? "yes" : "no"}`,
  ].join("\n");
}

async function resolveAccount(auth, target) {
  if (typeof target !== "string" || target.trim().length === 0) throw new AdminBootstrapError("target-required");
  try {
    return target.includes("@") ? await auth.getUserByEmail(target.trim()) : await auth.getUser(target.trim());
  } catch {
    throw new AdminBootstrapError("account-not-found");
  }
}

async function readState(auth, firestore, target) {
  const account = await resolveAccount(auth, target);
  const snapshot = await firestore.collection("users").doc(account.uid).get();
  const data = snapshot.exists ? snapshot.data() : null;
  const status = data && ["active", "restricted", "suspended"].includes(data.accountStatus) ? data.accountStatus : "unknown";
  return {
    account,
    documentExists: snapshot.exists,
    accountStatus: status,
    claims: account.customClaims ?? {},
    adminEnabled: account.customClaims?.admin === true,
  };
}

async function manageModerationAdmin({operation, target, projectId, auth, firestore, confirm = async () => false}) {
  if (projectId !== EXPECTED_PROJECT_ID) throw new AdminBootstrapError(projectId ? "wrong-project" : "project-unresolved");
  if (!new Set(["status", "grant", "revoke"]).has(operation)) throw new AdminBootstrapError("invalid-operation");
  const state = await readState(auth, firestore, target);

  if (operation === "status") {
    return safeSummary({operation, accountResolved: true, ...state, changed: false, tokenRevoked: false});
  }

  if (operation === "grant") {
    if (!state.documentExists) throw new AdminBootstrapError("user-document-missing");
    if (state.accountStatus !== "active") throw new AdminBootstrapError("account-not-active");
    if (state.adminEnabled) {
      return safeSummary({operation, accountResolved: true, ...state, changed: false, tokenRevoked: false});
    }
    const accepted = await confirm([
      "Operation: GRANT MODERATION ADMIN",
      `Project: ${EXPECTED_PROJECT_ID}`,
      "Account: resolved existing account",
      "Account status: active",
    ].join("\n"));
    if (!accepted) return safeSummary({operation, accountResolved: true, ...state, changed: false, tokenRevoked: false});
    await auth.setCustomUserClaims(state.account.uid, {...state.claims, admin: true});
    return safeSummary({operation, accountResolved: true, ...state, adminEnabled: true, changed: true, tokenRevoked: false});
  }

  if (!state.adminEnabled) {
    return safeSummary({operation, accountResolved: true, ...state, changed: false, tokenRevoked: false});
  }
  const accepted = await confirm([
    "Operation: REVOKE MODERATION ADMIN",
    `Project: ${EXPECTED_PROJECT_ID}`,
    "Account: resolved existing account",
    `Account status: ${state.accountStatus}`,
  ].join("\n"));
  if (!accepted) return safeSummary({operation, accountResolved: true, ...state, changed: false, tokenRevoked: false});
  const {admin: _removed, ...remainingClaims} = state.claims;
  await auth.setCustomUserClaims(state.account.uid, remainingClaims);
  await auth.revokeRefreshTokens(state.account.uid);
  return safeSummary({operation, accountResolved: true, ...state, adminEnabled: false, changed: true, tokenRevoked: true});
}

function createServices(projectId) {
  const {applicationDefault, getApps, initializeApp} = require("../functions/node_modules/firebase-admin/app");
  const {getAuth} = require("../functions/node_modules/firebase-admin/auth");
  const {getFirestore} = require("../functions/node_modules/firebase-admin/firestore");
  const app = getApps()[0] ?? initializeApp({credential: applicationDefault(), projectId});
  return {auth: getAuth(app), firestore: getFirestore(app)};
}

async function prompt(question) {
  const readline = require("node:readline/promises");
  const input = readline.createInterface({input: process.stdin, output: process.stdout});
  try {
    return (await input.question(question)).trim();
  } finally {
    input.close();
  }
}

async function main() {
  const operation = process.argv[2];
  if (!new Set(["status", "grant", "revoke"]).has(operation)) throw new AdminBootstrapError("usage: status|grant|revoke");
  const projectId = resolveProjectId(process.env);
  process.stdout.write(`Project: ${projectId}\n`);
  const target = await prompt("Account UID or email (not stored): ");
  const services = createServices(projectId);
  const result = await manageModerationAdmin({
    operation,
    target,
    projectId,
    ...services,
    confirm: async (message) => {
      process.stdout.write(`${message}\n`);
      return (await prompt("Type yes to continue: ")).toLowerCase() === "yes";
    },
  });
  process.stdout.write(`${result}\n`);
  if (operation === "grant" && result.includes("Changed: yes")) {
    process.stdout.write("Log out the target account, sign in again, and verify /admin with a fresh ID token.\n");
  }
  if (operation === "revoke" && result.includes("Changed: yes")) {
    process.stdout.write("Refresh tokens were revoked. Verify that the next sign-in is denied access to /admin.\n");
  }
}

if (require.main === module) {
  main().catch((error) => {
    const code = error instanceof AdminBootstrapError ? error.code : "operation-failed";
    process.stderr.write(`Moderation admin operation stopped: ${code}\n`);
    process.exitCode = 1;
  });
}

module.exports = {AdminBootstrapError, EXPECTED_PROJECT_ID, manageModerationAdmin, resolveProjectId};
