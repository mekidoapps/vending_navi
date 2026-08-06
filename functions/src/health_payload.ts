export interface EmulatorHealthPayload {
  readonly ok: true;
  readonly service: "vending-navi-v2-functions";
  readonly mode: "emulator";
}

export function buildHealthPayload(): EmulatorHealthPayload {
  return {
    ok: true,
    service: "vending-navi-v2-functions",
    mode: "emulator",
  };
}
