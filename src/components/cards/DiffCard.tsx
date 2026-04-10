import Editor, { DiffEditor } from "@monaco-editor/react";
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
        <div className="diff-editor">
          <DiffEditor
            language="typescript"
            original={current.before}
            modified={current.after}
            theme="vs-dark"
            options={{
              renderSideBySide: true,
              minimap: { enabled: false },
              readOnly: true
            }}
          />
        </div>
      ) : (
        <Editor
          language="markdown"
          theme="vs-dark"
          value="Select a file from Change Tracking or wait for a file_changed event..."
          options={{ readOnly: true, minimap: { enabled: false } }}
        />
      )}
    </section>
  );
}
