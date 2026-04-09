use crate::db::Database;
use crate::models::{EventEnvelope, EventType};
use tauri::{AppHandle, Manager};

pub fn emit_event(app: &AppHandle, db: &Database, event: &EventEnvelope) {
    if let Err(err) = db.insert_event(event) {
        eprintln!("failed to insert event: {err}");
    }

    if matches!(
        event.event_type,
        EventType::FileChanged | EventType::FileCreated | EventType::FileDeleted
    ) {
        if let Err(err) = db.upsert_diff(
            &event.session_id,
            event.payload.clone(),
            event.ts.to_rfc3339(),
        ) {
            eprintln!("failed to upsert diff: {err}");
        }
    }

    if let Err(err) = app.emit("backend:event", event) {
        eprintln!("failed to emit event: {err}");
    }
}
