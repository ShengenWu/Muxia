mod adapters;
mod db;
mod event_bus;
mod graph;
mod models;
mod pty;
mod watcher;

use adapters::{AgentAdapter, ClaudeAdapter, CodexAdapter};
use db::Database;
use event_bus::emit_event;
use graph::GraphBuilder;
use models::{EventEnvelope, EventSource, EventType};
use pty::{for_each_line, spawn_pty, PtySession};
use serde::Serialize;
use serde_json::json;
use std::collections::HashMap;
use std::io::Write;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use tauri::{AppHandle, Manager, State};
use watcher::start_workspace_watcher;

struct SessionRuntime {
    _adapter: Arc<dyn AgentAdapter>,
    pty: PtySession,
}

struct AppRuntime {
    db: Database,
    sessions: Mutex<HashMap<String, SessionRuntime>>,
    graph: Mutex<GraphBuilder>,
    last_active_session: Mutex<Option<String>>,
    watcher: Mutex<Option<notify::RecommendedWatcher>>,
}

impl AppRuntime {
    fn new(db: Database) -> Self {
        Self {
            db,
            sessions: Mutex::new(HashMap::new()),
            graph: Mutex::new(GraphBuilder::default()),
            last_active_session: Mutex::new(None),
            watcher: Mutex::new(None),
        }
    }

    fn ensure_watcher(&self, app: &AppHandle, root: PathBuf) -> anyhow::Result<()> {
        let mut watcher_guard = self.watcher.lock().expect("watcher mutex");
        if watcher_guard.is_some() {
            return Ok(());
        }

        let app_clone = app.clone();
        let runtime = app.state::<AppState>().inner().clone();
        let watcher = start_workspace_watcher(&root, move |path, before, after| {
            let session_id = runtime
                .runtime
                .last_active_session
                .lock()
                .expect("last active session")
                .clone()
                .unwrap_or_else(|| "global".to_string());

            let path_str = path.to_string_lossy().to_string();
            let file_changed_event = EventEnvelope::new(
                session_id.clone(),
                EventSource::FsWatcher,
                EventType::FileChanged,
                1.0,
                json!({
                    "path": path_str,
                    "change_type": "modified",
                    "before": before,
                    "after": after
                }),
            );
            emit_event(&app_clone, &runtime.runtime.db, &file_changed_event);
        })?;

        *watcher_guard = Some(watcher);
        Ok(())
    }
}

