import {resolveMasterEmulatorConfig} from "./master_emulator_config";

async function main(): Promise<void> {
  const config = resolveMasterEmulatorConfig();

  const databaseBaseUrl =
    `http://${config.firestoreHost}/v1/projects/${config.projectId}` +
    "/databases/(default)";

  const documentsBaseUrl =
    `${databaseBaseUrl}/documents`;

  await expectStatus(
    "public active v2 machine read",
    fetch(
      `${documentsBaseUrl}/vending_machines/machine_v2_station_east`,
    ),
    200,
  );

  await expectStatus(
    "public active legacy machine read",
    fetch(
      `${documentsBaseUrl}/vending_machines/machine_v1_legacy`,
    ),
    200,
  );

  await expectStatus(
    "hidden v2 machine read denied",
    fetch(
      `${documentsBaseUrl}/vending_machines/machine_v2_hidden`,
    ),
    403,
  );

  await expectStatus(
    "unfiltered vending-machine collection read denied",
    fetch(
      `${documentsBaseUrl}/vending_machines?pageSize=10`,
    ),
    403,
  );

  await expectActiveMachineQuery(databaseBaseUrl);

  await expectStatus(
    "public active machine product read",
    fetch(
      `${documentsBaseUrl}/vending_machines/` +
        "machine_v2_station_east/products/suntory_boss_black",
    ),
    200,
  );

  await expectStatus(
    "inactive machine product read denied",
    fetch(
      `${documentsBaseUrl}/vending_machines/` +
        "machine_v2_station_east/products/asahi_calpis",
    ),
    403,
  );

  await expectStatus(
    "active product under hidden machine denied",
    fetch(
      `${documentsBaseUrl}/vending_machines/` +
        "machine_v2_hidden/products/suntory_boss_black",
    ),
    403,
  );

  await expectStatus(
    "unfiltered machine product collection read denied",
    fetch(
      `${documentsBaseUrl}/vending_machines/` +
        "machine_v2_station_east/products?pageSize=10",
    ),
    403,
  );

  await expectActiveProductQuery(databaseBaseUrl);

  await expectStatus(
    "client vending-machine write denied",
    fetch(
      `${documentsBaseUrl}/vending_machines` +
        "?documentId=client_write_must_fail",
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        body: JSON.stringify({
          fields: {
            name: {
              stringValue: "blocked",
            },
            status: {
              stringValue: "active",
            },
          },
        }),
      },
    ),
    403,
  );

  await expectStatus(
    "client machine-product write denied",
    fetch(
      `${documentsBaseUrl}/vending_machines/` +
        "machine_v2_station_east/products" +
        "?documentId=client_write_must_fail",
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        body: JSON.stringify({
          fields: {
            productId: {
              stringValue: "suntory_boss_black",
            },
            isActive: {
              booleanValue: true,
            },
          },
        }),
      },
    ),
    403,
  );

  await expectStatus(
    "unreleased revisions read denied",
    fetch(
      `${documentsBaseUrl}/vending_machines/` +
        "machine_v2_station_east/revisions?pageSize=1",
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

async function expectActiveMachineQuery(
  databaseBaseUrl: string,
): Promise<void> {
  const response = await fetch(
    `${databaseBaseUrl}/documents:runQuery`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
      body: JSON.stringify({
        structuredQuery: {
          from: [
            {
              collectionId: "vending_machines",
            },
          ],
          where: {
            fieldFilter: {
              field: {
                fieldPath: "status",
              },
              op: "EQUAL",
              value: {
                stringValue: "active",
              },
            },
          },
        },
      }),
    },
  );

  if (response.status !== 200) {
    const body = await response.text();

    throw new Error(
      "active vending-machine query: expected HTTP 200, got " +
        `${response.status}. ${body.slice(0, 500)}`,
    );
  }

  console.log(
    "PASS constrained active vending-machine query: HTTP 200",
  );
}

async function expectActiveProductQuery(
  databaseBaseUrl: string,
): Promise<void> {
  const parent =
    `${databaseBaseUrl}/documents/vending_machines/` +
    "machine_v2_station_east";

  const response = await fetch(
    `${parent}:runQuery`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
      body: JSON.stringify({
        structuredQuery: {
          from: [
            {
              collectionId: "products",
            },
          ],
          where: {
            fieldFilter: {
              field: {
                fieldPath: "isActive",
              },
              op: "EQUAL",
              value: {
                booleanValue: true,
              },
            },
          },
        },
      }),
    },
  );

  if (response.status !== 200) {
    const body = await response.text();

    throw new Error(
      "active machine-product query: expected HTTP 200, got " +
        `${response.status}. ${body.slice(0, 500)}`,
    );
  }

  console.log(
    "PASS constrained active machine-product query: HTTP 200",
  );
}

async function expectStatus(
  name: string,
  request: Promise<Response>,
  expectedStatus: number,
): Promise<void> {
  const response = await request;

  if (response.status === expectedStatus) {
    console.log(
      `PASS ${name}: HTTP ${response.status}`,
    );
    return;
  }

  const responseText = await response.text();

  throw new Error(
    `${name}: expected HTTP ${expectedStatus}, ` +
      `got ${response.status}. ` +
      responseText.slice(0, 500),
  );
}

void main().catch((error: unknown) => {
  console.error(
    "Vending-machine rules verification failed.",
    error,
  );
  process.exitCode = 1;
});
