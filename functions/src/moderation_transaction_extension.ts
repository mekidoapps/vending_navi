import type {ModerationAction, ModerationTarget} from "./moderation_core";

export type ModerationTransactionPhase = "mutation" | "finalize";
export interface ModerationTransactionContext { readonly moderatorUid: string; readonly requestId: string; readonly target: ModerationTarget; readonly action: ModerationAction; readonly reason: string; readonly phase?: ModerationTransactionPhase; readonly previousStatus?: string; readonly nextStatus?: string; }
export interface ModerationTransactionExtensionMetadata { readonly kind: string; readonly queue?: {readonly sourceType: "report" | "correction"; readonly itemId: string; readonly previousStatus: string; readonly nextStatus: string; readonly resolution: string | null}; }
export interface ModerationTransactionPort { setPrivateRecord(id: string, value: Readonly<Record<string, unknown>>): void; setQueueRecord(sourceType: "report" | "correction", itemId: string, value: Readonly<Record<string, unknown>>): void; }
export interface ModerationTransactionExtension { readonly phase: ModerationTransactionPhase; readonly metadata: ModerationTransactionExtensionMetadata; validate(context: ModerationTransactionContext): void; stage(context: ModerationTransactionContext, port: ModerationTransactionPort): void; }
export const noModerationTransactionExtension: ModerationTransactionExtension = {phase: "mutation", metadata: {kind: "none"}, validate: () => undefined, stage: () => undefined};
export const noFinalizeModerationTransactionExtension: ModerationTransactionExtension = {phase: "finalize", metadata: {kind: "none"}, validate: () => undefined, stage: () => undefined};
export function createModerationTransactionContext(context: ModerationTransactionContext): ModerationTransactionContext { if (context.moderatorUid.trim().length === 0 || context.requestId.trim().length === 0 || context.reason.trim().length === 0) throw new ModerationTransactionContextError("invalid-moderation-transaction-context"); return context; }
export class ModerationTransactionContextError extends Error { constructor(readonly code: string) { super(code); } }
