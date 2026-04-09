import { create } from "zustand";
import type {
  ActionNode,
  ChatMessage,
  DiffArtifact,
  EventType,
  EventEnvelope,
  GraphEdge,
  SessionRecord
} from "../types/events";

interface AppState {
  sessions: Record<string, SessionRecord>;
  activeSessionId?: string;
  messages: Record<string, ChatMessage[]>;
  nodes: Record<string, ActionNode[]>;
  edges: Record<string, GraphEdge[]>;
  diffs: Record<string, DiffArtifact[]>;
  selectedDiffPath?: string;
  appendEvent: (event: EventEnvelope) => void;
  setActiveSession: (sessionId: string) => void;
  selectDiffPath: (path?: string) => void;
}

const mergeById = <T extends { id: string }>(current: T[], item: T): T[] => {
  const idx = current.findIndex((v) => v.id === item.id);
  if (idx === -1) {
    return [...current, item];
  }

  const copy = [...current];
  copy[idx] = item;
  return copy;
};

const normalizeEventType = (eventType: string): EventType => {
  const legacyMap: Record<string, EventType> = {
    "session.started": "session_started",
    "session.ended": "session_ended",
    "message.user": "message_user",
    "message.agent": "message_assistant",
    "action.detected": "action_tool_call",
    "file.changed": "file_changed",
    "diff.updated": "file_changed"
  };

  return (legacyMap[eventType] ?? eventType) as EventType;
};

export const useAppStore = create<AppState>((set) => ({
  sessions: {},
  activeSessionId: undefined,
  messages: {},
  nodes: {},
  edges: {},
  diffs: {},
  selectedDiffPath: undefined,
  setActiveSession: (sessionId) => set({ activeSessionId: sessionId }),
  selectDiffPath: (path) => set({ selectedDiffPath: path }),
  appendEvent: (event) =>
    set((state) => {
      const next = { ...state };
      const sessionId = event.session_id;
      const rawEventType = ((event as unknown as { event_type?: string; type?: string }).event_type
        ?? (event as unknown as { event_type?: string; type?: string }).type
        ?? "");
      const eventType = normalizeEventType(rawEventType);

      if (eventType === "session_started") {
        const payload = event.payload as {
          agent_type?: "claude" | "codex";
          adapter?: "claude" | "codex";
          cwd: string;
        };
        next.sessions = {
          ...state.sessions,
          [sessionId]: {
            sessionId,
            agentType: payload.agent_type ?? payload.adapter ?? "claude",
            cwd: payload.cwd,
            startedAt: event.ts
          }
        };
        if (!state.activeSessionId) {
          next.activeSessionId = sessionId;
        }
      }

      if (eventType === "session_ended") {
        const session = state.sessions[sessionId];
        if (session) {
          next.sessions = {
            ...state.sessions,
            [sessionId]: {
              ...session,
              endedAt: event.ts
            }
          };
        }
      }

      if (eventType === "message_user" || eventType === "message_assistant") {
        const payload = event.payload as { id: string; content: string };
        const current = state.messages[sessionId] ?? [];
        const role = eventType === "message_user" ? "user" : "agent";
        const message: ChatMessage = {
          id: payload.id,
          sessionId,
          role,
          content: payload.content,
          ts: event.ts
        };
        next.messages = {
          ...state.messages,
          [sessionId]: mergeById(current, message)
        };
      }

      if (eventType === "action_tool_call") {
        const payload = event.payload as {
          id: string;
          tool_name?: ActionNode["kind"];
          kind?: ActionNode["kind"];
          title: string;
          detail?: string;
          artifact_path?: string;
          artifactPath?: string;
          edge?: {
            id: string;
            session_id?: string;
            sessionId?: string;
            from: string;
            to: string;
            kind: GraphEdge["kind"];
          };
        };
        const currentNodes = state.nodes[sessionId] ?? [];
        const node: ActionNode = {
          id: payload.id,
          sessionId,
          ts: event.ts,
          kind: payload.tool_name ?? payload.kind ?? "tool_call",
          title: payload.title,
          detail: payload.detail,
          confidence: event.confidence,
          artifactPath: payload.artifact_path ?? payload.artifactPath
        };
        next.nodes = {
          ...state.nodes,
          [sessionId]: mergeById(currentNodes, node)
        };

        if (payload.edge) {
          const currentEdges = state.edges[sessionId] ?? [];
          const normalizedEdge: GraphEdge = {
            id: payload.edge.id,
            sessionId: payload.edge.sessionId ?? payload.edge.session_id ?? sessionId,
            from: payload.edge.from,
            to: payload.edge.to,
            kind: payload.edge.kind
          };
          next.edges = {
            ...state.edges,
            [sessionId]: mergeById(currentEdges, normalizedEdge)
          };
        }
      }

      if (eventType === "file_changed" || eventType === "file_created" || eventType === "file_deleted") {
        const payload = event.payload as {
          path: string;
          change_type?: "modified" | "created" | "deleted";
          before?: string;
          after?: string;
          ts?: string;
        };
        if (!payload.path) {
          return next;
        }
        const current = state.diffs[sessionId] ?? [];
        const nextArtifact: DiffArtifact = {
          path: payload.path,
          sessionId,
          changeType: payload.change_type ?? "modified",
          before: payload.before ?? "",
          after: payload.after ?? "",
          ts: payload.ts ?? event.ts
        };
        const idx = current.findIndex((d) => d.path === nextArtifact.path);
        const updated = [...current];
        if (idx >= 0) {
          updated[idx] = nextArtifact;
        } else {
          updated.push(nextArtifact);
        }
        next.diffs = {
          ...state.diffs,
          [sessionId]: updated
        };
        if (!state.selectedDiffPath) {
          next.selectedDiffPath = nextArtifact.path;
        }
      }

      return next;
    })
}));
