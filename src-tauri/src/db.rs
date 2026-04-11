use crate::models::EventEnvelope;
use anyhow::Result;
use rusqlite::{params, Connection};
use std::path::Path;
use std::sync::Mutex;

pub struct Database {
    conn: Mutex<Connection>,
}

impl Database {
    pub fn new(path: &Path) -> Result<Self> {
        let conn = Connection::open(path)?;
        conn.execute_batch(
            "
            CREATE TABLE IF NOT EXISTS events (
                event_id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                ts TEXT NOT NULL,
                source TEXT NOT NULL,
                event_type TEXT NOT NULL,
                confidence REAL NOT NULL,
                payload TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_events_session_ts ON events(session_id, ts);

            CREATE TABLE IF NOT EXISTS diffs (
                session_id TEXT NOT NULL,
                path TEXT NOT NULL,
                before_text TEXT NOT NULL,
                after_text TEXT NOT NULL,
                ts TEXT NOT NULL,
                PRIMARY KEY (session_id, path)
            );
            ",
        )?;

        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    pub fn insert_event(&self, event: &EventEnvelope) -> Result<()> {
        let conn = self
            .conn
            .lock()
            .map_err(|_| anyhow::anyhow!("failed to lock sqlite connection"))?;
        conn.execute(
            "
            INSERT INTO events(event_id, session_id, ts, source, event_type, confidence, payload)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
            ",
            params![
                event.event_id,
                event.session_id,
                event.ts.to_rfc3339(),
                serde_json::to_string(&event.source)?,
                serde_json::to_string(&event.event_type)?,
                event.confidence,
                serde_json::to_string(&event.payload)?,
            ],
        )?;
        Ok(())
    }

    pub fn upsert_diff(&self, session_id: &str, payload: serde_json::Value, ts: String) -> Result<()> {
        let path = payload
            .get("path")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_string();
        let before_text = payload
            .get("before")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_string();
        let after_text = payload
            .get("after")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_string();

        if path.is_empty() {
            return Ok(());
        }

        let conn = self
            .conn
            .lock()
            .map_err(|_| anyhow::anyhow!("failed to lock sqlite connection"))?;

        conn.execute(
            "
            INSERT INTO diffs(session_id, path, before_text, after_text, ts)
            VALUES (?1, ?2, ?3, ?4, ?5)
            ON CONFLICT(session_id, path)
            DO UPDATE SET before_text = excluded.before_text, after_text = excluded.after_text, ts = excluded.ts
            ",
            params![session_id, path, before_text, after_text, ts],
        )?;
        Ok(())
    }
}
