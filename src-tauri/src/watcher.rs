use anyhow::Result;
use notify::{Config, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

pub type SnapshotStore = Arc<Mutex<HashMap<PathBuf, String>>>;

pub fn start_workspace_watcher(
    root: &Path,
    mut on_change: impl FnMut(PathBuf, String, String) + Send + 'static,
) -> Result<RecommendedWatcher> {
    let snapshots: SnapshotStore = Arc::new(Mutex::new(HashMap::new()));
    let snapshots_clone = Arc::clone(&snapshots);

    let mut watcher = RecommendedWatcher::new(
        move |res: notify::Result<notify::Event>| {
            let Ok(event) = res else {
                return;
            };

            if !matches!(event.kind, EventKind::Modify(_) | EventKind::Create(_)) {
                return;
            }

            for path in event.paths {
                if path.is_dir() {
                    continue;
                }

                let Ok(new_text) = std::fs::read_to_string(&path) else {
                    continue;
                };

                let before = {
                    let mut guard = snapshots_clone.lock().expect("snapshot lock");
                    let old = guard.get(&path).cloned().unwrap_or_default();
                    guard.insert(path.clone(), new_text.clone());
                    old
                };

                on_change(path, before, new_text);
            }
        },
        Config::default(),
    )?;

    watcher.watch(root, RecursiveMode::Recursive)?;
    Ok(watcher)
}
