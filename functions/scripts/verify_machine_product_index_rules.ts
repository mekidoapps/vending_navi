import {resolveMasterEmulatorConfig} from "./master_emulator_config";

async function main(): Promise<void> {
  const config = resolveMasterEmulatorConfig();
  const baseUrl =
    `http://${config.firestoreHost}/v1/projects/${config.projectId}` +
    "/databases/(default)/documents";

  await expectStatus(
    "public machine-product index read",
    fetch(
      `${baseUrl}/machine_product_index/fixture_station_boss_black`,
    ),
    200,
  );

  await expectStatus(
    "client machine-product index write denied",
    fetch(
      `${baseUrl}/machine_product_index` +
        "?documentId=client_index_write_must_fail",
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({
          fields: {
            machineId: {stringValue: "blocked"},
            productId: {stringValue: "suntory_boss_black"},
          },
        }),
      },
    ),
    403,
  );

  console.log(
    [
      "Machine-product index Firestore rules verified.",
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
  console.error("Machine-product index rules verification failed.", error);
  process.exitCode = 1;
});
