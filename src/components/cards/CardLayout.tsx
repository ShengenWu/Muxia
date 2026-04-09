import GridLayout, { WidthProvider, type Layout } from "react-grid-layout";
import { AgentChatCard } from "./AgentChatCard";
import { ChangeTrackingCard } from "./ChangeTrackingCard";
import { DiffCard } from "./DiffCard";
import { SessionGraphCard } from "./SessionGraphCard";
import { TerminalCard } from "./TerminalCard";

const ResponsiveGridLayout = WidthProvider(GridLayout);

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
  return (
    <ResponsiveGridLayout
      className="layout"
      layout={loadLayout(storageScope, defaultLayout)}
      cols={12}
      rowHeight={48}
      width={1180}
      margin={[12, 12]}
      draggableHandle=".card-header"
      onLayoutChange={(layout: Layout[]) =>
        localStorage.setItem(storageKeyForScope(storageScope), JSON.stringify(layout))
      }
    >
      <div key="chat" className="grid-item"><AgentChatCard /></div>
      <div key="graph" className="grid-item"><SessionGraphCard /></div>
      <div key="change_tracking" className="grid-item"><ChangeTrackingCard /></div>
      <div key="diff" className="grid-item"><DiffCard /></div>
      <div key="terminal" className="grid-item"><TerminalCard /></div>
    </ResponsiveGridLayout>
  );
}
