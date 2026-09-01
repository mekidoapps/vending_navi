export const DELETE_ACCOUNT_CONFIRMATION =
  "DELETE_ACCOUNT";

export const RECENT_AUTH_MAX_AGE_SECONDS =
  10 * 60;

export interface DeleteAccountInput {
  readonly confirmation:
    typeof DELETE_ACCOUNT_CONFIRMATION;
}

export type DeleteAccountValidationReason =
  | "invalid-input"
  | "recent-auth-required";

export class DeleteAccountValidationError
  extends Error {
  constructor(
    message: string,
    readonly reason:
      DeleteAccountValidationReason =
        "invalid-input",
  ) {
    super(message);
    this.name =
      "DeleteAccountValidationError";
  }
}

export function parseDeleteAccountInput(
  raw: unknown,
): DeleteAccountInput {
  if (
    typeof raw !== "object" ||
    raw === null ||
    Array.isArray(raw)
  ) {
    throw new DeleteAccountValidationError(
      "Account deletion input must be an object.",
    );
  }

  const data =
    raw as Record<string, unknown>;

  const allowedKeys =
    new Set(["confirmation"]);

  for (const key of Object.keys(data)) {
    if (!allowedKeys.has(key)) {
      throw new DeleteAccountValidationError(
        `Unknown account deletion field: ${key}`,
      );
    }
  }

  if (
    data.confirmation !==
      DELETE_ACCOUNT_CONFIRMATION
  ) {
    throw new DeleteAccountValidationError(
      "Explicit account deletion confirmation is required.",
    );
  }

  return {
    confirmation:
      DELETE_ACCOUNT_CONFIRMATION,
  };
}

export function assertRecentAuthentication(
  authTimeSeconds: unknown,
  nowSeconds: number,
): void {
  if (
    typeof authTimeSeconds !== "number" ||
    !Number.isFinite(authTimeSeconds) ||
    authTimeSeconds <= 0
  ) {
    throw recentAuthError();
  }

  if (
    !Number.isFinite(nowSeconds) ||
    nowSeconds <= 0
  ) {
    throw new Error(
      "Current authentication-check time is invalid.",
    );
  }

  const ageSeconds =
    nowSeconds - authTimeSeconds;

  if (
    ageSeconds < 0 ||
    ageSeconds >
      RECENT_AUTH_MAX_AGE_SECONDS
  ) {
    throw recentAuthError();
  }
}

function recentAuthError():
  DeleteAccountValidationError {
  return new DeleteAccountValidationError(
    "Recent authentication is required before deleting the account.",
    "recent-auth-required",
  );
}
