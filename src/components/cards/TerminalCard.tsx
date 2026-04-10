import { useMemo } from "react";
import { useAppStore } from "../../state/store";

export function TerminalCard() {
  const activeSessionId = useAppStore((s) => s.activeSessionId);
  const messages = useAppStore((s) =>
    activeSessionId ? s.messages[activeSessionId] ?? [] : []
  );
  const nodes = useAppStore((s) => (activeSessionId ? s.nodes[activeSessionId] ?? [] : []));

  const transcript = useMemo(() => {
    if (!activeSessionId) {
      return [];
    }

    const assistantLines = messages.map((message) => `[${message.role}] ${message.content}`);
    const actionLines = nodes.map((node) => `[action:${node.kind}] ${node.title}`);
    return [`[session ${activeSessionId}] connected`, ...assistantLines, ...actionLines];
  }, [activeSessionId, messages, nodes]);

  return (
    <section className="card-shell terminal-shell">
      <header className="card-header">
        <h2>Terminal</h2>
        <span className="muted">safe transcript view</span>
      </header>
      <div className="terminal-host terminal-fallback">
        {transcript.length > 0 ? (
          <pre>{transcript.join("\n")}</pre>
        ) : (
          <p className="empty">No active session transcript yet.</p>
        )}
      </div>
    </section>
  );
}
