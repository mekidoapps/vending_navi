interface AuthResponse { readonly idToken: string; }
const projectId = process.env.GCLOUD_PROJECT ?? "vendingnavi";
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? "127.0.0.1:9099";
const functionsHost = process.env.FUNCTIONS_EMULATOR_HOST ?? "127.0.0.1:5001";

async function call(data: unknown, token?: string): Promise<{status: number; body: any}> {
  const response = await fetch(`http://${functionsHost}/${projectId}/us-central1/acceptUgcTerms`, {
    method: "POST", headers: {"content-type": "application/json", ...(token ? {authorization: `Bearer ${token}`} : {})}, body: JSON.stringify({data}),
  });
  return {status: response.status, body: await response.json()};
}

async function signUp(): Promise<string> {
  const response = await fetch(`http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key`, {
    method: "POST", headers: {"content-type": "application/json"}, body: JSON.stringify({email: `ugc-${Date.now()}@example.test`, password: "Terms-test-123!", returnSecureToken: true}),
  });
  const body = await response.json() as Partial<AuthResponse>;
  if (!response.ok || typeof body.idToken !== "string") throw new Error("Auth emulator sign-up failed.");
  return body.idToken;
}

async function main(): Promise<void> {
  const anonymous = await call({version: "2026-09-06"});
  if (anonymous.body?.error?.status !== "UNAUTHENTICATED") throw new Error("Unauthenticated callable request was not rejected.");
  const token = await signUp();
  const invalid = await call({version: "old"}, token);
  if (invalid.body?.error?.status !== "INVALID_ARGUMENT") throw new Error("Invalid terms version was not rejected.");
  const valid = await call({version: "2026-09-06"}, token);
  if (valid.status !== 200 || valid.body?.result?.version !== "2026-09-06") throw new Error("Valid terms acceptance failed.");
  console.log("Phase 22-A acceptUgcTerms emulator verification passed.");
}
void main();
