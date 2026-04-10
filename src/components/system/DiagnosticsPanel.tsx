import { useMemo, useState } from "react";
import { useRuntimeLogs } from "../../lib/runtimeDiagnostics";

interface DiagnosticsPanelProps {
  title?: string;
  expanded?: boolean;
}

export function DiagnosticsPanel({
  title = "Diagnostics",
  expanded = false
}: DiagnosticsPanelProps) {
  const logs = useRuntimeLogs();
  const [open, setOpen] = useState(expanded);

  const recentLogs = useMemo(() => logs.slice(-30).reverse(), [logs]);

  return (
    <section className="diagnostics-shell">
      <header className="diagnostics-header">
        <div>
          <h2>{title}</h2>
          <p className="muted">{logs.length} buffered entries</p>
        </div>
        <button type="button" onClick={() => setOpen((current) => !current)}>
          {open ? "Collapse" : "Expand"}
        </button>
      </header>
      {open ? (
        <div className="diagnostics-log-list">
          {recentLogs.map((entry) => (
            <article className={`diagnostics-log diagnostics-${entry.level}`} key={entry.id}>
              <div className="diagnostics-meta">
                <span>{entry.ts}</span>
                <span>{entry.level}</span>
                <span>{entry.scope}</span>
              </div>
              <div className="diagnostics-message">{entry.message}</div>
              {entry.details !== undefined ? (
                <pre className="diagnostics-details">
                  {safeStringify(entry.details)}
                </pre>
              ) : null}
            </article>
          ))}
        </div>
      ) : null}
    </section>
  );
}

const safeStringify = (value: unknown) => {
  try {
    return JSON.stringify(value, null, 2);
  } catch {
    return String(value);
  }
};
