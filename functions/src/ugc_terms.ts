import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

export const UGC_TERMS_VERSION = "2026-09-06";
export const UGC_TERMS_URL = "https://vendingnavi.web.app/terms";

const restrictedStatuses = new Set(["restricted", "suspended"]);

export function parseUgcTermsVersion(value: unknown): string {
  if (typeof value !== "string" || value.trim() !== UGC_TERMS_VERSION) {
    throw new HttpsError("invalid-argument", "The terms version is invalid.", {
      appCode: "invalid-ugc-terms-version",
    });
  }
  return UGC_TERMS_VERSION;
}

export async function acceptUgcTermsForUser(
  firestore: Firestore,
  uid: string,
  rawInput: unknown,
): Promise<{readonly version: string; readonly termsUrl: string}> {
  parseUgcTermsVersion(rawInput);
  const userRef = firestore.collection("users").doc(uid);
  const user = await userRef.get();
  const status = user.data()?.accountStatus;
  if (typeof status === "string" && restrictedStatuses.has(status)) {
    throw new HttpsError("permission-denied", "This account cannot accept contribution terms.", {
      appCode: "account-restricted",
    });
  }
  await userRef.collection("ugc_consent").doc("current").set({
    version: UGC_TERMS_VERSION,
    acceptedAt: FieldValue.serverTimestamp(),
    termsUrl: UGC_TERMS_URL,
  });
  return {version: UGC_TERMS_VERSION, termsUrl: UGC_TERMS_URL};
}

export async function getUgcTermsConsentForUser(
  firestore: Firestore,
  uid: string,
): Promise<{readonly accepted: boolean; readonly version: string; readonly termsUrl: string}> {
  const consent = await firestore.collection("users").doc(uid)
    .collection("ugc_consent").doc("current").get();
  return {
    accepted: consent.data()?.version === UGC_TERMS_VERSION,
    version: UGC_TERMS_VERSION,
    termsUrl: UGC_TERMS_URL,
  };
}

export async function assertUgcTermsAccepted(
  firestore: Firestore,
  uid: string,
): Promise<void> {
  const consent = await firestore.collection("users").doc(uid)
    .collection("ugc_consent").doc("current").get();
  const version = consent.data()?.version;
  if (version === UGC_TERMS_VERSION) return;
  throw new HttpsError("failed-precondition", "Current contribution terms must be accepted.", {
    appCode: version === undefined || version === null ? "ugc-terms-required" : "ugc-terms-outdated",
  });
}
