import { useMemo } from "react";
import { useAppStore } from "../../state/store";

export function DiffCard() {
  const sessionId = useAppStore((s) => s.activeSessionId);
  const diffs = useAppStore((s) => (sessionId ? s.diffs[sessionId] ?? [] : []));
  const selectedDiffPath = useAppStore((s) =>
    sessionId ? s.selectedDiffPathBySession[sessionId] : undefined
  );

  const current = useMemo(
    () => diffs.find((diff) => diff.path === selectedDiffPath) ?? diffs[0],
    [diffs, selectedDiffPath]
  );

  if (!sessionId) {
    return (
      <section className="card-shell">
        <header className="card-header">
          <h2>Diff</h2>
        </header>
        <p className="empty">No active session.</p>
      </section>
    );
  }

  return (
    <section className="card-shell">
      <header className="card-header">
        <h2>Diff</h2>
        {current ? <span className="muted">{current.path}</span> : null}
      </header>
      {current ? (
        <div className="diff-editor diff-fallback">
          <section className="diff-pane">
            <h3>Before</h3>
            <pre>{current.before || "(empty)"}</pre>
          </section>
          <section className="diff-pane">
            <h3>After</h3>
            <pre>{current.after || "(empty)"}</pre>
          </section>
        </div>
      ) : (
        <div className="diff-editor diff-empty">
          <p className="empty">Select a file from Change Tracking or wait for a file_changed event...</p>
        </div>
      )}
    </section>
  );
}