#[derive(Clone)]
struct AppState {
    runtime: Arc<AppRuntime>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct CreateSessionResponse {
    session_id: String,
}

#[tauri::command]
fn create_session(
    app: AppHandle,
    state: State<'_, AppState>,
    adapter: String,
    cwd: String,
) -> Result<CreateSessionResponse, String> {
    let session_id = uuid::Uuid::new_v4().to_string();
    let adapter_impl: Arc<dyn AgentAdapter> = match adapter.as_str() {
        "claude" => Arc::new(ClaudeAdapter::default()),
        "codex" => Arc::new(CodexAdapter::default()),
        _ => return Err("unsupported adapter".to_string()),
    };

    let command = match adapter.as_str() {
        "claude" => "claude",
        "codex" => "codex",
        _ => "zsh",
    };

    let (pty_session, reader) = spawn_pty(command, &cwd).map_err(|err| err.to_string())?;

    let event = EventEnvelope::new(
        session_id.clone(),
        EventSource::System,
        EventType::SessionStarted,
        1.0,
        json!({
            "agent_type": adapter,
            "cwd": cwd
        }),
    );
    emit_event(&app, &state.runtime.db, &event);

    {
        let mut map = state.runtime.sessions.lock().map_err(|_| "sessions lock poisoned")?;
        map.insert(
            session_id.clone(),
            SessionRuntime {
                _adapter: Arc::clone(&adapter_impl),
                pty: pty_session,
            },
        );
    }

    {
        let mut active = state
            .runtime
            .last_active_session
            .lock()
            .map_err(|_| "active session lock poisoned")?;
        *active = Some(session_id.clone());
    }

    let app_clone = app.clone();
    let state_clone = state.inner().clone();
    let session_id_clone = session_id.clone();
    for_each_line(reader, move |line| {
        let trimmed = line.trim().to_string();
        if trimmed.is_empty() {
            return;
        }

        let message_event = EventEnvelope::new(
            session_id_clone.clone(),
            EventSource::Pty,
            EventType::MessageAssistant,
            0.7,
            json!({
                "id": uuid::Uuid::new_v4().to_string(),
                "content": trimmed.clone()
            }),
        );
        emit_event(&app_clone, &state_clone.runtime.db, &message_event);

        if let Some(parsed) = adapter_impl.parse_line(&trimmed) {
            let node_id = uuid::Uuid::new_v4().to_string();
            let next_edge = state_clone
                .runtime
                .graph
                .lock()
                .expect("graph mutex")
                .create_next_edge(&session_id_clone, &node_id);

            let action_event = EventEnvelope::new(
                session_id_clone.clone(),
                EventSource::Adapter,
                EventType::ActionToolCall,
                0.8,
                json!({
                    "id": node_id,
                    "tool_name": parsed.kind,
                    "title": parsed.title,
                    "detail": parsed.detail,
                    "artifact_path": parsed.artifact_path,
                    "edge": next_edge
                }),
            );
            emit_event(&app_clone, &state_clone.runtime.db, &action_event);
        }
    });

    state
        .runtime
        .ensure_watcher(&app, PathBuf::from(&cwd))
        .map_err(|err| err.to_string())?;

    Ok(CreateSessionResponse { session_id })
}

#[tauri::command]
fn send_user_message(
    app: AppHandle,
    state: State<'_, AppState>,
    session_id: String,
    content: String,
) -> Result<(), String> {
    let event = EventEnvelope::new(
        session_id.clone(),
        EventSource::System,
        EventType::MessageUser,
        1.0,
        json!({
            "id": uuid::Uuid::new_v4().to_string(),
            "content": content.clone()
        }),
    );
    emit_event(&app, &state.runtime.db, &event);

    let mut map = state.runtime.sessions.lock().map_err(|_| "sessions lock poisoned")?;
    let runtime = map
        .get_mut(&session_id)
        .ok_or_else(|| "session not found".to_string())?;
    let mut writer = runtime
        .pty
        .writer
        .lock()
        .map_err(|_| "pty writer lock poisoned".to_string())?;

    writer
        .write_all(format!("{}\n", content).as_bytes())
        .map_err(|err| err.to_string())?;
    writer.flush().map_err(|err| err.to_string())?;

    Ok(())
}

#[tauri::command]
fn write_pty(state: State<'_, AppState>, session_id: String, data: String) -> Result<(), String> {
    let mut map = state.runtime.sessions.lock().map_err(|_| "sessions lock poisoned")?;
    let runtime = map
        .get_mut(&session_id)
        .ok_or_else(|| "session not found".to_string())?;
    let mut writer = runtime
        .pty
        .writer
        .lock()
        .map_err(|_| "pty writer lock poisoned".to_string())?;
    writer
        .write_all(data.as_bytes())
        .map_err(|err| err.to_string())?;
    writer.flush().map_err(|err| err.to_string())?;
    Ok(())
}

#[tauri::command]
fn end_session(app: AppHandle, state: State<'_, AppState>, session_id: String) -> Result<(), String> {
    {
        let mut map = state.runtime.sessions.lock().map_err(|_| "sessions lock poisoned")?;
        map.remove(&session_id);
    }

    let event = EventEnvelope::new(
        session_id,
        EventSource::System,
        EventType::SessionEnded,
        1.0,
        json!({}),
    );
    emit_event(&app, &state.runtime.db, &event);
    Ok(())
}

pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            let data_dir = app
                .path()
                .app_data_dir()
                .map_err(|err| anyhow::anyhow!(err.to_string()))?;
            std::fs::create_dir_all(&data_dir)?;
            let db = Database::new(&data_dir.join("new-terminal.db"))?;
            app.manage(AppState {
                runtime: Arc::new(AppRuntime::new(db)),
            });
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            create_session,
            send_user_message,
            write_pty,
            end_session
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
