import {resolveMasterEmulatorConfig} from "./master_emulator_config";

async function main(): Promise<void> {
  const config = resolveMasterEmulatorConfig();
  const baseUrl =
    `http://${config.firestoreHost}/v1/projects/${config.projectId}` +
    "/databases/(default)/documents";

  await expectStatus(
    "public products read",
    fetch(`${baseUrl}/products?pageSize=1`),
    200,
  );

  await expectStatus(
    "public manufacturers read",
    fetch(`${baseUrl}/manufacturers?pageSize=1`),
    200,
  );

  await expectStatus(
    "client product write denied",
    fetch(`${baseUrl}/products?documentId=client_write_must_fail`, {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({
        fields: {
          name: {stringValue: "blocked"},
        },
      }),
    }),
    403,
  );

  await expectStatus(
    "unreleased collection read denied",
    fetch(`${baseUrl}/vending_machines?pageSize=1`),
    403,
  );

  console.log(
    [
      "V2 master Firestore rules verified.",
      `project=${config.projectId}`,
      `firestore=${config.firestoreHost}`,
    ].join(" "),
  );
}

async function expectStatus(
  name: string,
  request: Promise<Response>,
  expectedStatus: number,
): Promise<void> {
  const response = await request;

  if (response.status === expectedStatus) {
    console.log(`PASS ${name}: HTTP ${response.status}`);
    return;
  }

  const responseText = await response.text();
  throw new Error(
    `${name}: expected HTTP ${expectedStatus}, got ${response.status}. ` +
      responseText.slice(0, 500),
  );
}

void main().catch((error: unknown) => {
  console.error("V2 master Firestore rules verification failed.", error);
  process.exitCode = 1;
});
