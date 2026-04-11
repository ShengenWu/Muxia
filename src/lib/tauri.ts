import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import type { EventEnvelope } from "../types/events";
import { runtimeLogger } from "./runtimeDiagnostics";

export const isTauriRuntime = (): boolean => {
  return typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;
};

export async function tauriInvoke<T>(cmd: string, args?: Record<string, unknown>): Promise<T> {
  if (!isTauriRuntime()) {
    runtimeLogger.warn("tauri", "Invoke attempted outside Tauri runtime", { cmd, args });
    throw new Error(`Tauri runtime is required for ${cmd}`);
  }
  runtimeLogger.info("tauri", "Invoking Tauri command", { cmd, args });
  try {
    const result = await invoke<T>(cmd, args);
    runtimeLogger.debug("tauri", "Tauri command resolved", { cmd });
    return result;
  } catch (error) {
    runtimeLogger.error("tauri", "Tauri command failed", { cmd, args, error });
    throw error;
  }
}

export const emitFrontendLog = (channel: string, message: string, details?: unknown) => {
  if (!isTauriRuntime()) {
    return;
  }

  void invoke("frontend_log", {
    channel,
    message,
    details: details === undefined ? undefined : safeSerialize(details)
  }).catch(() => {
    // Ignore logging transport failures to avoid cascading render issues.
  });
};

export async function onBackendEvent(
  handler: (event: EventEnvelope) => void
): Promise<() => void> {
  if (!isTauriRuntime()) {
    runtimeLogger.warn("tauri", "Backend event listener skipped outside Tauri runtime");
    return () => {};
  }

  runtimeLogger.info("tauri", "Subscribing to backend:event");
  const unlisten = await listen<EventEnvelope>("backend:event", (event) => {
    runtimeLogger.debug("tauri", "Received backend:event", {
      event_type: event.payload.event_type,
      session_id: event.payload.session_id
    });
    handler(event.payload);
  });

  return () => {
    runtimeLogger.info("tauri", "Unsubscribing from backend:event");
    unlisten();
  };
}

const safeSerialize = (value: unknown): string => {
  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
};
