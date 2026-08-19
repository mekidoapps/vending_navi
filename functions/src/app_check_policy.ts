export interface AppCheckRuntimeEnvironment {
  readonly FUNCTIONS_EMULATOR?: string;
}

/**
 * Production Functions must enforce Firebase App Check.
 *
 * The local Functions Emulator does not issue/require production App Check
 * tokens, so enforcement is disabled only when Firebase explicitly marks the
 * runtime as an emulator.
 */
export function shouldEnforceAppCheck(
  env: AppCheckRuntimeEnvironment,
): boolean {
  return env.FUNCTIONS_EMULATOR !== "true";
}
