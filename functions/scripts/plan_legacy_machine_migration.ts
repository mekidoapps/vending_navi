import {readFile, writeFile} from "node:fs/promises";
import {resolve} from "node:path";

import {
  type LegacyMachineExportRecord,
  type MigrationAliases,
  type MigrationMasterCatalog,
  planLegacyMachineMigration,
} from "../src/migration/legacy_machine_migration_planner";

interface Options {
  readonly inputPath: string;
  readonly masterPath: string;
  readonly aliasesPath: string | null;
  readonly outputPath: string | null;
}

async function main(): Promise<void> {
  const options = parseOptions(process.argv.slice(2));
  const [input, master, aliases] = await Promise.all([
    readJson(options.inputPath),
    readJson(options.masterPath),
    options.aliasesPath === null ? Promise.resolve({}) :
      readJson(options.aliasesPath),
  ]);
  const records = parseRecords(input);
  const report = planLegacyMachineMigration(
    records,
    parseCatalog(master),
    parseAliases(aliases),
  );
  const serialized = `${JSON.stringify(report, null, 2)}\n`;

  if (options.outputPath === null) {
    process.stdout.write(serialized);
  } else {
    await writeFile(options.outputPath, serialized, {encoding: "utf8"});
  }

  process.stderr.write([
    "LEGACY_MIGRATION_DRY_RUN",
    `revision=${report.revision}`,
    `total=${report.summary.total}`,
    `ready=${report.summary.ready}`,
    `manualReview=${report.summary.manualReview}`,
    `invalidCoordinates=${report.summary.invalidCoordinates}`,
    `unresolvedProducts=${report.summary.unresolvedProductCount}`,
    `plannedIndexes=${report.summary.plannedIndexCount}`,
  ].join(" ") + "\n");
}

function parseOptions(args: readonly string[]): Options {
  if (args.includes("--apply") || args.includes("--allow-production")) {
    throw new Error(
      "This Phase B tool is read-only; apply flags are not supported.",
    );
  }
  const value = (name: string): string | null => {
    const prefix = `--${name}=`;
    return args.find((item) => item.startsWith(prefix))?.slice(prefix.length)
      .trim() ?? null;
  };
  const input = value("input");
  if (input === null || input.length === 0) {
    throw new Error("Required argument: --input=<legacy-export.json>");
  }
  const master = value("master") ?? "fixtures/master_fixture.json";
  return {
    inputPath: resolve(input),
    masterPath: resolve(master),
    aliasesPath: value("aliases") === null ? null : resolve(value("aliases")!),
    outputPath: value("output") === null ? null : resolve(value("output")!),
  };
}

async function readJson(path: string): Promise<unknown> {
  return JSON.parse(await readFile(path, "utf8")) as unknown;
}

function parseRecords(value: unknown): readonly LegacyMachineExportRecord[] {
  const root = asRecord(value);
  const rawRecords = Array.isArray(value) ? value :
    root !== null && Array.isArray(root.machines) ? root.machines :
    root !== null && Array.isArray(root.documents) ? root.documents : null;
  if (rawRecords === null) {
    throw new Error(
      "Legacy export must be an array or contain a machines/documents array.",
    );
  }
  return rawRecords.map((raw, index) => {
    const record = asRecord(raw);
    const id = record === null ? null : readString(record.id);
    const data = record === null ? null : asRecord(record.data);
    if (id === null || data === null) {
      throw new Error(`Invalid legacy export record at index ${index}.`);
    }
    return {id, data};
  });
}

function parseCatalog(value: unknown): MigrationMasterCatalog {
  const root = asRecord(value);
  if (
    root === null ||
    !Array.isArray(root.manufacturers) ||
    !Array.isArray(root.products)
  ) {
    throw new Error("Invalid master fixture.");
  }
  return {
    manufacturers: root.manufacturers as MigrationMasterCatalog["manufacturers"],
    products: root.products as MigrationMasterCatalog["products"],
  };
}

function parseAliases(value: unknown): MigrationAliases {
  const root = asRecord(value);
  if (root === null) {
    throw new Error("Invalid alias fixture.");
  }
  return root as MigrationAliases;
}

function readString(value: unknown): string | null {
  if (typeof value !== "string" || value.trim().length === 0) {
    return null;
  }
  return value.trim();
}

function asRecord(value: unknown): Readonly<Record<string, unknown>> | null {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Readonly<Record<string, unknown>>;
}

void main().catch((error: unknown) => {
  console.error(
    "Legacy vending-machine migration planning failed.",
    error instanceof Error ? error.message : "UnknownError",
  );
  process.exitCode = 1;
});
