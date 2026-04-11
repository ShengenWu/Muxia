use crate::models::{EdgeKind, GraphEdge};
use std::collections::HashMap;

#[derive(Default)]
pub struct GraphBuilder {
    last_node_by_session: HashMap<String, String>,
}

impl GraphBuilder {
    pub fn create_next_edge(&mut self, session_id: &str, node_id: &str) -> Option<GraphEdge> {
        let prior = self
            .last_node_by_session
            .insert(session_id.to_string(), node_id.to_string());

        prior.map(|from| GraphEdge {
            id: uuid::Uuid::new_v4().to_string(),
            session_id: session_id.to_string(),
            from,
            to: node_id.to_string(),
            kind: EdgeKind::Next,
        })
    }
}
