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
use std::process::Command;
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
            eprintln!(
                "[info] [watcher] file change path={} session_id={} before_len={} after_len={}",
                path_str,
                session_id,
                before.len(),
                after.len()
            );
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

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct PickProjectDirectoryResponse {
    path: Option<String>,
}

#[tauri::command]
fn frontend_log(channel: String, message: String, details: Option<String>) {
    match details {
        Some(details) => eprintln!("[frontend:{}] {} | {}", channel, message, details),
        None => eprintln!("[frontend:{}] {}", channel, message),
    }
}

#[tauri::command]
fn create_session(
    app: AppHandle,
    state: State<'_, AppState>,
    adapter: String,
    cwd: String,
) -> Result<CreateSessionResponse, String> {
    eprintln!(
        "[info] [command] create_session adapter={} cwd={}",
        adapter, cwd
    );
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
    eprintln!(
        "[info] [command] send_user_message session_id={} content_len={}",
        session_id,
        content.len()
    );
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
    eprintln!(
        "[debug] [command] write_pty session_id={} data_len={}",
        session_id,
        data.len()
    );
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
fn set_active_session(state: State<'_, AppState>, session_id: String) -> Result<(), String> {
    eprintln!(
        "[info] [command] set_active_session session_id={}",
        session_id
    );
    let map = state.runtime.sessions.lock().map_err(|_| "sessions lock poisoned")?;
    if !map.contains_key(&session_id) {
        return Err("session not found".to_string());
    }
    drop(map);

    let mut active = state
        .runtime
        .last_active_session
        .lock()
        .map_err(|_| "active session lock poisoned".to_string())?;
    *active = Some(session_id);
    Ok(())
}

#[tauri::command]
fn end_session(app: AppHandle, state: State<'_, AppState>, session_id: String) -> Result<(), String> {
    eprintln!(
        "[info] [command] end_session session_id={}",
        session_id
    );
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

#[tauri::command]
fn pick_project_directory() -> Result<PickProjectDirectoryResponse, String> {
    eprintln!("[info] [command] pick_project_directory");

    #[cfg(target_os = "macos")]
    {
        let output = Command::new("osascript")
            .arg("-e")
            .arg("try")
            .arg("-e")
            .arg("POSIX path of (choose folder with prompt \"Select a project folder\")")
            .arg("-e")
            .arg("on error number -128")
            .arg("-e")
            .arg("return \"\"")
            .arg("-e")
            .arg("end try")
            .output()
            .map_err(|err| err.to_string())?;

        if !output.status.success() {
            return Err(String::from_utf8_lossy(&output.stderr).trim().to_string());
        }

        let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
        return Ok(PickProjectDirectoryResponse {
            path: if path.is_empty() { None } else { Some(path) },
        });
    }

    #[cfg(not(target_os = "macos"))]
    {
        Err("pick_project_directory is currently implemented only for macOS".to_string())
    }
}

pub fn run() {
    tauri::Builder::default()
        .on_page_load(|window, payload| {
            eprintln!(
                "[info] [webview] page load event window={} url={}",
                window.label(),
                payload.url()
            );
        })
        .setup(|app| {
            if let Some(main_window) = app.get_webview_window("main") {
                match main_window.inner_size() {
                    Ok(size) => {
                        eprintln!(
                            "[info] [window] main inner_size width={} height={}",
                            size.width, size.height
                        );
                    }
                    Err(error) => {
                        eprintln!("[error] [window] failed to read main inner_size: {error}");
                    }
                }

                match main_window.as_ref().bounds() {
                    Ok(bounds) => {
                        eprintln!("[info] [webview] main bounds {:?}", bounds);
                    }
                    Err(error) => {
                        eprintln!("[error] [webview] failed to read main bounds: {error}");
                    }
                }

                if let Err(error) = main_window.as_ref().set_auto_resize(true) {
                    eprintln!("[error] [webview] failed to enable auto_resize: {error}");
                } else {
                    eprintln!("[info] [webview] enabled auto_resize for main webview");
                }
            } else {
                eprintln!("[error] [window] failed to resolve main webview window during setup");
            }

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
            set_active_session,
            end_session,
            pick_project_directory,
            frontend_log
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
