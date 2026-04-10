import { useSyncExternalStore } from "react";

export type RuntimeLogLevel = "debug" | "info" | "warn" | "error";

export interface RuntimeLogEntry {
  id: string;
  ts: string;
  level: RuntimeLogLevel;
  scope: string;
  message: string;
  details?: unknown;
}

const MAX_LOGS = 300;
const BOOT_STATUS_KEY = "new-terminal-boot-status";
const WORKSPACE_STORAGE_KEY = "new-terminal-workspace";
const LAYOUT_STORAGE_PREFIX = "new-terminal-layout:";
const listeners = new Set<() => void>();
const entries: RuntimeLogEntry[] = [];
let diagnosticsInstalled = false;
let consolePatched = false;
let patchingConsole = false;

const notify = () => {
  listeners.forEach((listener) => listener());
};

const snapshot = () => [...entries];

const pushEntry = (entry: RuntimeLogEntry) => {
  entries.push(entry);
  if (entries.length > MAX_LOGS) {
    entries.splice(0, entries.length - MAX_LOGS);
  }
  notify();
};

const createEntry = (
  level: RuntimeLogLevel,
  scope: string,
  message: string,
  details?: unknown
): RuntimeLogEntry => ({
  id: `${Date.now()}-${Math.random().toString(16).slice(2)}`,
  ts: new Date().toISOString(),
  level,
  scope,
  message,
  details
});

const mirrorToConsole = (entry: RuntimeLogEntry) => {
  if (patchingConsole) {
    return;
  }

  patchingConsole = true;
  try {
    const payload: unknown[] = [`[${entry.level}] [${entry.scope}] ${entry.message}`];
    if (entry.details !== undefined) {
      payload.push(entry.details);
    }

    if (entry.level === "error") {
      console.error(...payload);
    } else if (entry.level === "warn") {
      console.warn(...payload);
    } else {
      console.log(...payload);
    }
  } finally {
    patchingConsole = false;
  }
};

export const addRuntimeLog = (
  level: RuntimeLogLevel,
  scope: string,
  message: string,
  details?: unknown
) => {
  const entry = createEntry(level, scope, message, details);
  pushEntry(entry);
  mirrorToConsole(entry);
  return entry;
};

export const runtimeLogger = {
  debug: (scope: string, message: string, details?: unknown) =>
    addRuntimeLog("debug", scope, message, details),
  info: (scope: string, message: string, details?: unknown) =>
    addRuntimeLog("info", scope, message, details),
  warn: (scope: string, message: string, details?: unknown) =>
    addRuntimeLog("warn", scope, message, details),
  error: (scope: string, message: string, details?: unknown) =>
    addRuntimeLog("error", scope, message, details)
};

const formatUnknownError = (error: unknown) => {
  if (error instanceof Error) {
    return {
      name: error.name,
      message: error.message,
      stack: error.stack
    };
  }

  return { value: String(error) };
};

const clearPersistedUiState = (reason: string) => {
  if (typeof window === "undefined") {
    return;
  }

  const keysToRemove: string[] = [];
  for (let index = 0; index < window.localStorage.length; index += 1) {
    const key = window.localStorage.key(index);
    if (!key) {
      continue;
    }
    if (key === WORKSPACE_STORAGE_KEY || key.startsWith(LAYOUT_STORAGE_PREFIX)) {
      keysToRemove.push(key);
    }
  }

  keysToRemove.forEach((key) => window.localStorage.removeItem(key));
  addRuntimeLog("warn", "diagnostics", "Cleared persisted UI state", { reason, keysToRemove });
};

const installStartupGuard = () => {
  if (typeof window === "undefined") {
    return;
  }

  try {
    const previousBoot = window.localStorage.getItem(BOOT_STATUS_KEY);
    if (previousBoot) {
      const parsed = JSON.parse(previousBoot) as { state?: string; ts?: string };
      if (parsed.state === "booting") {
        clearPersistedUiState("previous boot did not reach healthy state");
      }
    }

    window.localStorage.setItem(
      BOOT_STATUS_KEY,
      JSON.stringify({
        state: "booting",
        ts: new Date().toISOString()
      })
    );
  } catch (error) {
    addRuntimeLog("error", "diagnostics", "Failed to install startup guard", formatUnknownError(error));
  }
};

export const markRuntimeHealthy = () => {
  if (typeof window === "undefined") {
    return;
  }

  try {
    window.localStorage.setItem(
      BOOT_STATUS_KEY,
      JSON.stringify({
        state: "healthy",
        ts: new Date().toISOString()
      })
    );
    addRuntimeLog("info", "diagnostics", "Marked runtime as healthy");
  } catch (error) {
    addRuntimeLog("error", "diagnostics", "Failed to mark runtime healthy", formatUnknownError(error));
  }
};

export const installRuntimeDiagnostics = () => {
  if (diagnosticsInstalled || typeof window === "undefined") {
    return;
  }

  installStartupGuard();
  diagnosticsInstalled = true;
  runtimeLogger.info("diagnostics", "Installing runtime diagnostics");

  window.addEventListener("error", (event) => {
    runtimeLogger.error("window", "Unhandled window error", {
      message: event.message,
      filename: event.filename,
      lineno: event.lineno,
      colno: event.colno,
      error: formatUnknownError(event.error)
    });
  });

  window.addEventListener("unhandledrejection", (event) => {
    runtimeLogger.error("window", "Unhandled promise rejection", formatUnknownError(event.reason));
  });

  if (!consolePatched) {
    consolePatched = true;

    const originalError = console.error.bind(console);
    const originalWarn = console.warn.bind(console);

    console.error = (...args: unknown[]) => {
      if (!patchingConsole) {
        pushEntry(createEntry("error", "console", "console.error", args));
        notify();
      }
      originalError(...args);
    };

    console.warn = (...args: unknown[]) => {
      if (!patchingConsole) {
        pushEntry(createEntry("warn", "console", "console.warn", args));
        notify();
      }
      originalWarn(...args);
    };
  }
};

export const getRuntimeLogs = () => snapshot();

export const useRuntimeLogs = () =>
  useSyncExternalStore(
    (listener) => {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    snapshot,
    snapshot
  );
