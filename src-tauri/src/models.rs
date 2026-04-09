use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EventSource {
    System,
    Pty,
    FsWatcher,
    Adapter,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EventType {
    #[serde(rename = "session_started")]
    SessionStarted,
    #[serde(rename = "session_compact")]
    SessionCompact,
    #[serde(rename = "session_branched")]
    SessionBranched,
    #[serde(rename = "session_ended")]
    SessionEnded,
    #[serde(rename = "session_error")]
    SessionError,
    #[serde(rename = "message_user")]
    MessageUser,
    #[serde(rename = "message_assistant")]
    MessageAssistant,
    #[serde(rename = "message_system")]
    MessageSystem,
    #[serde(rename = "action_tool_call")]
    ActionToolCall,
    #[serde(rename = "action_tool_result")]
    ActionToolResult,
    #[serde(rename = "file_changed")]
    FileChanged,
    #[serde(rename = "file_created")]
    FileCreated,
    #[serde(rename = "file_deleted")]
    FileDeleted,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ActionKind {
    CommandRun,
    FileRead,
    FileWrite,
    TestRun,
    ToolCall,
    PatchApply,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EdgeKind {
    Next,
    CausedBy,
    Reads,
    Writes,
    Validates,
    Updates,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphEdge {
    pub id: String,
    pub session_id: String,
    pub from: String,
    pub to: String,
    pub kind: EdgeKind,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EventEnvelope {
    pub event_id: String,
    pub session_id: String,
    pub ts: DateTime<Utc>,
    pub source: EventSource,
    pub event_type: EventType,
    pub confidence: f32,
    pub payload: serde_json::Value,
}

impl EventEnvelope {
    pub fn new(
        session_id: impl Into<String>,
        source: EventSource,
        event_type: EventType,
        confidence: f32,
        payload: serde_json::Value,
    ) -> Self {
        Self {
            event_id: uuid::Uuid::new_v4().to_string(),
            session_id: session_id.into(),
            ts: Utc::now(),
            source,
            event_type,
            confidence,
            payload,
        }
    }
}
