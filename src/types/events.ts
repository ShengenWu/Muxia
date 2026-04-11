export type EventSource = "system" | "pty" | "fs_watcher" | "adapter";

export type EventType =
  | "message_user"
  | "message_assistant"
  | "message_system"
  | "action_tool_call"
  | "action_tool_result"
  | "file_changed"
  | "file_created"
  | "file_deleted"
  | "session_started"
  | "session_compact"
  | "session_branched"
  | "session_ended"
  | "session_error";

export type ActionKind =
  | "command_run"
  | "file_read"
  | "file_write"
  | "test_run"
  | "tool_call"
  | "patch_apply";

export type EdgeKind =
  | "next"
  | "caused_by"
  | "reads"
  | "writes"
  | "validates"
  | "updates";

export interface EventEnvelope<TPayload = unknown> {
  event_id: string;
  session_id: string;
  ts: string;
  source: EventSource;
  event_type: EventType;
  confidence: number;
  payload: TPayload;
}

export interface SessionRecord {
  sessionId: string;
  projectId: string;
  agentType: "claude" | "codex";
  cwd: string;
  startedAt: string;
  endedAt?: string;
}

export interface ChatMessage {
  id: string;
  sessionId: string;
  role: "user" | "agent";
  content: string;
  ts: string;
}

export interface ActionNode {
  id: string;
  sessionId: string;
  ts: string;
  kind: ActionKind;
  title: string;
  detail?: string;
  confidence: number;
  artifactPath?: string;
}

export interface GraphEdge {
  id: string;
  sessionId: string;
  from: string;
  to: string;
  kind: EdgeKind;
}

export interface DiffArtifact {
  path: string;
  sessionId: string;
  changeType: "modified" | "created" | "deleted";
  before: string;
  after: string;
  ts: string;
}
