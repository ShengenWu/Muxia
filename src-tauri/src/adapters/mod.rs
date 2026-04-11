mod claude;
mod codex;

use crate::models::ActionKind;

pub use claude::ClaudeAdapter;
pub use codex::CodexAdapter;

#[derive(Debug, Clone)]
pub struct ParsedAction {
    pub kind: ActionKind,
    pub title: String,
    pub detail: Option<String>,
    pub artifact_path: Option<String>,
}

pub trait AgentAdapter: Send + Sync {
    fn name(&self) -> &'static str;
    fn parse_line(&self, line: &str) -> Option<ParsedAction>;
}
