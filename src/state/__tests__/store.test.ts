import { beforeEach, describe, expect, it } from "vitest";
import { useAppStore } from "../store";
import type { EventEnvelope, GraphEdge } from "../../types/events";

const baseEvent = (overrides: Partial<EventEnvelope>): EventEnvelope => ({
  event_id: "e1",
  session_id: "s1",
  ts: new Date("2026-04-09T00:00:00Z").toISOString(),
  source: "system",
  event_type: "session_started",
  confidence: 1,
  payload: {},
  ...overrides
});

describe("store event reducer", () => {
  beforeEach(() => {
    useAppStore.setState({
      sessions: {},
      activeSessionId: undefined,
      messages: {},
      nodes: {},
      edges: {},
      diffs: {},
      selectedDiffPathBySession: {},
      appendEvent: useAppStore.getState().appendEvent,
      setActiveSession: useAppStore.getState().setActiveSession,
      selectDiffPath: useAppStore.getState().selectDiffPath
    });
  });

  it("creates session and appends message/action/diff", () => {
    const append = useAppStore.getState().appendEvent;

    append(
      baseEvent({
        event_type: "session_started",
        payload: { agent_type: "claude", cwd: "/tmp" }
      })
    );

    append(
      baseEvent({
        event_id: "e2",
        event_type: "message_user",
        payload: { id: "m1", content: "hello" }
      })
    );

    const edge: GraphEdge = {
      id: "g1",
      sessionId: "s1",
      from: "n0",
      to: "n1",
      kind: "next"
    };

    append(
      baseEvent({
        event_id: "e3",
        event_type: "action_tool_call",
        payload: {
          id: "n1",
          tool_name: "file_write",
          title: "Write src/App.tsx",
          artifact_path: "src/App.tsx",
          edge
        }
      })
    );

    append(
      baseEvent({
        event_id: "e4",
        event_type: "file_changed",
        payload: {
          path: "src/App.tsx",
          change_type: "modified",
          before: "a",
          after: "b",
          ts: new Date("2026-04-09T00:00:01Z").toISOString()
        }
      })
    );

    const state = useAppStore.getState();
    expect(state.sessions.s1).toBeDefined();
    expect(state.activeSessionId).toBe("s1");
    expect(state.messages.s1).toHaveLength(1);
    expect(state.nodes.s1).toHaveLength(1);
    expect(state.edges.s1).toHaveLength(1);
    expect(state.diffs.s1).toHaveLength(1);
    expect(state.selectedDiffPathBySession.s1).toBe("src/App.tsx");
  });
});
