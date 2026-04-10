import { useMemo } from "react";
import { useAppStore } from "../../state/store";

export function ChangeTrackingCard() {
  const sessionId = useAppStore((s) => s.activeSessionId);
  const diffs = useAppStore((s) => (sessionId ? s.diffs[sessionId] ?? [] : []));
  const selectedDiffPath = useAppStore((s) =>
    sessionId ? s.selectedDiffPathBySession[sessionId] : undefined
  );
  const selectDiffPath = useAppStore((s) => s.selectDiffPath);

  const orderedDiffs = useMemo(
    () => [...diffs].sort((a, b) => b.ts.localeCompare(a.ts)),
    [diffs]
  );

  if (!sessionId) {
    return (
      <section className="card-shell">
        <header className="card-header">
          <h2>Change Tracking</h2>
        </header>
        <p className="empty">No active session.</p>
      </section>
    );
  }

  return (
    <section className="card-shell">
      <header className="card-header">
        <h2>Change Tracking</h2>
        <span className="muted">{orderedDiffs.length} files</span>
      </header>
      <div className="change-list">
        {orderedDiffs.length > 0 ? (
          orderedDiffs.map((diff) => (
            <button
              key={diff.path}
              type="button"
              className={diff.path === selectedDiffPath ? "change-item active" : "change-item"}
              onClick={() => selectDiffPath(sessionId, diff.path)}
            >
              <span className="change-path">{diff.path}</span>
              <span className="change-meta">{diff.changeType} · {new Date(diff.ts).toLocaleTimeString()}</span>
            </button>
          ))
        ) : (
          <p className="empty">Waiting for `file_changed` events from the active session.</p>
        )}
      </div>
    </section>
  );
}
