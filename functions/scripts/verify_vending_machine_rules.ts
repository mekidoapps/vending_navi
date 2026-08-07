import {resolveMasterEmulatorConfig} from "./master_emulator_config";

async function main(): Promise<void> {
  const config = resolveMasterEmulatorConfig();
  const baseUrl =
    `http://${config.firestoreHost}/v1/projects/${config.projectId}` +
    "/databases/(default)/documents";

  await expectStatus(
    "public vending-machine collection read",
    fetch(`${baseUrl}/vending_machines?pageSize=10`),
    200,
  );

  await expectStatus(
    "public v2 machine read",
    fetch(`${baseUrl}/vending_machines/machine_v2_station_east`),
    200,
  );

  await expectStatus(
    "public legacy machine read",
    fetch(`${baseUrl}/vending_machines/machine_v1_legacy`),
    200,
  );

  await expectStatus(
    "public machine product read",
    fetch(
      `${baseUrl}/vending_machines/machine_v2_station_east/products` +
        "/suntory_boss_black",
    ),
    200,
  );

  await expectStatus(
    "client vending-machine write denied",
    fetch(`${baseUrl}/vending_machines?documentId=client_write_must_fail`, {
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
    "client machine-product write denied",
    fetch(
      `${baseUrl}/vending_machines/machine_v2_station_east/products` +
        "?documentId=client_write_must_fail",
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({
          fields: {
            productId: {stringValue: "suntory_boss_black"},
          },
        }),
      },
    ),
    403,
  );

  await expectStatus(
    "unreleased revisions read denied",
    fetch(
      `${baseUrl}/vending_machines/machine_v2_station_east/revisions` +
        "?pageSize=1",
    ),
    403,
  );

  console.log(
    [
      "V2 vending-machine Firestore rules verified.",
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
  console.error("Vending-machine rules verification failed.", error);
  process.exitCode = 1;
});
