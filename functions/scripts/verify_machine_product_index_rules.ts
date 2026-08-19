import {resolveMasterEmulatorConfig} from "./master_emulator_config";

async function main(): Promise<void> {
  const config = resolveMasterEmulatorConfig();

  const databaseBaseUrl =
    `http://${config.firestoreHost}/v1/projects/${config.projectId}` +
    "/databases/(default)";

  const documentsBaseUrl = `${databaseBaseUrl}/documents`;

  await expectStatus(
    "public active machine-product index read",
    fetch(
      `${documentsBaseUrl}/machine_product_index/fixture_station_boss_black`,
    ),
    200,
  );

  await expectStatus(
    "inactive machine-product index read denied",
    fetch(
      `${documentsBaseUrl}/machine_product_index/fixture_inactive_boss_black`,
    ),
    403,
  );

  await expectStatus(
    "hidden-machine index read denied",
    fetch(
      `${documentsBaseUrl}/machine_product_index/fixture_hidden_boss_black`,
    ),
    403,
  );

  await expectStatus(
    "unfiltered machine-product index collection read denied",
    fetch(
      `${documentsBaseUrl}/machine_product_index?pageSize=20`,
    ),
    403,
  );

  await expectVisibleQuery(
    databaseBaseUrl,
  );

  await expectStatus(
    "client machine-product index write denied",
    fetch(
      `${documentsBaseUrl}/machine_product_index` +
        "?documentId=client_index_write_must_fail",
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({
          fields: {
            machineId: {stringValue: "blocked"},
            productId: {stringValue: "suntory_boss_black"},
            isActive: {booleanValue: true},
            machineStatus: {stringValue: "active"},
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

async function expectVisibleQuery(
  databaseBaseUrl: string,
): Promise<void> {
  const response = await fetch(
    `${databaseBaseUrl}/documents:runQuery`,
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({
        structuredQuery: {
          from: [
            {collectionId: "machine_product_index"},
          ],
          where: {
            compositeFilter: {
              op: "AND",
              filters: [
                {
                  fieldFilter: {
                    field: {fieldPath: "productId"},
                    op: "EQUAL",
                    value: {stringValue: "suntory_boss_black"},
                  },
                },
                {
                  fieldFilter: {
                    field: {fieldPath: "isActive"},
                    op: "EQUAL",
                    value: {booleanValue: true},
                  },
                },
                {
                  fieldFilter: {
                    field: {fieldPath: "machineStatus"},
                    op: "EQUAL",
                    value: {stringValue: "active"},
                  },
                },
                {
                  fieldFilter: {
                    field: {fieldPath: "geohash"},
                    op: "GREATER_THAN_OR_EQUAL",
                    value: {stringValue: "xn76u"},
                  },
                },
                {
                  fieldFilter: {
                    field: {fieldPath: "geohash"},
                    op: "LESS_THAN_OR_EQUAL",
                    value: {stringValue: "xn76u\uf8ff"},
                  },
                },
              ],
            },
          },
        },
      }),
    },
  );

  const responseText = await response.text();

  if (response.status !== 200) {
    throw new Error(
      "visible machine-product query: expected HTTP 200, got " +
        `${response.status}. ${responseText.slice(0, 500)}`,
    );
  }

  const payload = JSON.parse(responseText) as unknown;

  if (!Array.isArray(payload)) {
    throw new Error("Visible query response was not an array.");
  }

  const ids = payload
    .map((item: unknown) => {
      if (
        typeof item !== "object" ||
        item === null ||
        !("document" in item)
      ) {
        return null;
      }

      const document = (
        item as {
          document?: {
            name?: unknown;
          };
        }
      ).document;

      if (
        document === undefined ||
        typeof document.name !== "string"
      ) {
        return null;
      }

      return document.name.split("/").at(-1) ?? null;
    })
    .filter((value): value is string => value !== null);

  if (!ids.includes("fixture_station_boss_black")) {
    throw new Error(
      "Visible query did not return the active fixture.",
    );
  }

  if (
    ids.includes("fixture_inactive_boss_black") ||
    ids.includes("fixture_hidden_boss_black")
  ) {
    throw new Error(
      "Visible query returned a non-public index fixture.",
    );
  }

  console.log(
    `PASS constrained machine-product query: ids=${ids.join(",")}`,
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
  console.error(
    "Machine-product index rules verification failed.",
    error,
  );
  process.exitCode = 1;
});
