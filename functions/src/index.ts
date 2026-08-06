import {HttpsError, onCall} from "firebase-functions/v2/https";

import {buildHealthPayload} from "./health_payload";

/**
 * Infrastructure-only callable used to confirm the local Functions emulator.
 * It performs no reads or writes and refuses execution outside the emulator.
 */
export const v2EmulatorHealth = onCall(() => {
  if (process.env.FUNCTIONS_EMULATOR !== "true") {
    throw new HttpsError(
      "failed-precondition",
      "v2EmulatorHealth is available only in the local emulator.",
    );
  }

  return buildHealthPayload();
});
