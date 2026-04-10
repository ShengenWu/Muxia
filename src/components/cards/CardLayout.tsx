import type { CSSProperties } from "react";
import type { Layout } from "react-grid-layout";
import { runtimeLogger } from "../../lib/runtimeDiagnostics";
import { AgentChatCard } from "./AgentChatCard";
import { ChangeTrackingCard } from "./ChangeTrackingCard";
import { DiffCard } from "./DiffCard";
import { SessionGraphCard } from "./SessionGraphCard";
import { TerminalCard } from "./TerminalCard";

const storageKeyForScope = (storageScope: string) => `new-terminal-layout:${storageScope}`;

interface PersistedLayoutSnapshot {
  version: number;
  data: Layout[];
}

const STORAGE_VERSION = 2;
const REQUIRED_CARD_IDS = ["chat", "graph", "change_tracking", "diff", "terminal"] as const;

const isValidLayout = (value: unknown): value is Layout[] => {
  return Array.isArray(value)
    && value.every((item) => (
      item
      && typeof item === "object"
      && typeof item.i === "string"
      && typeof item.x === "number"
      && typeof item.y === "number"
      && typeof item.w === "number"
      && typeof item.h === "number"
      && Number.isFinite(item.x)
      && Number.isFinite(item.y)
      && Number.isFinite(item.w)
      && Number.isFinite(item.h)
      && item.w > 0
      && item.h > 0
    ));
};

const loadLayout = (storageScope: string, fallbackLayout: Layout[]): Layout[] => {
  const storageKey = storageKeyForScope(storageScope);
  const raw = localStorage.getItem(storageKey);
  if (!raw) {
    return fallbackLayout;
  }

  try {
    const parsed = JSON.parse(raw) as PersistedLayoutSnapshot | Layout[];
    const layout = Array.isArray(parsed) ? parsed : parsed.data;
    const version = Array.isArray(parsed) ? 0 : parsed.version;

    if (version !== STORAGE_VERSION) {
      runtimeLogger.warn("layout", "Layout storage version mismatch; resetting scope", {
        storageScope,
        version
      });
      localStorage.removeItem(storageKey);
      return fallbackLayout;
    }

    if (!isValidLayout(layout)) {
      runtimeLogger.warn("layout", "Invalid stored layout shape; resetting scope", { storageScope });
      localStorage.removeItem(storageKey);
      return fallbackLayout;
    }

    const ids = new Set(layout.map((item) => item.i));
    if (REQUIRED_CARD_IDS.some((id) => !ids.has(id))) {
      runtimeLogger.warn("layout", "Stored layout missing required cards; resetting scope", {
        storageScope,
        ids: [...ids]
      });
      localStorage.removeItem(storageKey);
      return fallbackLayout;
    }

    return layout;
  } catch {
    runtimeLogger.error("layout", "Failed to parse stored layout; resetting scope", { storageScope });
    localStorage.removeItem(storageKey);
    return fallbackLayout;
  }
};

interface CardLayoutProps {
  storageScope: string;
  defaultLayout: Layout[];
}

export function CardLayout({ storageScope, defaultLayout }: CardLayoutProps) {
  const layout = loadLayout(storageScope, defaultLayout);
  const layoutById = new Map(layout.map((item) => [item.i, item]));

  return (
    <section className="layout layout-static">
      <div className="grid-item" style={toGridStyle(layoutById.get("chat"))}><AgentChatCard /></div>
      <div className="grid-item" style={toGridStyle(layoutById.get("graph"))}><SessionGraphCard /></div>
      <div className="grid-item" style={toGridStyle(layoutById.get("change_tracking"))}><ChangeTrackingCard /></div>
      <div className="grid-item" style={toGridStyle(layoutById.get("diff"))}><DiffCard /></div>
      <div className="grid-item" style={toGridStyle(layoutById.get("terminal"))}><TerminalCard /></div>
    </section>
  );
}

const toGridStyle = (item?: Layout): CSSProperties => {
  if (!item) {
    return {};
  }

  return {
    gridColumn: `${item.x + 1} / span ${item.w}`,
    gridRow: `${item.y + 1} / span ${item.h}`
  };
};
