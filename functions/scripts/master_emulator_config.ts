import {existsSync, readFileSync} from "node:fs";
import {resolve} from "node:path";

export interface MasterEmulatorConfig {
  readonly projectId: string;
  readonly firestoreHost: string;
}

export function resolveMasterEmulatorConfig(): MasterEmulatorConfig {
  const firestoreHost =
    process.env.FIRESTORE_EMULATOR_HOST?.trim() || "127.0.0.1:8080";

  if (!isLocalFirestoreHost(firestoreHost)) {
    throw new Error(
      "Refusing master fixture operation outside a local Firestore emulator.",
    );
  }

  process.env.FIRESTORE_EMULATOR_HOST = firestoreHost;

  const projectId =
    readProjectArgument() ||
    process.env.GCLOUD_PROJECT?.trim() ||
    process.env.GOOGLE_CLOUD_PROJECT?.trim() ||
    readDefaultFirebaseProject();

  if (!projectId) {
    throw new Error(
      "Firebase project ID could not be resolved. " +
        "Pass --project=<projectId> or configure .firebaserc.",
    );
  }

  process.env.GCLOUD_PROJECT = projectId;

  return {
    projectId,
    firestoreHost,
  };
}

function readProjectArgument(): string | undefined {
  const prefix = "--project=";
  const argument = process.argv.find((value) => value.startsWith(prefix));
  const value = argument?.slice(prefix.length).trim();
  return value || undefined;
}

function readDefaultFirebaseProject(): string | undefined {
  const candidates = [
    resolve(process.cwd(), ".firebaserc"),
    resolve(process.cwd(), "..", ".firebaserc"),
  ];

  for (const filePath of candidates) {
    if (!existsSync(filePath)) {
      continue;
    }

    const parsed = JSON.parse(readFileSync(filePath, "utf8")) as {
      projects?: {default?: unknown};
    };

    const defaultProject = parsed.projects?.default;
    if (typeof defaultProject === "string" && defaultProject.trim()) {
      return defaultProject.trim();
    }
  }

  return undefined;
}

function isLocalFirestoreHost(value: string): boolean {
  const host = value.split(":")[0]?.toLowerCase();
  return host === "127.0.0.1" || host === "localhost" || host === "::1";
}
