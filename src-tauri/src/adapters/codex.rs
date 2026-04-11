use crate::adapters::{AgentAdapter, ParsedAction};
use crate::models::ActionKind;
use regex::Regex;

pub struct CodexAdapter {
    read: Regex,
    write: Regex,
    test: Regex,
    command: Regex,
}

impl Default for CodexAdapter {
    fn default() -> Self {
        Self {
            read: Regex::new(r"(?i)(?:open|read)\s+([\w\-./]+)").expect("valid regex"),
            write: Regex::new(r"(?i)(?:write|update|patch)\s+([\w\-./]+)").expect("valid regex"),
            test: Regex::new(r"(?i)(?:pytest|cargo test|npm test|vitest|go test)").expect("valid regex"),
            command: Regex::new(r"(?i)run(?:ning)?\s*:?\s*(.+)$").expect("valid regex"),
        }
    }
}

impl AgentAdapter for CodexAdapter {
    fn name(&self) -> &'static str {
        "codex"
    }

    fn parse_line(&self, line: &str) -> Option<ParsedAction> {
        if self.test.is_match(line) {
            return Some(ParsedAction {
                kind: ActionKind::TestRun,
                title: "Run tests".to_string(),
                detail: Some(line.to_string()),
                artifact_path: None,
            });
        }

        if let Some(captures) = self.read.captures(line) {
            let path = captures.get(1)?.as_str().to_string();
            return Some(ParsedAction {
                kind: ActionKind::FileRead,
                title: format!("Read {path}"),
                detail: Some(line.to_string()),
                artifact_path: Some(path),
            });
        }

        if let Some(captures) = self.write.captures(line) {
            let path = captures.get(1)?.as_str().to_string();
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
