import type { CSSProperties } from "react";
import type { Layout } from "react-grid-layout";
import { AgentChatCard } from "./AgentChatCard";
import { ChangeTrackingCard } from "./ChangeTrackingCard";
import { DiffCard } from "./DiffCard";
import { SessionGraphCard } from "./SessionGraphCard";
import { TerminalCard } from "./TerminalCard";

const storageKeyForScope = (storageScope: string) => `new-terminal-layout:${storageScope}`;

const loadLayout = (storageScope: string, fallbackLayout: Layout[]): Layout[] => {
  const raw = localStorage.getItem(storageKeyForScope(storageScope));
  if (!raw) {
    return fallbackLayout;
  }

  try {
    const parsed = JSON.parse(raw) as Layout[];
    if (!Array.isArray(parsed)) {
      return fallbackLayout;
    }
    return parsed;
  } catch {
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
