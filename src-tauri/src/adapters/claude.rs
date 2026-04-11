use crate::adapters::{AgentAdapter, ParsedAction};
use crate::models::ActionKind;
use regex::Regex;

pub struct ClaudeAdapter {
    file_read: Regex,
    file_write: Regex,
    command: Regex,
}

impl Default for ClaudeAdapter {
    fn default() -> Self {
        Self {
            file_read: Regex::new(r"(?i)read(?:ing)?\s+file\s+(.+)$").expect("valid regex"),
            file_write: Regex::new(r"(?i)(?:updated|wrote|editing)\s+(.+)$").expect("valid regex"),
            command: Regex::new(r"(?i)running\s+command\s*:?\s*(.+)$").expect("valid regex"),
        }
    }
}

impl AgentAdapter for ClaudeAdapter {
    fn name(&self) -> &'static str {
        "claude"
    }

    fn parse_line(&self, line: &str) -> Option<ParsedAction> {
        if let Some(captures) = self.file_read.captures(line) {
            let path = captures.get(1)?.as_str().trim().to_string();
            return Some(ParsedAction {
                kind: ActionKind::FileRead,
                title: format!("Read {path}"),
                detail: Some(line.to_string()),
                artifact_path: Some(path),
            });
        }

        if let Some(captures) = self.file_write.captures(line) {
            let path = captures.get(1)?.as_str().trim().to_string();
            return Some(ParsedAction {
                kind: ActionKind::FileWrite,
                title: format!("Write {path}"),
                detail: Some(line.to_string()),
                artifact_path: Some(path),
            });
        }

        if let Some(captures) = self.command.captures(line) {
            let cmd = captures.get(1)?.as_str().trim().to_string();
            return Some(ParsedAction {
                kind: ActionKind::CommandRun,
                title: cmd,
                detail: Some(line.to_string()),
                artifact_path: None,
            });
        }

        None
    }
}
