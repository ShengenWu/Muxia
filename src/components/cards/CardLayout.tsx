import { useEffect, useMemo, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { runtimeLogger } from "../../lib/runtimeDiagnostics";
import { ALL_CARD_IDS, isPaneCardId, type PaneCardId } from "../../state/layoutCards";
import { AgentChatCard } from "./AgentChatCard";
import { ChangeTrackingCard } from "./ChangeTrackingCard";
import { DiffCard } from "./DiffCard";
import { SessionGraphCard } from "./SessionGraphCard";
import { TerminalCard } from "./TerminalCard";

const storageKeyForScope = (storageScope: string) => `new-terminal-layout:${storageScope}`;
const STORAGE_VERSION = 1;
const MIN_RATIO = 0.2;
const MAX_RATIO = 0.8;

type SplitAxis = "horizontal" | "vertical";

type PaneTree =
  | { kind: "leaf"; cardId: PaneCardId }
  | { kind: "split"; path: string; axis: SplitAxis; first: PaneTree; second: PaneTree };

interface PaneLayoutSnapshot {
  cards: PaneCardId[];
  ratios: Record<string, number>;
}

interface PersistedPaneLayoutSnapshot {
  version: number;
  data: PaneLayoutSnapshot;
}

interface CardLayoutProps {
  storageScope: string;
  defaultCards: PaneCardId[];
  pendingAddCardId?: PaneCardId;
  onPendingAddHandled?: () => void;
  onCardsChange?: (cards: PaneCardId[]) => void;
}

const CARD_REGISTRY: Record<PaneCardId, { label: string; render: () => ReactNode }> = {
  chat: {
    label: "Chat",
    render: () => <AgentChatCard />
  },
  graph: {
    label: "Graph",
    render: () => <SessionGraphCard />
  },
  change_tracking: {
    label: "Change Tracking",
    render: () => <ChangeTrackingCard />
  },
  diff: {
    label: "Diff",
    render: () => <DiffCard />
  },
  terminal: {
    label: "Terminal",
    render: () => <TerminalCard />
  }
};

const clampRatio = (value: number): number => {
  return Math.min(MAX_RATIO, Math.max(MIN_RATIO, value));
};

const normalizeCardOrder = (cards: PaneCardId[]): PaneCardId[] => {
  const unique = new Set<PaneCardId>();
  cards.forEach((cardId) => {
    if (isPaneCardId(cardId)) {
      unique.add(cardId);
    }
  });

  return [...unique];
};

const loadPaneLayout = (storageScope: string, defaultCards: PaneCardId[]): PaneLayoutSnapshot => {
  const normalizedDefaults = normalizeCardOrder(defaultCards);
  const raw = window.localStorage.getItem(storageKeyForScope(storageScope));
  if (!raw) {
    return { cards: normalizedDefaults, ratios: {} };
  }

  try {
    const parsed = JSON.parse(raw) as PersistedPaneLayoutSnapshot | unknown;
    if (!parsed || typeof parsed !== "object" || !("version" in parsed) || !("data" in parsed)) {
      window.localStorage.removeItem(storageKeyForScope(storageScope));
      return { cards: normalizedDefaults, ratios: {} };
    }

    if (parsed.version !== STORAGE_VERSION) {
      runtimeLogger.warn("layout", "Pane layout storage version mismatch; resetting scope", { storageScope });
      window.localStorage.removeItem(storageKeyForScope(storageScope));
      return { cards: normalizedDefaults, ratios: {} };
    }

    const data = parsed.data;
    if (!data || typeof data !== "object") {
      window.localStorage.removeItem(storageKeyForScope(storageScope));
      return { cards: normalizedDefaults, ratios: {} };
    }

    const snapshot = data as Partial<PaneLayoutSnapshot>;
    const cards = Array.isArray(snapshot.cards)
      ? normalizeCardOrder(snapshot.cards.filter((card): card is PaneCardId => typeof card === "string" && isPaneCardId(card)))
      : normalizedDefaults;
    const ratios = Object.fromEntries(
      Object.entries(snapshot.ratios ?? {}).filter((entry): entry is [string, number] => {
        return typeof entry[0] === "string" && typeof entry[1] === "number" && Number.isFinite(entry[1]);
      })
    );

    return {
      cards: cards.length > 0 ? cards : normalizedDefaults,
      ratios
    };
  } catch {
    runtimeLogger.error("layout", "Failed to parse pane layout; resetting scope", { storageScope });
    window.localStorage.removeItem(storageKeyForScope(storageScope));
    return { cards: normalizedDefaults, ratios: {} };
  }
};

const buildPaneTree = (cards: PaneCardId[], depth = 0, path = "root"): PaneTree => {
  if (cards.length === 1) {
    return { kind: "leaf", cardId: cards[0] };
  }

  const splitIndex = Math.ceil(cards.length / 2);
  const axis: SplitAxis = depth % 2 === 0 ? "horizontal" : "vertical";
  return {
    kind: "split",
    path,
    axis,
    first: buildPaneTree(cards.slice(0, splitIndex), depth + 1, `${path}.0`),
    second: buildPaneTree(cards.slice(splitIndex), depth + 1, `${path}.1`)
  };
};

export function CardLayout({
  storageScope,
  defaultCards,
  pendingAddCardId,
  onPendingAddHandled,
  onCardsChange
}: CardLayoutProps) {
  const [snapshot, setSnapshot] = useState<PaneLayoutSnapshot>(() => loadPaneLayout(storageScope, defaultCards));

  useEffect(() => {
    setSnapshot(loadPaneLayout(storageScope, defaultCards));
  }, [storageScope, defaultCards]);

  useEffect(() => {
    const persisted: PersistedPaneLayoutSnapshot = {
      version: STORAGE_VERSION,
      data: snapshot
    };
    window.localStorage.setItem(storageKeyForScope(storageScope), JSON.stringify(persisted));
    onCardsChange?.(snapshot.cards);
  }, [onCardsChange, snapshot, storageScope]);

  useEffect(() => {
    if (!pendingAddCardId) {
      return;
    }

    setSnapshot((current) => {
      if (current.cards.includes(pendingAddCardId)) {
        return current;
      }

      runtimeLogger.info("layout", "Adding card to pane layout", {
        storageScope,
        cardId: pendingAddCardId
      });
      return {
        ...current,
        cards: [...current.cards, pendingAddCardId]
      };
    });
    onPendingAddHandled?.();
  }, [onPendingAddHandled, pendingAddCardId, storageScope]);

  const tree = useMemo(() => buildPaneTree(snapshot.cards), [snapshot.cards]);

  if (snapshot.cards.length === 0) {
    return <section className="layout layout-pane empty">No cards configured for this layout.</section>;
  }

  return (
    <section className="layout layout-pane">
      <PaneNodeView
        node={tree}
        ratios={snapshot.ratios}
        onRatioChange={(path, ratio) => {
          setSnapshot((current) => ({
            ...current,
            ratios: {
              ...current.ratios,
              [path]: clampRatio(ratio)
            }
          }));
        }}
      />
    </section>
  );
}

interface PaneNodeViewProps {
  node: PaneTree;
  ratios: Record<string, number>;
  onRatioChange: (path: string, ratio: number) => void;
}

function PaneNodeView({ node, ratios, onRatioChange }: PaneNodeViewProps) {
  if (node.kind === "leaf") {
    return <div className="pane-leaf">{CARD_REGISTRY[node.cardId].render()}</div>;
  }

  const ratio = clampRatio(ratios[node.path] ?? 0.5);
  return (
    <SplitPane
      axis={node.axis}
      ratio={ratio}
      onRatioChange={(nextRatio) => onRatioChange(node.path, nextRatio)}
      first={<PaneNodeView node={node.first} ratios={ratios} onRatioChange={onRatioChange} />}
      second={<PaneNodeView node={node.second} ratios={ratios} onRatioChange={onRatioChange} />}
    />
  );
}

interface SplitPaneProps {
  axis: SplitAxis;
  ratio: number;
  onRatioChange: (ratio: number) => void;
  first: ReactNode;
  second: ReactNode;
}

function SplitPane({ axis, ratio, onRatioChange, first, second }: SplitPaneProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);

  const handleDragStart = (event: React.MouseEvent<HTMLDivElement>) => {
    event.preventDefault();
    const container = containerRef.current;
    if (!container) {
      return;
    }

    const rect = container.getBoundingClientRect();
    const size = axis === "horizontal" ? rect.width : rect.height;
    const startPoint = axis === "horizontal" ? event.clientX : event.clientY;
    const startRatio = ratio;

    const handleMove = (moveEvent: MouseEvent) => {
      const currentPoint = axis === "horizontal" ? moveEvent.clientX : moveEvent.clientY;
      const delta = currentPoint - startPoint;
      if (size <= 0) {
        return;
      }
      onRatioChange(startRatio + delta / size);
    };

    const handleUp = () => {
      window.removeEventListener("mousemove", handleMove);
      window.removeEventListener("mouseup", handleUp);
    };

    window.addEventListener("mousemove", handleMove);
    window.addEventListener("mouseup", handleUp);
  };

  const firstStyle: CSSProperties = axis === "horizontal"
    ? { flexBasis: `calc(${ratio * 100}% - 3px)` }
    : { flexBasis: `calc(${ratio * 100}% - 3px)` };

  return (
    <div className={axis === "horizontal" ? "pane-split pane-split-row" : "pane-split pane-split-column"} ref={containerRef}>
      <div className="pane-branch" style={firstStyle}>{first}</div>
      <div
        className={axis === "horizontal" ? "pane-divider pane-divider-vertical" : "pane-divider pane-divider-horizontal"}
        onMouseDown={handleDragStart}
        role="separator"
      />
      <div className="pane-branch pane-branch-flex">{second}</div>
    </div>
  );
}

export { ALL_CARD_IDS };
export type { PaneCardId };
